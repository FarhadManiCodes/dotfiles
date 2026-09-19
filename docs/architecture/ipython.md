# IPython

`IPYTHONDIR` is `~/.config/ipython` (set in `zsh/.zshenv`), launched from Zsh — the
directory override doesn't belong in Niri's `environment.d` defaults (see
`docs/system-notes.md`, "Environment variables").

Three tracked files, all hand-written:
- `ipython_config.py` — autoreload, `nvim` as editor, no exit confirmation, verbose
  tracebacks
- `startup/00-imports.py` — preloads `numpy`, `polars`, `pathlib.Path`
- `startup/01-theme.py` — reads `foot_theme_state`, the fourth `Mod+Alt+T` consumer after
  vim, nvim and ptpython

`history.sqlite` is the only other file in the profile and is deliberately untracked
(state). All three tracked files were untracked until the 2026-09-04 `~/.config` sweep.
