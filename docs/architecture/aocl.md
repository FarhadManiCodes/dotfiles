# AOCL — linking it without hijacking system FFTW

Why `aocl-gcc` is installed and benchmarked against OpenBLAS: see the package notes in
`docs/system-notes.md`. This file covers how to link it safely.

- **There is deliberately no system `blas` provider.** The AUR adapter `blas-aocl-gcc`, which
  symlinked `/usr/lib/lib{blas,cblas,lapack,lapacke}.so` at AOCL, was **removed 2026-08-14**:
  it is orphaned upstream (no maintainer, flagged out-of-date), and AOCL 5.3.0 moved the
  library trees down into `MT/` (multi-threaded) and `ST/` subdirectories, dangling all 13 of
  its hardcoded symlinks — `ldconfig` then pruned the four `.so.3` ones, silently. **`-lblas`
  no longer resolves, and never should:** AOCL ships no `libblas.so` at all, so that name was
  always the adapter's invention. Don't reinstall it, and don't add a replacement provider —
  nothing on the system depends on `blas`.
- **How to link AOCL.** CMake has native support since 3.27, and it is strictly better than
  the old symlinks: it adds the `-fopenmp` that libflame needs (the symlinks silently omitted
  it) and picks MT/ST and LP64/ILP64 correctly instead of hardcoding one combination.
  ```cmake
  list(APPEND CMAKE_LIBRARY_PATH "/opt/aocl/gcc/MT/lib_LP64")
  set(BLA_VENDOR AOCL_mt)
  find_package(BLAS REQUIRED)
  find_package(LAPACK REQUIRED)
  ```
  Copy the full pattern — layout probe plus RPATH — from
  `~/learning/playground/aocl-check/CMakeLists.txt`. Running that project verifies the wiring
  end to end (`dgemm`/`dtrsm`/`dgesv`, exit 0 = correct).
- **Never add AOCL's lib dir to `/etc/ld.so.conf.d/`**, despite what the `aocl-gcc` install
  scriptlet suggests. It ships `libfftw3.so.3` (FFTW 3.3.10) with the *same soname* as the
  system fftw (3.3.11), so a global entry would hijack FFTW for every process on the machine.
  Use per-target `BUILD_RPATH`/`INSTALL_RPATH`; binaries then run in a clean environment with
  no `LD_LIBRARY_PATH`.
- **Put `/usr/lib` first in that RPATH** — `"/usr/lib:${AOCL_LIB_DIR}"`. `DT_RUNPATH` is
  searched *before* `ld.so.cache`, so a bare AOCL rpath reproduces the FFTW hijack inside
  that one binary: measured, a program linked against system `-lfftw3` then loads AOCL's
  3.3.10 at runtime and warns ``Symbol `fftw_version' has different size in shared object``.
  Ordering `/usr/lib` first fixes it and costs nothing; `libblis-mt`/`libflame` still resolve
  from AOCL. Both `blas_bench` and `aocl-check` do this.
- **`PKG_CONFIG_PATH` is deliberately not set globally**, for that same FFTW reason —
  pkg-config searches it *before* the compiled-in defaults, so exposing it makes `pkg-config
  fftw3` return AOCL's 3.3.10. Set it per project if you need the BLIS-native API (`blis.h`,
  `blis`/`blis-mt`/`flame` modules). The `.pc` files are also **broken out of the box**: they
  hardcode `prefix=/opt/aocl/5.3.0/gcc/MT`, which does not exist. Override it with
  `pkg-config --define-variable=prefix=/opt/aocl/gcc/MT --libs flame`.
- BLIS worker count is set to 8 in `environment.d/defaults.conf`, matching the physical-core
  worker policy in `docs/system-notes.md`. With both thread-count overrides unset, BLIS was
  measured using all 16 logical CPUs. `BLIS_NUM_THREADS` **outranks** `OMP_NUM_THREADS`
  (measured), so a project setting `OMP_NUM_THREADS` for its own parallel regions will not
  resize BLIS.
- **Don't wrap BLAS calls in an `omp parallel` region.** `omp_max_active_levels` is 1 by
  default, so BLIS collapses to a single thread inside an active region — no
  oversubscription, but a real loss: 4×1500³ dgemm ran 435 GFLOP/s letting BLIS thread vs 265
  GFLOP/s hand-parallelised over 4 OpenMP threads (3 runs, ±1 ms).
- Verified sound in the 2026-08-03 second check: libFLAME exports 12,161 symbols with 0 of 30
  common LAPACK routines missing, and `dgemm`/`dgesv`/`dsyev` are numerically exact. The one
  rough edge was a link-time `libaoclutils.so ... not found` warning, which is **gone**: it
  came from `/usr/lib/liblapack.so`, a `blas-aocl-gcc` symlink, and that package was removed
  on 2026-08-14. Verified 2026-09-08 — the file does not exist, `/usr/local/lib` is empty,
  and 5.3.0's `libflame.so` records absolute `DT_NEEDED` paths so `ld` needs no help.
