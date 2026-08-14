# uv notes

## AOCL BLIS for numpy — evaluated, not adopted (2026-06-17)

**Decision: numpy stays on the stock OpenBLAS PyPI wheel.** We tried forcing `uv` to
source-build numpy against AOCL BLIS + libFLAME (Zen 4 kernels) instead of the OpenBLAS that
ships inside the wheel. Benchmarked on this machine — not worth the complexity. The `uv.toml` here only sets
`compile-bytecode`; it intentionally does **not** force an AOCL source build.

### Why a source build was even needed

PyPI numpy/scipy wheels bundle their own OpenBLAS and ignore the system BLAS entirely — which
is now doubly true, since there is no system `blas` provider at all any more (see `revisit.md`).
uv vs pip is irrelevant — same wheel. The only way to use AOCL is to compile numpy from source
and point Meson at AOCL via pkg-config.

Re-verified 2026-08-14 on numpy 2.5.2 with `~/learning/playground/numpy-blas-check`, which reads
the process's own `/proc/self/maps` rather than trusting build metadata:

```
build config : scipy-openblas 0.3.34
loaded .so   : .venv/.../numpy.libs/libscipy_openblas64_-61654e39.so   (24 MiB, inside the wheel)
find_library('blas') -> None          AOCL loaded by numpy -> NO
threadpoolctl: openblas 0.3.34  threads=8  arch=SkylakeX
```

### Benchmark (float64, 8 threads, performance governor, AC power)

Both backends verified at ~7.9 cores / 8 threads (no thread-count bias); AOCL affinity tuning
did not help. OpenBLAS 0.3.31 runs AVX-512 `SkylakeX` (no dedicated Zen 4 kernel); AOCL is `zen4`.
Still `SkylakeX` at 0.3.34 (2026-08-14) — so OpenBLAS wins these sizes *without* a Zen 4 kernel,
and a future one would only widen the gap.

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

AOCL's own `.pc` files are broken — they hardcode a version-stamped `prefix=` that does not
exist (`/opt/aocl/5.3.0/gcc/MT` as of 5.3.0; it was `/opt/aocl/5.2.0/gcc` before), so
pkg-config detection passes but linking dies (`ld: cannot find -lblis-mt`). Note 5.3.0 also
moved the trees down a level into `MT/`. Rewrite `prefix=` outright rather than matching the
old string, so this survives the next bump:

```bash
mkdir -p ~/.config/aocl-pkgconfig
for f in blis-mt flame aocl-utils; do
  sed -e 's#^prefix=.*#prefix=/opt/aocl/gcc/MT#' \
      -e 's#^libdir=.*#libdir=${prefix}/lib_LP64#' \
      /opt/aocl/gcc/MT/lib_LP64/pkgconfig/$f.pc > ~/.config/aocl-pkgconfig/$f.pc
done

PKG_CONFIG_PATH=~/.config/aocl-pkgconfig \
uv pip install --no-binary numpy numpy \
  -C setup-args=-Dblas=blis-mt -C setup-args=-Dlapack=flame
# verify: python -m threadpoolctl -i numpy  → blis / zen4
```

Threads via `BLIS_NUM_THREADS` / `OMP_NUM_THREADS`. Runtime needs no `LD_LIBRARY_PATH`
(`libblis-mt.so.5` / `libflame.so` are in the ld.so cache via `/usr/lib`). numpy only — never scipy.
