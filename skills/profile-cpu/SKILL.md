---
name: profile-cpu
description: >
  Find where CPU time goes in a program on this machine with Linux perf. Use when asked why
  something is slow or CPU-bound, which function or source line is hot, who calls it (call
  stacks), for IPC, cache-miss or branch-miss counts, to read a perf.data file, or when perf
  fails with "Failure to open event". Not for timing whole commands or comparing
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
`/etc/sysctl.d` sets it. Tested at 2 without root (perf 7.3.4, 2026-11-18):

| Works | Fails: "Failure to open event … which will be removed" |
|---|---|
| `perf stat`, `perf record` with or without `-e` (perf samples user space only by itself) | any call graph **without** `--user-callchains`: `-g`, `--call-graph dwarf` |
| call stacks **with** `--user-callchains`: `-g` or `--call-graph dwarf` | `--call-graph lbr`, even with the flag |
| `perf report`, `perf annotate` | `perf c2c`, `-e ibs_op//`, system-wide `-a` |

- **Call stacks need `--user-callchains`.** `-g` alone also asks for kernel stacks, which
  paranoid 2 refuses, so the whole event fails to open and the error names the event, not
  the call graph, which reads like perf is broken. With the flag:
  `perf record -g --user-callchains -o /tmp/g.data -- ./prog`.
- **Use `--call-graph dwarf` when a frame looks missing.** Frame-pointer unwinding (`-g`)
  loses the caller of any function that sets up no stack frame of its own. GCC 16 at `-O1`
  left a small leaf function without one even with `-fno-omit-frame-pointer
  -mno-omit-leaf-frame-pointer`, so `-g` showed `leaf → main` while dwarf showed
  `leaf → mid → main`. Dwarf files are much larger; keep runs short.
- **Start flat.** A flat profile sorted by symbol and source line answers "what is hot" most
  of the time; call stacks answer "who called it".
- **`c2c`, IBS and `-a` need root or a lower paranoid level.** Ask first. `sudo` wants a
  password, so the user runs it with `! …`: `sudo sysctl kernel.perf_event_paranoid=1`
  (lasts until reboot). What level 1 unlocks has not been tested here yet; record it in this
  table once it has.
- **Several `perf record` at once** can fail with "Permission error mapping pages" and leave
  an empty `-o` file; the next `perf report` then only says "zero-sized data". The per-user
  buffer budget is small here (`perf_event_mlock_kb` 516). Run profiles one at a time, or
  give each a smaller buffer with `-m 16` (0 of 32 concurrent runs failed with it).
- **After a kernel or perf update**, run the script below; update the table if it disagrees.

## Available Scripts

| Script | Purpose | Arguments |
|---|---|---|
| `scripts/check-perms.sh` | Re-tests every row of the table above on a small program it builds in a temp dir (about 1 s), and checks that dwarf stacks show the middle frame | none |

## The flow

```sh
cd /tmp                                                    # perf record writes ./perf.data
perf stat -- ./prog                                        # 1. counters: IPC, branch-miss rate
perf record -o /tmp/p.data -- ./prog                       # 2. sample
perf report -i /tmp/p.data --stdio --sort dso,sym --percent-limit 2
perf report -i /tmp/p.data --stdio --sort sym,srcline --percent-limit 5   # own code: file:line
perf annotate -i /tmp/p.data --stdio -s main               # 3. per-instruction, one symbol
perf record -g --user-callchains -o /tmp/g.data -- ./prog                 # 4. who calls it
perf report -i /tmp/g.data --stdio --no-children --percent-limit 5
```

- **`perf stat` with no `-e`** already prints IPC (`insn_per_cycle`), branch-miss rate and
  frontend stalls. Below ~1 IPC the CPU is mostly waiting (memory, mispredicts); a high
  branch-miss rate points at unpredictable branches. Every count is user space only here:
  perf silently turns `-e cycles` into `cycles:u`, so time spent in the kernel (syscalls,
  page faults) is not in the numbers. Say so when reporting them.
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

A plain profile sees the interpreter, not your code: a hashlib loop profiled as
`PyLong_FromLong`, `PyObject_Malloc` and `__tls_get_addr` inside `libpython3.14`. For
Python function names, run the script with `-X perf` and call stacks:
`perf record -e cpu-clock:u -g --user-callchains -o /tmp/py.data -- python3 -X perf script.py`.
The report then names frames `py::outer:script.py` → `py::hot_func:script.py` (tested with
3.14). Each run leaves a `/tmp/perf-<pid>.map` that perf needs to read the report; delete it
afterwards.
`python -m cProfile -s cumtime script.py` is the simpler answer when only the Python side
matters; no `py-spy` is installed.

## Report

Say what was run, the event, sample count, and whether call stacks were available. If the
answer needs data you could not collect (stacks, contention), say that rather than guess
from a flat profile.
