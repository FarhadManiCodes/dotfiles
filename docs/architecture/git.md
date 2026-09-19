# Git

- **Config**: `git/config` — delta pager, histogram diff, nvimdiff mergetool, aliases
- **Global ignore**: `git/ignore`
- **User identity**: `~/.config/git/config.local` (not tracked)
- **`push.recurseSubmodules = check`** (2026-09-09) — aborts a push whose submodule
  pointer names a commit absent from the submodule's own remote. Git doesn't check this
  by default, and the failure is silent: the superproject pushes fine and the pointer
  resolves nowhere for anyone else. It had already happened — `9eb7e47` reached the
  dotfiles remote pinning `nvim` at `b23059e`, not on the nvim remote.
  **Know its blind spot.** `check` only inspects submodules whose pointer *changes* in
  the commits being pushed. A push that leaves the gitlink untouched isn't checked at
  all, even when the remote pointer is already broken — measured 2026-09-09: with `nvim`
  at an unpushed `b23059e`, a dry-run push that didn't touch the gitlink exited 0. So this
  guards the pointer-bump push and nothing else; for an already-broken remote, fetch and
  compare `git -C nvim log origin/main..main`.

**`core.fsmonitor` is off everywhere** (2026-09-09). Git's own default is off; the line in
`git/config` states the decision so a stray default or a copied "make git faster" tip
can't quietly restore it. It can't be uninstalled — `git-fsmonitor--daemon` is a symlink
to the `git` binary itself — so the config line is the entire off switch.

The feature starts a background daemon per worktree so `git status` can ask it what
changed instead of scanning. Its own docs scope the benefit to "a working directory with
many files", which doesn't hold here: 20-run averages of `git status`, warm cache, were
5ms with it and 5ms without, on both `dotfiles` (235 tracked files) and the largest repo
present (1770).

It was global from 2026-05-07 and cost 61 daemons holding 318 MB — one per repository
ever touched, **59 of them plugin clones** (37 nvim lazy, 14 vim plugged, 5 tmux, 3 zsh)
that nothing ever edits. Git has no idle timeout, so a single sweep across a plugin tree —
exactly what `config-drift`'s plugin-staleness loop does — left one daemon per plugin
until reboot. After the change: 0 daemons, and `config-drift` spawns none where it spawned
22. (Measurements: `git show 14cc481`.)

The benchmarks are warm-cache only. The boot-cold case went further than expected:
`~/.cache/starship/` held a `git` timeout log from 08:23 on 2026-09-09 with
`core.fsmonitor` still global — so the earlier `Nice`/`CPUWeight` fix on the rclone mounts
had *not* eliminated that warning, as believed. The first boot after disabling fsmonitor
produced no starship log at all, and the git pre-warm in `niri/config.kdl` was deleted
the same evening — it only ever raced the boot storm rather than removing anything, which
is what made the warning intermittent. If it returns, `~/.cache/starship/` is the
evidence and the pre-warm is a `git revert` away.
