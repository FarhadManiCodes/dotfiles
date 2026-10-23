# Herdr Migration: Implementation

Status: **Not started (2026-10-23)**
Decisions, reasons and the draft config live in `docs/herdr-migration.md`; "Step N" below refers to its steps.

Testing a config without touching the live one: copy it to `~/.cache/hx/herdr/config.toml` and run `XDG_CONFIG_HOME=~/.cache/hx herdr config check` (add `--session <name>` for a throwaway session), then delete `~/.cache/hx`. Keep that path short: under the scratchpad, Herdr's socket path exceeds `sun_path` and fails. Prove the check can fail by also running it on a deliberately conflicting key.

---

## Milestones

- **Branches:** one branch per milestone, named `herdr/<n>-<name>`, cut from `master` after these two docs are merged. Each is reviewed and merged before the next one that depends on it starts. Tick the boxes on the milestone's branch. Milestone 1 keeps the `herdr/` name instead of `AGENTS.md`'s `add-<name>-config` on purpose (user decision, 2026-10-23).
- **Order:** 1 → 2 → any order of 3–7 → 8.
- **tmux retires from daily use at Milestone 2.** Nothing else blocks the switch (user decision, 2026-10-23). tmux stays installed only to compare behavior side by side while features are ported, and is removed in Milestone 8.
- **"Prove first" boxes** cover a mechanism that is not chosen yet. They must pass before the build work starts. If one fails, stop and discuss rather than building around it.

| # | Branch | Goal | Status |
|---|---|---|---|
| 1 | `herdr/1-base-config` | Tracked Herdr config live, launcher unchanged | Not started |
| 2 | `herdr/2-switch-launcher` | `Mod+Return` opens Herdr; daily use moves over | Not started |
| 3 | `herdr/3-restart-recovery` | Editors, agents and tools come back after a restart | Not started |
| 4 | `herdr/4-copy-output` | Copy the last command's output, or report unavailable | Not started |
| 5 | `herdr/5-layouts-agents` | `Prefix+W` layout picker, `Prefix+A` agent tabs | Not started |
| 6 | `herdr/6-cpp-tools` | `bash/tmux-cpp-tools` ported to Herdr | Not started |
| 7 | `herdr/7-fzf-pane` | fzf in a temporary split pane inside Herdr | Not started |
| 8 | `herdr/8-retire-tmux` | tmux config, helpers and package removed | Not started |

### Milestone 1: Base config live
Decisions: Steps 2–7 and the draft config.

Work:
- Add `herdr/config.toml` from the draft config, without the placeholder helper commands (C++ and copy-output). Each of those arrives with its own milestone.
- Add the `[app-name=Herdr]` `format` rule to `mako/config` (Step 3).
- Link `config.toml` as a single file in `install.sh`, not the whole directory, and add it to `bash/config-drift` and the explicit file list in `bash/config-drift.d/symlink-integrity.sh` (paths not listed there are skipped). Before linking, compare the independent live `~/.config/herdr/config.toml` with the tracked one and keep anything wanted from it.
- Run `wl-copy` under `setsid` in Vim's `\y` maps (`vim/config/mappings.vim`): `\y` in the `Prefix+e` editor is the daily copy path from Milestone 2, and a bare `wl-copy` can die with the editor.
- Update `docs/architecture/herdr.md` and the README keybinding references.

Acceptance criteria:
- [ ] `herdr config check` passes on the tracked file.
- [ ] `~/.config/herdr/config.toml` is a symlink into the checkout. A listing of `~/.config/herdr` before and after shows sockets, logs and session data untouched.
- [ ] `bash bash/config-drift` reports the Herdr mappings as clean.
- [ ] Pressed by hand in foot, each of these works: `Prefix+$`, `Prefix+|`, `Prefix+Alt+g`, `Alt+Shift+Left/Right` and direct `Alt+1..9`. A key that fails gets a different binding, recorded in Step 5.
- [ ] `Prefix+Shift+g` creates a worktree under `~/.local/share/herdr/worktrees`, not a folder literally named `~` (the config value starts with `~`).
- [ ] Every popup opens in the invoking pane's directory, as tmux's popups did: `Prefix+t` (scratch terminal) and `Prefix+Alt+g` (lazygit shows that pane's repository).
- [ ] `Ctrl+a Ctrl+a` reaches zsh as `Ctrl+a`, which jumps to the start of the line.
- [ ] `Mod+Alt+T` flips Herdr's sidebar and tab bar without a Herdr-specific signal from the script. If it doesn't, the clients-only `SIGWINCH` fallback from Step 4 is added and does.
- [ ] In both light and dark, Herdr's colors look right beside foot and Neovim. A decision on `panel_bg = "reset"` is recorded.
- [ ] `pane_gaps = false` and `true` compared by eye; the choice is recorded in Step 3.
- [ ] `makoctl reload` succeeds, and a Herdr notification shows 🐑 before its title.
- [ ] Copying with `y` in copy mode and with mouse selection is pasted with both `Ctrl+Shift+v` and middle-click. Where each copy lands (clipboard, primary) is recorded in Step 7.
- [ ] Text copied with `\y` in Vim still pastes after Vim has quit.
- [ ] A multi-line paste into zsh and into Neovim does not run anything by itself.
- [ ] `Shift+Enter` works in OpenCode, Claude Code and Codex. The image previews actually used still show, or the gap is recorded.
- [ ] Bare `Ctrl+h/j/k/l` moves between Neovim and Vim splits, and `Ctrl+l` clears the zsh screen.
- [ ] Vim and Neovim pick the right light/dark background inside Herdr.
- [ ] Sioyek inverse search reaches Neovim when its pane is the focused one, with several foot windows open (Step 3, `window_title`). The hidden-pane case is Milestone 5's.

### Milestone 2: Switch the launcher
Decisions: Step 9. Follow `niri/AGENTS.md`; reload with `niri msg action load-config-file`.

Work:
- Change `Mod+Return` in `niri/config.kdl` from `footclient tmux new-session -A -s main` to `footclient herdr`.
- Have `bash/herdr-cargo` link `~/.local/bin/herdr` to the binary where it actually installed it: it honours `CARGO_INSTALL_ROOT`, `CARGO_HOME` and `--root`, so the target is not always `~/.cargo/bin/herdr`. Check the link in `bash/config-drift`. Only zsh's `.zshenv` adds `~/.cargo/bin`; niri, foot's server, fuzzel and `environment.d` do not, so without the link `footclient herdr` opens a window that closes at once.
- Add `applications/herdr.desktop` running `footclient herdr` (linked by `install.sh`'s existing `applications/*.desktop` glob).

Acceptance criteria:
- [ ] `herdr` resolves from foot's server environment, not just from zsh.
- [ ] `Mod+Return` opens foot attached to the default Herdr session. A second `Mod+Return` attaches another client to the same session.
- [ ] Herdr appears in fuzzel and opens the same default session.
- [ ] `Mod+T` (plain foot) and `Mod+Grave` (floating scratch terminal) behave as before.
- [ ] Detach (`Prefix+q`) and reattach keep running programs alive.
- [ ] `tmux` still starts by hand in plain foot, for comparison.
- [ ] foot's `Ctrl+Shift+y` and `Ctrl+Alt+c` tested inside Herdr: run a command with known multi-line output, copy it, and compare the clipboard with the real command, directory and output. If they match, record that they work until Milestone 4. If not, record them as untrusted inside Herdr until Milestone 4 replaces them; they keep working in plain foot (`Mod+T`).

Until Milestone 3 lands, a full restart restores layout, directories and pane history, and Herdr already tries to resume agents (`resume_agents_on_restore` is on from Milestone 1, unproven until Milestone 3); editors and other tools are not relaunched.

### Milestone 3: Restart recovery
Decisions: Step 2R.

Prove first:
- [ ] A relaunch mechanism that records, per persistent pane, which editor and project session or which tool (with its directory, Python environment and database) to start, and starts it after Herdr restores the layout. New pane IDs must not break it.
- [ ] Native resume works for OpenCode, Claude Code and Codex through their Herdr integrations with `resume_agents_on_restore = true`.
- [ ] A saving policy for Vim sessions, and for Neovim launches the current auto-tracking misses (`nvim file`, non-Git directories).

Acceptance criteria:
- [ ] Each case is tested separately: detach and reattach, full server restart, reboot.
- [ ] With several projects in one workspace, each project's editor reopens with its own `Session.vim`: files, splits and editor tabs.
- [ ] OpenCode, Claude Code and Codex each resume their own conversation. Two agent tabs on one project resume as two conversations.
- [ ] `ptpython`, `ptipython`, `htop`, `lazygit` and `duckdb` restart fresh in the right directory, Python environment and database file.
- [ ] Popups (scratch terminal, lazygit, pickers), the `Prefix+e` scrollback editor and Git commit editors do not come back and do not overwrite a project's `Session.vim`.
- [ ] With an unchanged layout, pane history returns. Returned screen text is not counted as a resumed program.
- [ ] The integration prerequisite for a rebuilt machine is documented in `docs/architecture/herdr.md`.

### Milestone 4: Copy last command output
Decisions: Step 7.

Prove first:
- [ ] Routing from a foot key binding to the right Herdr pane, with no race against focus changes.
- [ ] Command boundaries and matching command/directory metadata per shell, not the global `~/.local/state/zsh/last_command`.

Work: write `bash/herdr-copy-output`; add the `Prefix+Shift+y` and `Prefix+Alt+c` entries from the draft config; link and drift-map the helper.

Acceptance criteria:
- [ ] `Ctrl+Shift+y` (raw) and `Ctrl+Alt+c` (command + directory + output) work in plain foot and in Herdr. So do `Prefix+Shift+y` and `Prefix+Alt+c`, with `Prefix+Alt+c` pressed by hand in foot.
- [ ] The copy is complete with output longer than 500 lines, soft-wrapped lines, prompt-like output, two shells running at once, after a `cd` and after a focus change.
- [ ] When output was evicted or the boundaries are missing, the helper reports unavailable and the clipboard is unchanged.
- [ ] Inside a TUI (agent, Vim, Neovim), it reports unavailable.
- [ ] For each of OpenCode, Claude Code and Codex, `Prefix+e` shows useful retained text and `\y` copies the selected lines. The copy still pastes after the editor has closed.

### Milestone 5: Layouts and agent tabs
Decisions: Step 8C.

Work: write the `Prefix+W` and `Prefix+A` helpers, add their key entries, link and drift-map them, and settle initial sizes and focus.

Notes carried over from the removed `TODO.md` item 2 (full text, including Omarchy's `tdl`/`tds`/`tdlm`/`tsl` layout shapes: `git show 8af5af3:TODO.md`, a `master` commit). They were written for tmux; the principles apply to Herdr's pane CLI:
- Address every pane by the ID returned when it is created, starting from the invoking pane's own ID, never "the active pane". Focus can move while the script runs.
- Pass the directory explicitly on every split or new tab.
- Send command text literally, then Enter separately, so text such as `C-m` is not read as a key.
- Omarchy's `tdl` ends with `select-pane -t "$opencode_pane"`, a variable it never sets, so its final focus step silently does nothing. Don't copy it.

Acceptance criteria:
- [ ] `Prefix+W` offers editor + terminal and C++ `code` + `profile`, and builds the layout for the invoking pane's project.
- [ ] `Prefix+W` for a project whose editor is already open focuses that editor. There is no duplicate, and the layout is unchanged. The editor is found by project, not by tab or workspace name.
- [ ] `Prefix+A` offers OpenCode, Claude Code and Codex, and opens a new tab for the invoking pane's project. Existing agent tabs are untouched. AGY is left out on purpose (user decision, 2026-10-23).
- [ ] Both helpers handle a project path with spaces, a missing agent command (clear message, nothing half-built), a small terminal, being run twice in a row, and focus changing while they run. They run no command beyond the layout and the chosen agent.
- [ ] Both keys work correctly when two projects share a workspace.
- [ ] Investigated and decided: Sioyek inverse search when Neovim's pane is not focused. The handler (`nvim/lua/plugins/documents.lua`) only matches a foot window title containing "NVIM", which shows the focused pane, and after Milestone 2 two foot windows attached to the same session can both carry it (the handler takes the first match). Reaching a hidden editor, or the right one of two windows, needs the same find-the-project's-editor lookup as `Prefix+W`; fix it with that lookup, or record it as a known gap.
- [ ] No hooks, dashboards or coordination were added; those stay for the agentic-layer session.

### Milestone 6: C++ tools
Decisions: Step 8D. Baseline: `bash/tmux-cpp-tools`; the new helper name is provisional.

Prove first:
- [ ] A runner that starts tasks in the selected project's tabs without typing into a running TUI.
- [ ] Per-project editor lookup that replaces the global first-Neovim-pane lookup.

Acceptance criteria:
- [ ] `Prefix+C` opens the menu from any pane, including an editor or another TUI, and types nothing into it.
- [ ] Every existing action is present: configure; build, test, build+test; executable selection and arguments; source navigation from failures; GDB, Valgrind, clang-tidy, Google Benchmark, hyperfine, perf and samply; ccache statistics; project creation; clean. Clean-all keeps its guard.
- [ ] `Prefix+B` quick-builds with the same targeting.
- [ ] The build tab is reused when idle and keeps the previous output. When busy, the helper says so and focuses the tab, without interrupting, queueing or overlapping.
- [ ] Programs run in their own tabs, GDB in the debug tab, and profiling in the project's profile tab. Lifecycle matches the tmux version when compared side by side.
- [ ] The clean-all guard tests in `tests/test_tmux_cpp_tools.py` (no deleting through a symlinked build, no cache naming another tree) are ported to the new helper and pass.
- [ ] With two C++ projects in one workspace, every action and source jump hits the right project and editor, even when focus changes mid-task.

### Milestone 7: fzf temporary pane
Decisions: Step 9 (fzf).

Acceptance criteria:
- [ ] Inside Herdr, the history, file and directory widgets open fzf in a temporary split. The result reaches the original shell: history edits its command line, files are inserted there, and the directory changes there.
- [ ] Scripted fzf callers receive the selection and exit status. Cancelling is a cancel and does not reopen inline.
- [ ] The pane closes and focus returns after a selection, a cancel or an error, with no shell left behind.
- [ ] Concurrent pickers, paths with spaces or newlines, previews and keys behave as they do inline.
- [ ] If the pane cannot open, fzf falls back to inline and any partial pane is cleaned up.
- [ ] Plain foot keeps inline `--height 40%`.
- [ ] The picker pane does not come back after a restart.

### Milestone 8: Retire tmux
Decisions: Steps 6, 8A, 9.

Work:
- Remove `tmux/`, `bash/tmux-cpp-tools`, `tests/test_tmux_cpp_tools.py`, the tmux block in `bash/toggle-foot-theme.sh` (add nothing in its place, Step 4), the TPM updater in `zsh/functions/sysup/plugins.zsh` and the `--tmux` line in `zsh/functions/fzf.zsh`.
- Remove `vim-tmux-navigator` from Neovim (`nvim/lua/plugins/editor.lua`, as a submodule commit plus a parent pointer update) and from Vim (`vim/config/plugins.vim`), and add native `<C-h/j/k/l>` and `<C-\>` split maps (`nvim/lua/config/keymaps.lua` and Vim's mappings).
- Remove the tmux mappings from `install.sh`, `bash/config-drift` and its plugin scan, and `bash/config-drift.d/symlink-integrity.sh`. Update the README and `docs/architecture/`.
- Write a much more concise user-level version of `docs/herdr-migration.md` into `docs/architecture/herdr.md`: keys, behavior and the reasons that still matter.
- Remove only the tracked links and plugin clones from `~/.config/tmux`.

Acceptance criteria:
- [ ] A `tmux` grep over tracked files finds only intended mentions (history and notes).
- [ ] `Ctrl+h/j/k/l` and `Ctrl+\` still move between Neovim and Vim splits. `cd nvim && nvim --headless -c 'lua dofile("tests/runtime.lua")'` and `:checkhealth` pass.
- [ ] Personal files in `~/.config/tmux` remain.
- [ ] `docs/architecture/herdr.md` covers the keys, behavior and reasons in a short read, without implementation notes.
- [ ] `bash bash/config-drift` is clean, and the relevant suites pass under `bash bash/run-tests`.
- [ ] The sysup path for Zsh, Vim and Neovim plugin updates is unchanged (checked by reading the code and running `shellcheck`, not by running `sysup`).
- [ ] The tmux removal transaction is inspected first and removes only tmux. The user runs it.
