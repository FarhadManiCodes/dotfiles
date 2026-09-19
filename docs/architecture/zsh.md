# Zsh

- **Entry**: `~/.zshrc` + `~/.zshenv`
- **Config dir**: `~/.config/zsh/`
- **Aliases**: `zsh/aliases`
- **Helpers**: `zsh/helpers.zsh` — `safe_source` and utilities
- **Functions** (`zsh/functions/`):
  - `audio.zsh` — `playaudio`, fzf-driven mpv queue for `~/Audio`
  - `clipboard.zsh` — Wayland file copy
  - `cpp.zsh` — C++ build helpers (cmake/ninja/ccache)
  - `fzf.zsh` — FZF config + `fnb` (Jupyter finder) + `fdata` (data file finder)
  - `git-enhancements.zsh` — `gci`, `gst`, `gstds`
  - `last_working_dir.zsh` — restore last directory
  - `papis.zsh` — `pask` wrapper (papis-ask + llama.cpp embedding server)
  - `pdf.zsh` — PDF/book search with rga + fzf
  - `search.zsh` — `ff`, `fdir`, `fgit`, `rgf`, `rgpy`, `rgcpp`
  - `shpool.zsh` — detachable `keep`, per-repository `lg`, interactive `attach`
  - `sysclean.zsh` — system & cache cleanup, see [sysclean.md](sysclean.md)
  - `sysup.zsh` — full system update (mirrorlist → paru → uv → bgutil → yts → Cargo →
    Claude Code → plugins → nvim `:checkhealth` → images → fwupd → `config-drift`)
  - `virtualenv.zsh` — full uv+direnv venv management (`vc`, `va`, `vp`, `vd`, `vl`, `vr`)
- **Plugins** (clones untracked; list lives in `zsh/update-plugins.sh`):
  fast-syntax-highlighting, zsh-autosuggestions, zsh-history-substring-search

| Command | Purpose |
|---|---|
| `z <dir>` | Jump (zoxide) |
| `ll`, `la` | eza listings |
| `vc [name] [template]` | Create venv |
| `va [name]` | Activate venv — bare `va` picks from central venvs plus a `./.venv` (listed as `local`); `va local` activates for the session only, `va <central-name>` writes an `.envrc` so direnv takes over |
| `vl` | List venvs |
| `vs [--prune]` | Install requirements into this project's `.venv` or a central environment; `--prune` removes unlisted packages only from this project's non-symlinked `.venv`. Other environments are rejected. |
| `fnb` | Find + open Jupyter notebook |
| `fdata` | Find data/model files |
| `gci` | Interactive commit |
| `gstds` | Git status with data science awareness |
| `ff` | Fuzzy file finder |
| `rgf` | Live ripgrep with preview |

## yt-dlp's token helper

Immediately after uv updates, `_sysup_bgutil` compares the installed Python plugin
version against the runnable Node helper at `~/.local/share/bgutil-pot`. A mismatch
fetches that exact release, runs `npm ci --ignore-scripts` and the local TypeScript
compiler in a staging directory, then gates the swap on **generating a real token**, not
just `generate_once.js --version`. Matching versions need no fetch or build; missing
installs are skipped; local edits are preserved. Any failure stops `sysup` nonzero. The
previous helper is kept at `bgutil-pot.update.*/previous` (auto-restored on a failed
rename, otherwise retained for manual recovery). Closes the 2026-09-17 failure where uv
updated the plugin to 2.0.0 but left the helper at 1.3.1.

`--ignore-scripts` and the token gate arrived together and depend on each other: `npm ci`
otherwise runs the dependency tree's install scripts (arbitrary code execution at build
time), and neither declared script here is actually needed (`@swc/core` an unused dev
dep, `canvas` an optional peer of `jsdom` absent from the compiled output). A
scripts-free build was measured generating a real token, 23 MB smaller. The gate matters
because **`--version` is not evidence of a working build** — it reported `2.0.0` from a
tree missing `canvas`'s native binary entirely, so a genuinely broken build would have
passed and been promoted over a working helper. Failure counts as a bad build only when
`youtube.com` is reachable; offline, it's reported NOT CHECKED and the version-checked
build installs anyway, rather than blocking `sysup` on a dropped connection.

## yts, the one locally-built app

`_sysup_yts` compares `~/projects/yts`'s HEAD against the commit recorded at install time
in `~/.local/share/yts-gui/.installed-commit` (yts's own `make install` writes it, since
`__version__` marks releases, not commits). A mismatch runs `make test`, `make install`,
then proves the result imports — `uv pip install` succeeding isn't evidence the launcher
works. Non-fatal unlike bgutil: a stale launcher is an older working app, so it warns and
`sysup` continues.

Refuses a dirty worktree, **checking untracked files too** — `make install` runs
`uv pip install .` against the worktree, so an untracked new module ships exactly like a
modified one. Both directories are passed as arguments because `make install` runs
`uv venv --clear`, which would wipe a live prefix. Exists because the launcher sat three
months stale on 2026-09-17 while starting and running fine.
