# uv notes

## AOCL BLIS for numpy — evaluated, not adopted (2026-06-17)

**Decision: numpy stays on the stock OpenBLAS PyPI wheel.** We tried forcing `uv` to
source-build numpy against AOCL BLIS + libFLAME (Zen 4 kernels) instead of the OpenBLAS that
ships inside the wheel. Benchmarked on this machine — not worth the complexity. The `uv.toml` here only sets
`compile-bytecode`; it intentionally does **not** force an AOCL source build.

### Why a source build was even needed

PyPI numpy/scipy wheels bundle their own OpenBLAS and ignore the system BLAS
(`/usr/lib/libblas.so` → AOCL) entirely. uv vs pip is irrelevant — same wheel. The only way to
use AOCL is to compile numpy from source and point Meson at AOCL via pkg-config.

### Benchmark (float64, 8 threads, performance governor, AC power)

Both backends verified at ~7.9 cores / 8 threads (no thread-count bias); AOCL affinity tuning
did not help. OpenBLAS 0.3.31 runs AVX-512 `SkylakeX` (no dedicated Zen 4 kernel); AOCL is `zen4`.

GEMM `C=A@B` — AOCL vs OpenBLAS GFLOPS:

| N     | AOCL | OpenBLAS | Winner            |
|-------|------|----------|-------------------|
| 1024  | 354  | **451**  | OpenBLAS +27%     |
| 2048  | 279  | **397**  | **OpenBLAS +42%** |
| 4096  | **438** | 426   | ~tie              |
| 8192  | **441** | 430   | ~tie              |
| 16384 | **429** | 402   | AOCL +6.8%        |
| 20480 | **427** | 396   | AOCL +7.9%        |

- Crossover ~4096; AOCL also noisier at small N. **RAM: identical** within ~0.3% (matrix data
  dominates; BLAS buffer overhead negligible).
- LAPACK (`np.linalg.solve`): AOCL libFLAME is **slower** (−16% at N=8192) — never point scipy
  at it.
- ~430/~1280 GFLOPS peak (~34%) for *both* — the 28 W APU throttles under sustained AVX-512, so
  silicon, not the library, is the ceiling.

**Takeaway:** AOCL only pays off for large dense GEMM (N≥4096), and only 3–8%. The stock
OpenBLAS wheel is the better default.

### Recipe, if a future large-GEMM workload justifies revisiting (per-project, not global)

AOCL's own `.pc` files are broken — they hardcode `prefix=/opt/aocl/5.2.0/gcc`, a path that
does not exist, so pkg-config detection passes but linking dies (`ld: cannot find -lblis-mt`).
Generate corrected copies, then source-build numpy:

```bash
mkdir -p ~/.config/aocl-pkgconfig
for f in blis-mt flame aocl-utils; do
  sed -e 's#/opt/aocl/5.2.0/gcc#/opt/aocl/gcc#g' \
      -e 's#^libdir=.*#libdir=${prefix}/lib_LP64#' \
      /opt/aocl/gcc/lib_LP64/pkgconfig/$f.pc > ~/.config/aocl-pkgconfig/$f.pc
done

PKG_CONFIG_PATH=~/.config/aocl-pkgconfig \
uv pip install --no-binary numpy numpy \
  -C setup-args=-Dblas=blis-mt -C setup-args=-Dlapack=flame
# verify: python -m threadpoolctl -i numpy  → blis / zen4
```

Threads via `BLIS_NUM_THREADS` / `OMP_NUM_THREADS`. Runtime needs no `LD_LIBRARY_PATH`
(`libblis-mt.so.5` / `libflame.so` are in the ld.so cache via `/usr/lib`). numpy only — never scipy.
