---
name: profile-cpu
description: >
  Find where CPU time goes in a program on this machine with Linux perf. Use when asked why
  something is slow or CPU-bound, which function or source line is hot, for IPC, cache-miss or
  branch-miss counts, or to read a perf.data file. Not for timing whole commands or comparing
  before and after (use measure-performance).
---

# Profiling with perf here

AMD Ryzen 7 PRO 7840U (Zen 4), kernel 7.3, `perf` 7.3 (built with debuginfod, libdw DWARF
unwinding and libpython; without libunwind, capstone or LLVM). Guides written for Intel do not
apply as written: there are no `BR_INST_RETIRED.*`, `MEM_LOAD_RETIRED.*` or topdown/TMA events,
and AMD reports cache-line contention through IBS (the `ibs_op` and `ibs_fetch` PMUs), not
"HITM".

## Permissions decide what works

`kernel.perf_event_paranoid` is **2**, the kernel default; nothing in dotfiles or
`/etc/sysctl.d` sets it. Tested at 2 without root:

| Works | Fails: "Failure to open any events for recording" |
|---|---|
| `perf stat` (default events or explicit `:u` ones) | plain `perf record` (its default event) |
| `perf record -e cycles:u` (flat profile) | any call graph: `-g`, `--call-graph fp`, `dwarf` or `lbr` |
| `perf report`, `perf annotate` | `perf c2c`, `-e ibs_op//`, system-wide `-a` |

- **Always pass `-e cycles:u` to `perf record`.** The bare command fails here even though
  counting works, which reads like perf is broken.
- **Start flat.** A flat profile sorted by symbol and source line answers "what is hot" most
  of the time; call stacks answer "who called it".
- **Call stacks, `c2c` and IBS need root or a lower paranoid level.** Ask before either.
  `sudo` wants a password, so the user runs it with `! …`:
  `sudo sysctl kernel.perf_event_paranoid=1` (lasts until reboot). What level 1 unlocks has
  not been tested here yet; record it in this table once it has.

## The flow

```sh
cd /tmp                                                    # perf record writes ./perf.data
perf stat -- ./prog                                        # 1. counters: IPC, branch-miss rate
perf record -e cycles:u -o /tmp/p.data -- ./prog           # 2. sample
perf report -i /tmp/p.data --stdio --sort dso,sym --percent-limit 2
perf report -i /tmp/p.data --stdio --sort sym,srcline --percent-limit 5   # own code: file:line
perf annotate -i /tmp/p.data --stdio -s main               # 3. per-instruction, one symbol
```

- **`perf stat` with no `-e`** already prints IPC (`insn_per_cycle`), branch-miss rate and
  frontend stalls. Below ~1 IPC the CPU is mostly waiting (memory, mispredicts); a high
  branch-miss rate points at unpredictable branches.
- **Counter multiplexing.** Six explicit events showed `(66%)` beside each count: the PMU
  time-shared them and the counts are scaled estimates. Keep it to four or fewer events
  when the exact number matters.
- **Compare `instructions`, not cycles or time,** between two builds. Machine speed drifts
  between minutes (see measure-performance); instruction counts barely move.

## Symbols and source lines

- **Your own code:** build with `-O2 -g`. `-g` adds DWARF and does not change the generated
  code. With it, `--sort sym,srcline` showed `hot.c:2` / `hot.c:3`.
- **Inlining hides functions.** At `-O2` a small `work()` was inlined and its samples were
  reported under `main`. Look for the lines with `srcline`, or build with
  `-fno-inline` for a profile that names it (that build is slower and not what ships).
- **System libraries:** Arch packages carry no debug info. perf fetches it through debuginfod
  only when `DEBUGINFOD_URLS` is set, and only login shells set it (`/etc/profile.d`). The
  agent's shell and a non-login interactive zsh have it empty, so export it for the session:
  `export DEBUGINFOD_URLS=https://debuginfod.archlinux.org`. The first lookup downloads into
  `~/.cache/debuginfod_client`. Without it, library symbols still resolve, but not lines.

## Python

perf sees the interpreter, not your code: a hashlib loop profiled as `PyLong_FromLong`,
`PyObject_Malloc` and `__tls_get_addr` inside `libpython3.14`. Python-level attribution
(`python -X perf`) needs call stacks, which paranoid 2 blocks, and no `py-spy` is
installed. Use `python -m cProfile -s cumtime script.py` for which Python function is hot,
and perf only to see what a hot C extension call does.

## Report

Say what was run, the event, sample count, and whether call stacks were available. If the
answer needs data you could not collect (stacks, contention), say that rather than guess
from a flat profile.
