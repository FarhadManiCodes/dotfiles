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
  - `sysup.zsh` — full system update (mirrorlist → paru → uv → bgutil → yts → Cargo → Herdr →
    Claude Code → plugins → nvim `:checkhealth` → fwupd → `config-drift`);
    `sysup --podman-images` also updates installed Quadlet images, including stopped ones;
    `sysup --test-tools` also runs my own uv tools' test suites on the newest dependencies
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
| `batt` | Battery status, power draw, CPU/GPU/NVMe temperatures and both fan speeds |
| `ff` | Fuzzy file finder |
| `rgf` | Live ripgrep with preview |
| `sysup [--podman-images] [--test-tools]` | Update the system; include installed Quadlet images or the own-tool dependency tests only when requested |

`sysup` and `sysclean` automatically use `keep` to start a fresh shpool session.
Inside an existing shpool session (`SHPOOL_SESSION_NAME` set), they run there
without nesting. Missing shpool/`keep` stops the command with an error. Arguments
are preserved, including `sysup --podman-images` and `sysclean --all`.
Closing the terminal detaches; use `attach` or Mod+A to reconnect. Ctrl+C in `sysup` skips the
running step or stops the run, see [Ctrl-C in sysup](#ctrl-c-in-sysup). Reload `~/.zshrc` in shells
already open after changing these functions.

`sysup --test-tools` (`sysup/tool-tests.zsh`) runs the suites of mathunicode, paper-refinery and
audio_text (the dictate project) in `~/projects` with `uv run --isolated --upgrade`: a throwaway
environment on the newest allowed dependencies, because the projects' own `uv.lock` pins their
tests to known-good versions and a breaking release would otherwise show up only in the installed
tool. Neither the lockfile, the project `.venv` nor the installed tool is touched. A failing suite
is reported with its pytest summary and the end of its output; a suite that could not run (no pytest
summary, or pytest exit 4/5: resolving, network or build failure, nothing collected) or timed out
(600 s, stdin closed) is reported separately, so it is not mistaken for a broken tool. Both kinds are
repeated before the closing line and `sysup` continues. A run that cannot even create its temporary
file is recorded as "could not start". A project without a checkout is skipped. It adds about 40
seconds, hence opt-in.

The lock descriptor is closed in the steps that run in a subshell (tool tests, bgutil, yts, Herdr), so
a process one of them leaves behind cannot keep the concurrency lock held. The steps run directly in
`sysup`'s shell (paru, uv, Cargo, Claude, plugins, nvim health, podman, fwupd) still pass it on; none
of them is known to leave a process behind. If one ever does, close it there the same way.

`sysup` continues past a failed `uv tool list`, `uv tool upgrade --all`, yts install or Herdr update.
Each failure is reported where it happens and repeated after the last step, and again when the run
stops early (a bgutil or Cargo failure, or Ctrl-C); a run with recorded failures or skips ends
"sysup finished with warnings" and returns non-zero (the podman status when the image update failed,
otherwise 1).

## Ctrl-C in sysup

Measured in an interactive zsh on a pty: with no handling, Ctrl-C aborts the whole `sysup` call at
once but skips a plain EXIT trap, leaking the sleep inhibitor and the lock. So `sysup` does its
cleanup in a `{ … } always { … }` block and handles the key itself:

| Where | First Ctrl-C | Second within 2 s |
|---|---|---|
| paru, before pacman logged `transaction started` (prompt, sudo, downloads) | skip paru, continue | stop |
| paru, after `transaction started` (or the log position unreadable) | stop | – |
| bgutil | stop | – |
| every other step | skip the running command, continue | stop |

- **Skip** kills the running command (the terminal sends SIGINT to the whole foreground group), prints
  "Ctrl-C: skipping the running command in <step>", and the run moves on. The skip is recorded and
  repeated last as "skipped with Ctrl-C: the running command in <step>", so the run ends "finished
  with warnings" and non-zero. A step that returns the killed command's own status (the tool tests,
  paru, Cargo) does not also report it as a failure. A step that folds several commands into one
  result does: the podman loop turns a skipped `podman pull` into "pull failed" and a plain status 1,
  which is true, since that image was not updated. A later failure in the same step is reported,
  unless it carries the skipped command's own exit status. Only a command that was running counts
  (`$?` on entering the trap is non-zero): with nothing running the key press is ignored ("nothing
  to skip") and a second within 2 s still stops. It is per running command: in a multi-command step
  (plugins, Claude update and prune, the podman loop, one suite of the tool tests) the step goes on
  with its next command.
- **Stop** ends `sysup` at once. The always block releases the sleep inhibitor and the lock, removes
  the Herdr reason file and the tool-test temp file, and prints the failures and skips recorded so
  far. No "finished with warnings" or "done" line is printed, and the shell abandons the whole command
  line, so there is no exit status to read.
- **Why those two stop:** a half-installed package transaction must not be built on by the uv, yts and
  Cargo steps, and skipping bgutil leaves yt-dlp and its token helper mismatched. Before pacman logs
  `transaction started` (written after the prompt, sudo and downloads) nothing has been installed, so
  paru can be skipped. `sysup` reads the part of `/var/log/pacman.log` written since the run began
  (the byte offset it already records for the config-drift check); a log that was rotated or
  truncated since then counts as started, because the offset no longer means anything.
- **Mechanism:** a `TRAPINT` function exists only while `sysup` runs (one you defined yourself is put
  back afterwards; `local_traps` does not cover functions). Returning 130 (128 + SIGINT) makes
  zsh abort as usual; returning 0 lets the run continue. A `trap '…' INT` string does not abort on a
  non-zero return, and `return` in it leaves only the innermost function; both measured.
- **Latency:** every `timeout` around a foreground command uses `--foreground`. Plain `timeout` starts
  its command in a new process group, which the terminal's Ctrl-C does not reach; a plain `timeout 6`
  held Ctrl-C for about 5 s, `--foreground` for 0.1 s. The price: on expiry only the direct child gets
  the signal, so the pytest that a timed-out `uv run` started can outlive the 600 s limit.
- **Known gap:** a Ctrl-C landing between two commands of one step can leave the skip mark set. A real
  failure later in that step with the skipped command's own exit status is then not repeated; the skip
  itself still is, so the run still ends with warnings.
- **Not covered:** pacman and paru roll back (or not) by their own rules; SIGTERM is ignored by an
  interactive zsh, so it does nothing to `sysup`; a hung-up or killed shell (`shpool kill`) runs
  neither the always block nor an EXIT trap (measured), so the Herdr reason file stays behind, but the
  sleep inhibitor still ends because the kernel hangs up the whole pty session; `herdr-cargo` run alone exits 130 on Ctrl-C and
  `install.sh` reports that as "interrupted", not a failure.

`batt` uses `bash/hardware-readings`, shared with the Mod+Shift+N temperature
notification. Each request invokes `sensors -j` once and `jq` once, without
background monitoring. The helper returns five tab-separated display values:
CPU, GPU, NVMe, Fan 1 and Fan 2. It matches chip prefixes and reads k10temp's
Tctl, amdgpu's edge, NVMe's Composite and ThinkPad's two fan inputs, excluding
redundant ACPI readings and PWM. Temperatures have one decimal place; zero RPM
is preserved and missing/null/nonnumeric readings show `N/A`. Invalid or empty
JSON produces five `N/A` values, exit status 1 and an explanatory message from
the caller; valid JSON is used even if unrelated subfeatures report read errors.
The installer links the helper through its existing `bash/*` mapping. Reload
`~/.config/zsh/helpers.zsh` to update `batt` in an existing shell.

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

## yts

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

## Herdr stable Cargo builds

After registry Cargo updates, `_sysup_herdr` invokes `bash/herdr-cargo --update`.
Missing Herdr installations are skipped; a failed update is reported with its reason and `sysup` continues
(`HERDR_CARGO_REASON_FILE` carries the helper's `die` message back). The helper
resolves the latest stable tag to a commit, provisions that release's compatible
Zig temporarily, and uses the measured Zen 4/fat-LTO recipe. It checks a staged
build before promotion and preserves running sessions. See [Herdr](herdr.md)
for installation, provenance, cleanup and the benchmark's limits.

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
