---
name: measure-performance
description: >
  Time and compare commands on this machine with hyperfine, so a speed or startup claim is
  measured rather than assumed. Use when asked whether something got faster or slower, to time
  shell or terminal startup, the prompt, a script or a build step, to compare two
  implementations, or before and after any performance edit. Covers the hyperfine flags that
  matter, what it cannot measure (memory, shell functions), and the traps that gave wrong
  numbers here: machine drift, warm versus cold caches, inherited environment, and probe
  shells overwriting the last working directory.
---

# Measuring speed here

`hyperfine` (1.20, `/usr/sbin/hyperfine`) is installed on purpose. Use it for wall time;
reach for something else only for the things it cannot see (below).

## The commands

```sh
cd /tmp                                              # see "Probe from /tmp"
hyperfine -N --warmup 5 --runs 40 'zsh -i -c exit'   # one command
hyperfine -N --warmup 5 'cmd-old' 'cmd-new'          # compare: it prints the ratio
hyperfine --prepare 'rm -f cache.zwc' 'cmd'          # cold cache: --prepare runs before every run
hyperfine -N -L v old,new 'prog --mode {v}'          # parameter sweep
```

- **`-N` (no shell)** for anything under ~5 ms. Without it hyperfine subtracts a shell-startup
  estimate and warns the result is inaccurate. Drop `-N` only when the command needs a pipe or
  `&&`.
- It reports mean ± σ, min/max, and **user/system time per run** (children included). Read
  σ: if it is a third of the mean, the numbers are noise, so add `--runs`.
- `--export-markdown file.md` if the result belongs in a document.

## What it cannot measure

- **Memory.** `/usr/bin/time` is not installed. Peak RSS of children:
  `python3 -c 'import resource,subprocess; subprocess.run([...]); print(resource.getrusage(resource.RUSAGE_CHILDREN).ru_maxrss)'`.
  A running shell: `grep -E 'RssAnon|RssFile' /proc/$$/status` (anon is private, file is shared).
- **A shell function or hook.** hyperfine starts programs. Time those inside zsh:
  `zmodload zsh/datetime; s=$EPOCHREALTIME; for i in {1..300}; do f; done; print $(( (EPOCHREALTIME-s)*1000/300 ))`.
- **Where the time goes.** Profile, don't guess: `zmodload zsh/zprof` in a throwaway `ZDOTDIR`
  plus `$EPOCHREALTIME` checkpoints between sections. zprof misses top-level code in sourced
  files and argument expansion: a `$(basename …)` forked 13 times per shell and never showed.

## Traps that gave wrong numbers

- **Probe from `/tmp`.** Every interactive zsh saves its directory as the last working
  directory on exit (`zsh/functions/last_working_dir.zsh`), and only `/tmp`, `$HOME`,
  `~/.cache` and similar are skipped. A probe that `cd`s elsewhere changes where your next
  terminal opens.
- **Machine speed drifts ~25 % between minutes.** Compare A and B interleaved in one session
  (A, B, A, B), never against a number measured earlier.
- **Cache state is part of the result.** zsh uses a `.zwc` beside a file automatically, so an
  "old code" baseline must have them removed, and the first shell after an edit recompiles.
  Say whether a figure is cold or warm.
- **Clean environment for behaviour.** The shell running you inherits exports an edit may
  have dropped, so a probe passes for the wrong reason. Use
  `env -i HOME=$HOME PATH=$PATH zsh -ic '…'`.
- **A shell start is not a first prompt.** `zsh -i -c exit` stops before any prompt is drawn;
  the first prompt adds the precmd hooks, starship and a one-time widget bind (~30 ms).
- **zsh does not word-split `$var`.** `S='tmux -L x'; $S new` fails; use a function or array.
- **Baselines.** `git stash` the change, measure, `git stash pop`; never time an installer,
  `sysup` or a plugin upgrade.

Report what was measured, how many runs, cold or warm, and what was not measured.
