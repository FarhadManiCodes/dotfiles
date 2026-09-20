# Dotfiles architecture and operational rationale

Per-application rationale and operational constraints, one file per topic under
`docs/architecture/`. Paths in backticks are relative to the dotfiles root unless stated
otherwise. Historical measurements and examples are retained as recorded; verify current
state before acting. Read the file for the app you're touching before changing it.

- [Symlink model](architecture/symlinks.md) — how tracked configs reach the live system,
  what's deliberately untracked
- [Neovim](architecture/neovim.md) — submodule vs. plugins, lazy-lock, `:checkhealth`
- [Vim](architecture/vim.md) — lightweight editing, theme toggle
- [IPython](architecture/ipython.md) — profile location, tracked files
- [Zsh](architecture/zsh.md) — entry points, functions, the bgutil/yts `sysup` steps
- [sysclean](architecture/sysclean.md) — NVMe health check, glob-qualifier removals
- [Mirrorlist check](architecture/mirrorlist.md) — the `sysup` step that runs first
- [mirrorlist-rank](architecture/mirrorlist-rank.md) — filtering, timing methodology, safe
  writes
- [config-drift](architecture/config-drift.md) — catching config that silently stopped
  meaning what it used to
- [USB media](architecture/usb-media.md) — vifm `:media`, no automount daemon
- [Tmux](architecture/tmux.md) — identity segment, ssh detection
- [Git](architecture/git.md) — submodule push guard, `core.fsmonitor` off
- [SSH](architecture/ssh.md) — passphrase-protected key, agent lifetime
- [Firefox](architecture/firefox.md) — userChrome, about:config
- [Tridactyl](architecture/tridactyl.md) — Firefox vim bindings
- [Niri](architecture/niri.md) — isolated session, lock screen, sleep hooks
- [Theming](architecture/theming.md) — `Mod+Alt+T` light/dark toggle, GTK appearance
- [systemd user services](architecture/systemd-services.md) — failure notification,
  sandboxing, the `network-online.target` trap
- [rclone](architecture/rclone.md) — Google Drive's personal OAuth client, the `combine`
  remote
- [btrfs subvolumes](architecture/btrfs.md) — snapshot exclusion, the two snapper configs
- [Containers](architecture/containers.md) — rootless podman, Postgres as a Quadlet unit
- [AOCL](architecture/aocl.md) — linking without hijacking system FFTW, BLIS thread count
