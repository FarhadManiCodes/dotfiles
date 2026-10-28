# IPython

`IPYTHONDIR` is `~/.config/ipython` (set in `zsh/.zshenv`), launched from Zsh — the
directory override doesn't belong in Niri's `environment.d` defaults (see
`docs/system-notes.md`, "Environment variables").

Two tracked files, both hand-written:
- `ipython_config.py` — autoreload, `nvim` as editor, no exit confirmation, verbose
  tracebacks, and the session's imports (`numpy`, `polars`, `pathlib.Path`) as
  `exec_lines`, one entry each, so a venv missing one still gets the rest
- `startup/01-theme.py` — reads `foot_theme_state`, the fourth `Mod+Alt+T` consumer after
  vim, nvim and ptpython

`history.sqlite` is the only other file in the profile and is deliberately untracked
(state). The tracked files were untracked until the 2026-09-04 `~/.config` sweep.
