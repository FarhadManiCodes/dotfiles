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
  - `pdf.zsh` — book search with fzf; `rgbook` searches refinery's sibling Markdown
    review copies with physical PDF page markers
  - `search.zsh` — `ff`, `fdir`, `fgit`, `rgf`, `rgpy`, `rgcpp`
  - `shpool.zsh` — detachable `keep`, per-repository `lg`, interactive `attach`
  - `sysclean.zsh` — system & cache cleanup, see [sysclean.md](sysclean.md)
  - `sysup.zsh` — full system update (mirrorlist → paru → uv → bgutil → yts → Cargo →
    Claude Code → plugins → nvim `:checkhealth` → fwupd → `config-drift`);
    `sysup --podman-images` also updates installed Quadlet images, including stopped ones
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
| `sysup [--podman-images]` | Update the system; include installed Quadlet images only when requested |

`rgbook` searches completed sibling `<stem>.md` review copies, not the internal
`<stem>.refinery/refinery.md` used for re-chunking. It keeps refinery's one-based physical page
number for Sioyek's `--page`; books without a review copy have no results.
`pdf-meta yloc` reads that page's bounds with MuPDF and passes half its height as
`--yloc`, because Sioyek otherwise centers the page's top boundary and leaves the
preceding page in view. `fbook` and vifm use `pdf-meta preview` for embedded title,
author, page count and a short first-page text excerpt (no OCR or papis metadata fallback).

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
in `~/.local/share/yts-gui/.installed-commit` (yts's own `make install` writes it, since the
version marks releases, not commits). A mismatch runs `make test` (CMake, ctest under
ASan), then `make install` (release build, then a stripped install into `~/.local`), both
with `CMAKE_BUILD_PARALLEL_LEVEL=8`, the physical core count, and then proves the installed
`~/.local/bin/yts` runs (`--version`): a reported success isn't evidence the binary works.
`make install` builds before it copies, so a failed build leaves the previous binary in
place. Non-fatal unlike bgutil: a stale binary is an older working app, so it warns and
`sysup` continues.

Refuses a dirty worktree, **checking untracked files too**: an untracked header that a
tracked source includes ships exactly like a modified file. The checkout, the install
state and the binary directory are arguments so the tests never touch the live install.
Exists because the launcher sat three months stale on 2026-09-17 while starting and
running fine. Rewritten for the C++ version on 2026-10-06 (TODO item 13).

Tridactyl's `,y ,Y ;y ;Y` call `~/.local/bin/yts --play` directly, with `-a` for
audio. URLs go on stdin through `native.run`'s second argument, never into shell commands.

## Startup and prompt cost

Measured 2026-10: a new interactive shell ~44 ms (bare zsh 3 ms), a prompt ~3 ms outside git.
What keeps it there, and what not to undo:

- **No forks on the hot paths.** `.zshenv` is read by every zsh, scripts included, so it
  forks nothing (`OPENBLAS_NUM_THREADS=8` is hardcoded, machine-specific); variables only
  an interactive tool reads (`_ZO_*`, `FAST_WORK_DIR`) live in `.zshrc`, **exported** when an
  external program reads them. No `$(basename …)` in loops: use `${f:t}`.
- **Prompt segments come from a hook, not starship custom modules.** A custom module with
  `when=` ignores `detect_*` and forks a shell on every prompt in every directory. The
  `_prompt_env` precmd hook sets `STARSHIP_VENV` and `STARSHIP_GIT_HOST` (`env_var`
  modules); the host icon is git's answer cached per repo, refetched when its `.git/config`
  mtime changes. `cmake_build_type` uses `detect_files` (project root only). `direnv` runs
  only where an `.envrc` exists above or one is loaded.
- **`ZSH_AUTOSUGGEST_MANUAL_REBIND=1`**: the default re-binds every zle widget before each
  prompt (~13 ms).
- **`_zcompile_stale`** keeps `.zwc` copies of everything sourced at startup (beside the
  sources in `~/.config/zsh`, `~/.cache`; never in the repo). A stale `.zwc` is ignored, so
  a missed recompile only costs speed. `compinit` touches and compiles its dump daily.
- **Caps:** `HISTSIZE=SAVEHIST=10000` (~195 B per entry); tmux `history-limit` and foot
  scrollback 10000 (~540 B per tmux line per pane).
- **Probe from `/tmp`.** An interactive probe shell saves its directory as the last working
  directory on exit (`last_working_dir.zsh`).
