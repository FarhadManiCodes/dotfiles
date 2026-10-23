# Migration Plan: `tmux` to `herdr`

Status: **In-progress design & brainstorming checkpoint (2026-10-23)**
Branch: `switch-tmux-to-herdr` (non-master, per `AGENTS.md`); the earlier `add-herdr-config` branch is already merged.

---

## 1. Progress Ledger

| Step | Topic | Status |
|---|---|---|
| **Step 1** | Coexistence vs. Replacement & Mental Model | ✅ Decided |
| **Step 2** | Core `[terminal]`, `[session]`, `[update]`, `[worktrees]`, `[advanced]` | ✅ Settings decided; restart behavior tracked in 2R |
| **Step 2R** | Editor, agent and tool recovery after reboot / full server restart | 🔧 Restore behavior agreed; temporary popups excluded; relaunch mechanism unresolved |
| **Step 3** | UI Chrome, Sidebar, Bottom Tab Bar, Clock & Notifications (`[ui]`) | ✅ Decided |
| **Step 4** | Theme Integration (`[theme]` + `Mod+Alt+T` live switch) | ✅ Decided |
| **Step 5** | Prefix & Core Keybindings (`[keys]` & `[[keys.command]]`) | ✅ Decided |
| **Step 6** | Pane & Neovim Split Navigation + Neovim/Vim Simplification | ✅ Decided |
| **Step 7** | Clipboard, Copy Mode & Unified Last-Command Output Capture | ✅ Shortcuts and behavior decided; reliable capture implementation unresolved |
| **Step 8A** | Retire `Prefix + S` (Session Menu) & `Prefix + V` (Virtualenv Menu) | ✅ Decided; persistence replacement must satisfy 2R before cutover |
| **Step 8B** | Retire `Prefix + G` Menu; keep `Prefix + Shift+g` worktree; add `lazygit` popup on `Prefix + Alt+g` | ✅ Decided |
| **Step 8C** | Basic project layouts and separate agent tabs | ✅ Basic placement, picker, multiple tabs and shortcuts agreed; full agentic layer deferred |
| **Step 8D** | C++ popup menu, project task tabs and shortcuts | ✅ Entry point, build-tab rules, keys and run/debug/profile destinations decided; port details remain |
| **Step 9** | System Touchpoints (`niri/config.kdl`, `fzf.zsh`, `sysup`, `install.sh`, `config-drift`, retiring `tmux/`) | 🔎 In review; fzf temporary-pane direction chosen; adapter needs validation |

---

## 2. Decisions and Remaining Design Work (Steps 1–9)

### Step 1: Transition Strategy & Mental Model
- **Direct Cutover:** Full replacement of the local `tmux` workflow with `herdr`; uninstall local tmux after validation, not before. Implementation and validation precede launcher/config retirement and package removal.
- **Hierarchy Mapping (Style 1 — "The Herdr Way"):**
  - **Herdr `Session`** = Persistent background server (attached automatically via bare `herdr`); one session can contain several projects.
  - **Herdr `Workspace` (Space)** = Organizational group in the left sidebar, with Git/worktree and agent features. One workspace can also contain several projects in different tabs/panes. One workspace per project is an optional convention, not a requirement.
  - **Herdr `Tab`** = What `tmux` called a **Window** (`1..9` along the bottom bar, scoped per Workspace, not per project).
  - **Herdr `Pane`** = Splits inside a Tab.
  - **Editor session scope:** One ordinary Vim or Neovim instance per project, with that editor's own tabs and split windows. Several projects/editors can coexist in the same Herdr session or workspace. Project/session lookup must be independent of the workspace directory or name.

### Step 2: Core `[terminal]`, `[session]`, `[update]`, `[worktrees]`, `[advanced]`
- **`[terminal]`:**
  - `default_shell = ""` (uses `$SHELL`, i.e., `zsh`)
  - `shell_mode = "non_login"` (explicitly matches `foot` and `tmux` on Arch Linux)
  - `new_cwd = "follow"` (new panes and tabs inherit the active pane's current working directory automatically)
  - `kitty_graphics = false` (`foot` uses Sixel, not Kitty graphics protocol)
- **`[update]`:**
  - `channel = "stable"`
  - `version_check = false` (binary updates are managed by `sysup` via `bash/herdr-cargo`)
  - `manifest_check = true` (declaratively updates agent-detection rules so `opencode`/`claude` states stay accurate between Herdr releases)
- **`[worktrees]`:**
  - `directory = "~/.local/share/herdr/worktrees"` (XDG-clean path instead of `~/.herdr/worktrees`)
- **`[session]` & `[experimental]`:**
  - `resume_agents_on_restore = true`
  - `startup_per_agent_delay_ms = 100`
  - `experimental.pane_history = true` (persists recent pane screen history across full server restarts, replacing the screen-history part of `tmux-resurrect`; upstream replays it only when the restored layout exactly matches the saved one, so a changed layout can come back without history; does not relaunch ordinary programs or restore editor sessions)
- **`[advanced]`:**
  - `scrollback_limit_bytes = 5000000` (5 MB per pane; dynamically allocated up to cap; retained line count depends on content and terminal storage)

### Step 2R: Recovery After Reboot / Full Server Restart
- **Separate live persistence from restart recovery:** Detaching keeps existing pane processes alive. After a reboot or full server restart, Herdr restores layout/directories and optionally screen history; ordinary processes need a relaunch mechanism. Old screen text is not a running program.
- **Editors — agreed behavior:** Automatically reopen each project's ordinary Vim/Neovim editor and restore its open files, splits and editor tabs where supported.
  - Keep **one project-root `Session.vim` per project**. The user normally has one ordinary editor instance per project; separate session files per Herdr pane are not required for this workflow.
  - Neovim already uses `tpope/vim-obsession`, auto-started for bare `nvim` inside a Git repository; it writes to the Git root, including when launched from a subdirectory. This does not establish automatic saving for every launch, such as `nvim file` or a non-Git directory.
  - Vim supports session files but currently has no automatic session-saving setup. Its saving policy still needs implementation; no new plugin has been selected.
  - The restore mechanism must remember which editor and project session belong to each persistent pane, then launch the correct editor with that session. Do not assume a workspace represents only one project or that newly assigned pane IDs necessarily match the old ones.
  - Editor session files restore editing structure; they do not by themselves preserve unsaved buffer text.
  - **Exclude temporary editor views:** `Prefix+e` scrollback, Git commit-message editors, and editors opened inside popups must not be automatically restored or overwrite an ordinary project session.
- **All temporary popup instances are excluded from restoration — agreed:** This applies to tools as well as editors, including the popup scratch terminal, lazygit popup and temporary pickers/menus. Restore eligible ordinary persistent panes/tabs only; do not turn temporary popup activity into a persistent task on restart.
  - This also applies to the proposed temporary fzf split pane in Step 9: its temporary purpose does not become persistent merely because it uses a normal split instead of a floating popup. Establish and test exclusion from restart recovery rather than assuming native pane snapshots omit it.
- **Agents — agreed basic scope:** Automatically resume supported conversations for **OpenCode, Claude Code and Codex** through their existing Herdr integrations. All three report current integrations on this machine as of the review. Verify native resume behavior and document the integration prerequisite for rebuilds. Preserve current hooks/configuration; custom hooks, dashboards, orchestration and broader agent recovery architecture belong to the separate future agentic-layer design session.
- **Other tools — accepted first version:** Reopen `ptpython`, `ptipython`, `htop`, `lazygit` and `duckdb` in eligible persistent panes/tabs, corresponding to the current tmux-resurrect process list. Fresh processes in the correct project directory, Python environment and saved database are acceptable for now. Restoring Python variables, an in-memory DuckDB database or other application memory is deferred; no mechanism for that is selected or promised. The relaunch mechanism still needs design and testing, including how to recover the required environment/database launch context. Temporary popup instances are excluded under the rule above.
- **Implementation remains unresolved:** These requirements are not provided by the draft TOML alone. Establish and validate a feasible relaunch mechanism before removing tmux-resurrect.

### Step 3: UI Chrome, Sidebar, Tab Bar, Clock & Notifications (`[ui]`)
- **Sidebar:**
  - `sidebar_start_collapsed = false`
  - `sidebar_collapsed_mode = "hidden"` (collapses to 0 width when toggled with `Prefix + b`)
  - `sidebar_width` / `sidebar_min_width` / `sidebar_max_width` kept at defaults (`26` / `18` / `36`)
- **Bottom Tab Bar & Clock:**
  - Since Niri runs without a desktop status bar, the bottom tab bar remains the persistent clock/date display:
  - `tab_bar_position = "bottom"`
  - `hide_tab_bar_when_single_tab = false` (must stay visible even with 1 tab so the clock never disappears)
  - `tab_bar_right` shows `{ type = "zoom" }`, `{ type = "datetime", format = " %H:%M" }`, and `{ type = "datetime", format = " %d-%b" }` with `tab_bar_right_separator = "  "`.
- **Pane Borders & Scrollbars:**
  - `pane_borders = "auto"`
  - `pane_outer_borders = false` (no outer box frame around the screen edge)
  - `pane_scrollbars = false` (reclaims scrollbar column and keeps it out of selections)
  - `pane_gaps = false` (single 1-cell shared divider line between splits; marked in Section 4 to visually test against `true`)
- **Prompts & Confirmations:**
  - `prompt_new_tab_name = false` (`Prefix + c` opens a new tab immediately without prompting for a name first)
  - `prompt_new_workspace_name = false` (default)
  - `confirm_close = true` (default: asks before closing a workspace)
- **Outer Window Title:**
  - `window_title = "{workspace}: {terminal_title}"` (includes `{terminal_title}` so `nvim` surfaces `"NVIM"` to `foot` for `VimtexEventViewReverse` inverse search from Sioyek; marked for live test/revisit)
- **Notifications & Mako Integration:**
  - `ui.sound.enabled = false`
  - `ui.toast.delivery = "system"` (`notify-send --app-name Herdr`) with `delay_seconds = 1`
  - Track upstream's official vector icon (`assets/logo.svg` at `v0.9.5`) as `herdr/logo.svg` -> `~/.config/herdr/logo.svg`, and add to `mako/config`:
    ```ini
    [app-name=Herdr]
    default-icon=/home/farhad/.config/herdr/logo.svg
    ```

### Step 4: Theme Integration (`[theme]` + `Mod+Alt+T`)
- **Built-in OneDark / OneLight Auto-Switching:**
  - `name = "one-dark"`
  - `auto_switch = true`
  - `dark_name = "one-dark"` (matches `nvim`, `vim`, `ptpython`, and `ipython` dark themes)
  - `light_name = "one-light"`
- **Live Switching via `Mod+Alt+T` (`bash/toggle-foot-theme.sh`):**
  - Delete the old `tmux source-file ...` block from `bash/toggle-foot-theme.sh` and add nothing in its place. The script already signals foot (`SIGUSR1`/`SIGUSR2`); Herdr's binary requests terminal light/dark notifications (`?2031h`), so with `auto_switch = true` it should follow foot's switch by itself. This is unproven: foot sending those notifications to Herdr has not been observed (see Section 4, item 3).
  - **Fallback if it does not follow:** send `SIGWINCH` to Herdr *clients only* (upstream: "send `kill -WINCH <client-pid>` after applying the new palette"). Not `pkill -x herdr`, which also hits the server; the client/server process names must be checked first.
  - **Trap:** choosing a theme in Herdr's Settings (`Prefix+s`) turns `auto_switch` off, after which `Mod+Alt+T` stops changing Herdr's colors until it is set back in the config. Change the theme in `config.toml`, not in Settings.
  - Note: `nvim` and `vim` use `termguicolors` and paint their own pane interiors (`onedark` / `newpaper` / `PaperColor`), while Herdr's `[theme]` only colors Herdr's UI chrome (sidebar, bottom tab bar, split dividers, popups).

### Step 5 & Step 6: Keybindings & Pane/Neovim Navigation
- **Clean Separation of Pane vs. Neovim Split Navigation (Step 6):**
  - Bare `Ctrl+h/j/k/l` is **not** intercepted by Herdr:
    - Inside `nvim` / `vim`, `<C-h/j/k/l>` navigates editor splits natively (`<C-w>h/j/k/l`, `<C-\>` -> `<C-w>p`), allowing us to **remove `christoomey/vim-tmux-navigator`** from `nvim/lua/plugins/editor.lua`.
    - Inside `fzf` and Telescope, `<C-j>` / `<C-k>` navigate items without any `ps` shell-check latency.
    - Inside `zsh`, bare `Ctrl+l` clears the screen normally (no `Prefix + Ctrl+l` workaround needed).
  - Across Herdr Panes:
    - `Prefix + h/j/k/l` focuses Herdr panes Left / Down / Up / Right (Herdr default).
    - `Prefix + Shift+h/j/k/l` swaps Herdr panes Left / Down / Up / Right (Herdr default, matching Niri's `Mod+Shift+H/J/K/L`).
- **Complete Keymap Summary:**
  - `prefix = "ctrl+a"` (decided). Pressing it twice sends a literal `Ctrl+a` to the pane, like tmux's `send-prefix`: tested on 0.9.5 with `cat -v`, one press is consumed by Herdr, two reach the program as `^A`. This keeps zsh's `bindkey '^a' beginning-of-line`, Vim's insert/command-line `<C-A>` maps and normal-mode increment working.
  - `detach = "prefix+d"` (matches tmux `Prefix + d`)
  - `reload_config = "prefix+shift+r"` (Herdr default)
  - `resize_mode = "prefix+r"` (Herdr default interactive resize mode)
  - `split_vertical = "prefix+|"` and `split_horizontal = "prefix+minus"` (matches tmux)
  - `new_tab = "prefix+c"`, `close_tab = "prefix+shift+x"`, `rename_tab = "prefix+shift+t"`, `next_tab = "prefix+n"`, `previous_tab = "prefix+p"`
  - `switch_tab = ["prefix+1..9", "alt+1..9"]` (both prefix and direct `Alt+1..9`)
  - `move_tab_previous = "alt+shift+left"` and `move_tab_next = "alt+shift+right"` (matches tmux)
  - `workspace_picker = "prefix+w"`, `goto = "prefix+g"`, `new_workspace = "prefix+shift+n"`, `rename_workspace = "prefix+$"`, `close_workspace = "prefix+shift+d"`, `toggle_sidebar = "prefix+b"`
  - `open_notification_target = "prefix+o"` (Herdr default)
  - `Prefix + t` = Floating Scratchpad Terminal popup (`50% x 50%`, `exec "${SHELL:-zsh}"`)
  - `Prefix + C` (`prefix+shift+c`) = unified C++ popup menu; `Prefix + B` (`prefix+shift+b`) = quick build.
  - `Prefix + W` (`prefix+shift+w`) = basic layout picker; `Prefix + A` (`prefix+shift+a`) = basic agent picker/add tab. Launch helpers for these actions remain to be implemented.

### Step 7: Clipboard, Copy Mode & Unified Last-Command Output Capture
- **Built-in Copy / Scrollback:**
  - `copy_on_select = true` (mouse selection auto-copies) and `Ctrl+Shift+v` pastes via `foot` — no extra paste bindings or copy-command hacks needed.
  - `copy_mode = "prefix+["` (vi-style copy mode). Search lives inside it: `/` searches forward, `?` backward, `n`/`N` repeat. tmux's `Prefix+/` shortcut and `Prefix+Ctrl+v` paste are dropped deliberately: search is `Prefix+[` then `?`, and `Ctrl+Shift+v` in foot replaces the tmux paste buffer.
  - `edit_scrollback = "prefix+e"` (follows `$EDITOR`, currently `vim`; no global editor change). This temporary editor is excluded from restart restoration.
  - **Agent output — agreed manual path:** Use `Prefix+e` to open retained pane scrollback in Vim, select the needed portion of agent output, and copy with the existing `\y` Wayland clipboard mapping. This is the chosen path for copying part of an agent's response; agent-aware automatic command-output extraction is outside the initial scope.
  - Agent TUIs redraw their screens, so retained pane scrollback is not guaranteed to contain the full conversation. Verify that the wanted text is available for OpenCode, Claude Code and Codex during implementation; do not promise a transcript export.
- **Unified `Ctrl+Shift+y` & `Ctrl+Alt+c` Output Capture Across `foot` AND `herdr`:**
  - Keep `Control+Shift+y` for raw output and `Control+Alt+c` for formatted command + directory + output in both plain Foot and Herdr. Also retain `prefix+shift+y` and `prefix+alt+c` as secondary Herdr routes.
  - **Agreed correctness requirement:** Copy the complete retained output of the last command from the correct pane. If the output or its boundaries cannot be recovered reliably, report that it is unavailable; do not present a truncated excerpt as complete. Preserve the clipboard on failure.
  - **Agreed initial scope:** Automatic capture applies to the most recent completed shell command while the pane is at the shell prompt. Inside an agent, Vim/Neovim or another running TUI, report unavailable instead of treating the TUI screen as command output. Use the manual `Prefix+e` path for selecting agent text.
  - **Implementation unresolved:** `bash/herdr-copy-output` is a proposed helper, not an implemented or validated design. Plain Foot's OSC 133 stdin capture is a candidate source; formatted command/directory metadata must also identify the same command and shell.
  - The earlier fixed `--lines 500` read plus Starship `│ ` / `❯` matching is insufficient for this requirement. Output can exceed the read limit or resemble a prompt, and the global `~/.local/state/zsh/last_command` can be overwritten by another shell.
  - `herdr pane read` requires an explicit pane ID. A helper launched by Foot does not inherit the environment of its child Herdr pane. Establish window/client/pane routing, capture the intended target without a focus race, and obtain matching command/directory metadata before selecting the implementation.
  - Any scrollback cap still bounds what can be recovered; missing command boundaries or evicted output must produce an explicit unavailable result.

### Step 8A & Step 8B: Menus & Git Workflow
- **Retire `Prefix + S` (Session Menu):** Replace its workflow with Herdr persistence/native workspace keys and the editor/agent/tool restart recovery in Step 2R. Layout/history alone is insufficient; validate the replacement before removing tmux-resurrect.
- **Retire the Quick Menu (`Prefix + e`):** Every entry has a direct Herdr key. `Prefix+e` is now scrollback edit.
- **Retire `Prefix + V` (Virtualenv Menu):** Unused; `direnv` + `zsh/functions/virtualenv.zsh` (`va`, `vc`, `vp`, `vl`, `vs`, `vr`) already work directly in `zsh`.
- **Retire `Prefix + G` (13-item Git + Data Science Menu):** Redundant with `lazygit/config.yml` custom commands (`v` DVC, `N` notebooks, `X` experiment branch, `C` `gci` interactive commit) and `zsh/functions/git-enhancements.zsh`.
- **Keep `Prefix + Shift+g` as Herdr's default `new_worktree`**.
- **Add `lazygit` Floating Popup (`80% x 80%`) on `Prefix + Alt+g`**.

### Step 8C (Partial): Basic Project Layouts and Agent Tabs
- **Scope boundary — explicit user decision:** The agent-related part of this migration supplies basic launching and separate tabs alongside ordinary editor/terminal layouts. The broader agentic layer needs its own design session, taking existing hooks and available dashboards into account. Do not design or modify those systems, introduce coordination/automation, or expand the agent launcher into a framework as part of this migration.
- **Agreed agent placement:** Agents run in separate tabs, not beside the editor in the `code` tab. Keep the editor plus a smaller terminal pane in `code`; C++ projects also retain the `profile` tab. Build/run/debug tabs open as needed under Step 8D. The earlier two-tab C++ direction described the base `code` + `profile` layout, not a limit on agent or task tabs.
- **Agreed agent selection:** When creating an agent tab, show a picker for **OpenCode, Claude Code or Codex** rather than launching a fixed default.
- **Agreed multiple-agent support:** A project can have several agent tabs simultaneously, including different agents working on the same project. Adding an agent must allow another tab without replacing or restarting an existing agent. Keep each tab associated with its project independently of the surrounding workspace, which may contain other projects too.
- **Agreed shortcuts:** `Prefix+Shift+w` (`Prefix+W`) opens a basic layout picker (editor + terminal, or C++ `code` + `profile`). `Prefix+Shift+a` (`Prefix+A`) opens the agent picker and creates another agent tab for the invoking pane's project. These are launch shortcuts; the helper commands remain to be implemented.
- **Recovery connection:** Each supported agent tab should resume its own conversation through the integrations in Step 2R; multiple tabs are not a single shared agent session.
- **Agreed repeated layout invocation:** Selecting a layout through `Prefix+W` for a project whose ordinary editor is already open focuses that existing editor and preserves its current layout. Do not create a duplicate editor or rebuild/rearrange the project's tabs and panes. Identify the editor by project association, not workspace or tab name alone.
- **Remaining basic layout details:** Implement the launch commands and settle initial editor/terminal sizes and focus for newly created layouts without expanding into agent workflow design. `TODO.md` #2's old same-window proposal was not selected; the broader agentic-layer design is deferred to a dedicated user session.

### Step 8D: C++ Menu and Task Tabs
- **Agreed entry point:** One C++ popup menu, available through a Herdr shortcut even when the invoking pane contains an editor, dashboard or another TUI. Actions must run independently of that TUI; do not inject shell commands into it.
- **Agreed shortcuts:**
  - `Prefix+Shift+c` (`Prefix+C`) opens the unified C++ menu, containing the existing configure, build, run, debug and profiling actions.
  - `Prefix+Shift+b` (`Prefix+B`) runs quick build using the same project targeting and build-tab rules.
  - `Prefix+b` remains Herdr's sidebar toggle. The old tmux quick-build binding on lowercase `b` is not carried over.
- **Project targeting:** Resolve the project from the invoking pane's current directory and keep that project/target attached to the selected action even if focus changes. Several projects may share a Herdr workspace; workspace name/directory and tab title alone cannot identify the project reliably.
- **Agreed output location:** Configure, build and test run in a dedicated project build tab, so the task can continue while the user switches elsewhere.
  - Reuse that project's build tab when it is idle, preserving previous output.
  - If it is busy, report that a task is already running and focus the existing tab. Do not interrupt it, queue the request or start an overlapping task.
- **Existing helper is the baseline:** Port the useful behavior in `bash/tmux-cpp-tools` rather than redesigning every action. It already provides CMake configuration, build/test/build+test, executable selection and arguments, source navigation from failures, GDB, Valgrind, clang-tidy, Google Benchmark, hyperfine, perf and samply, plus project creation and clean actions. Preserve the existing guarded clean-all behavior. Port details and final menu organization still need review.
- **Agreed run/debug/profiling destinations:** Preserve the existing workflow: programs run in their own tabs, GDB uses a dedicated debug tab, and profiling uses the project's profile tab. Route each action to the selected project, including when several projects share one workspace. The build-tab reuse/busy rules above do not automatically prescribe reuse or concurrency behavior for these other tabs; preserve existing behavior unless a later decision changes it.
- **Correct cross-project routing:** The current helper's global first-Neovim-pane lookup is unsuitable when several projects are open. Source navigation/current-buffer actions must address the editor belonging to the selected project; profiling destinations likewise need project association rather than a shared tab name alone.
- **Not yet decided or implemented:** The exact launcher/runner mechanism, final helper name, menu implementation and any changes to the existing lifecycle/concurrency behavior for run/debug/profile tabs. Destinations are agreed, but the port still needs to establish that tasks are launched into the correct project without writing into an unrelated running TUI. New shortcut commands below are placeholders until the helper exists.

---

### Step 9 (In Review): System Touchpoints and Cutover
- **Launcher change already in the migration scope:** Replace Niri's `Mod+Return` tmux command with `footclient herdr`, using the default persistent Herdr session. Keep `Mod+T` as plain Foot and `Mod+Grave` as the existing floating scratch terminal; these are distinct from Herdr's internal popup.
- **fzf — temporary-pane direction chosen:** Inside Herdr, use a temporary split pane for the picker instead of requiring a floating popup. Herdr 0.9.5 exposes targeted pane split/close operations; this makes the layout possible but does not itself provide fzf integration.
  - The adapter must pass the calling invocation's candidates/options/environment to fzf and return the selection and cancellation/exit status to that same caller. History selection must update the original shell's command line, file selection must return there, and directory selection must change the original shell's directory, not just the temporary pane's directory.
  - Close the temporary pane after selection/cancellation and return focus to the invoking shell as appropriate. Cover errors and cleanup, concurrent picker invocations, paths with spaces/newlines, preview/key behavior and stream/selection semantics. Do not inject the result into an unrelated pane or leave a shell behind.
  - Exclude the picker pane from restart restoration. The adapter and transient-pane handling are still unimplemented and need proof with shell widgets and scripted fzf callers.
  - **Agreed fallback:** If the temporary picker pane cannot open, fall back to the usual inline picker in the calling terminal. Clean up any partially created pane and preserve the caller's input/result semantics. User cancellation is cancellation, not a reason to reopen inline. Successful fallback does not count as validation of the temporary-pane integration.
  - Preserve plain Foot's current inline `--height 40%` behavior. Remove the tmux-only `--tmux center,80%` path during cutover; it is not a native Herdr backend. Split direction/size remain an implementation starting default to verify visually.
- **Updates:** Keep the existing stable Cargo helper and Herdr `sysup` update step. Retire only the TPM/tmux plugin updater; preserve Zsh, Vim and Neovim update behavior. Keep the existing shpool-backed `keep`/`lg`, update-task persistence and `Mod+A` restore picker outside this tmux migration.
- **Install and drift mappings:** Add file-level links for Herdr config/icon and the authored helper mappings; remove retired tmux config/layout/theme mappings and update the explicit config-drift mappings/plugin scan. Preserve the current Herdr directory's live session data, sockets and logs.
- **Retirement scope:** Retire tracked tmux configuration and migrated helper entry points after validation/review, removing only the matching live links. `~/.config/tmux` contains independent personal files as well as tracked links and plugin clones: do not delete the whole directory or unrelated notes/session state. Uninstall local tmux after successful cutover, inspecting the proposed package transaction first. The installed package currently has no required dependents; fzf lists it as optional. No remote VM changes are included.
- **Validation and docs:** Update README/app architecture/keybinding references and affected tests alongside the implementation. Validate without running installers or upgrades as tests. Follow Niri/Neovim scoped instructions, separate submodule commits from parent pointer updates, and leave implementation for review before merge. Plan work does not authorize immediate live cutover or package removal.

---

## 3. Partial Draft `herdr/config.toml` (Reflecting Decisions So Far)

Review evidence (2026-10-23): the extracted draft passes `herdr config check` on installed Herdr **0.9.5**, including `prefix+$` and the C++ shortcut additions. This validates configuration parsing/keybinding diagnostics, not helper availability, live shortcut delivery or restore/copy behavior. The custom `herdr-copy-output` and `herdr-cpp-tools` commands below remain placeholders; Step 2R's ordinary-program restoration is not implemented by this config.

The agreed `Prefix+W` layout and `Prefix+A` agent-picker bindings still need command entries once their launch helpers are defined. This partial draft is not a finished installable configuration.

```toml
# ~/.config/herdr/config.toml — Arch Linux + Niri + foot + Neovim
onboarding = false

[theme]
name = "one-dark"
auto_switch = true
dark_name = "one-dark"
light_name = "one-light"

[terminal]
default_shell = ""
shell_mode = "non_login"
new_cwd = "follow"
kitty_graphics = false

[update]
channel = "stable"
version_check = false
manifest_check = true

[worktrees]
directory = "~/.local/share/herdr/worktrees"

[session]
resume_agents_on_restore = true
startup_per_agent_delay_ms = 100

[experimental]
pane_history = true

[advanced]
scrollback_limit_bytes = 5000000

[ui]
sidebar_start_collapsed = false
sidebar_collapsed_mode = "hidden"

tab_bar_position = "bottom"
hide_tab_bar_when_single_tab = false
tab_bar_right = [
  { type = "zoom" },
  { type = "datetime", format = " %H:%M" },
  { type = "datetime", format = " %d-%b" },
]
tab_bar_right_separator = "  "

pane_borders = "auto"
pane_outer_borders = false
pane_scrollbars = false
pane_gaps = false

prompt_new_tab_name = false
prompt_new_workspace_name = false
confirm_close = true

window_title = "{workspace}: {terminal_title}"

mouse_capture = true
copy_on_select = true

[ui.toast]
delivery = "system"
delay_seconds = 1

[ui.sound]
enabled = false

[keys]
prefix = "ctrl+a"
detach = "prefix+d"
reload_config = "prefix+shift+r"
resize_mode = "prefix+r"
help = "prefix+?"
settings = "prefix+s"

split_vertical = "prefix+|"
split_horizontal = "prefix+minus"

focus_pane_left = "prefix+h"
focus_pane_down = "prefix+j"
focus_pane_up = "prefix+k"
focus_pane_right = "prefix+l"
swap_pane_left = "prefix+shift+h"
swap_pane_down = "prefix+shift+j"
swap_pane_up = "prefix+shift+k"
swap_pane_right = "prefix+shift+l"
close_pane = "prefix+x"
zoom = "prefix+z"

new_tab = "prefix+c"
close_tab = "prefix+shift+x"
rename_tab = "prefix+shift+t"
next_tab = "prefix+n"
previous_tab = "prefix+p"
switch_tab = ["prefix+1..9", "alt+1..9"]
move_tab_previous = "alt+shift+left"
move_tab_next = "alt+shift+right"

workspace_picker = "prefix+w"
goto = "prefix+g"
new_workspace = "prefix+shift+n"
rename_workspace = "prefix+$"
close_workspace = "prefix+shift+d"
new_worktree = "prefix+shift+g"
toggle_sidebar = "prefix+b"
open_notification_target = "prefix+o"

copy_mode = "prefix+["
edit_scrollback = "prefix+e"

[[keys.command]]
key = "prefix+t"
type = "popup"
command = "exec \"${SHELL:-zsh}\""
description = "open floating terminal"
width = "50%"
height = "50%"

[[keys.command]]
key = "prefix+alt+g"
type = "popup"
command = "lazygit"
description = "run lazygit"
width = "80%"
height = "80%"

# C++ helper commands below are placeholders; implementation remains pending.
[[keys.command]]
key = "prefix+shift+c"
type = "popup"
command = "herdr-cpp-tools menu"
description = "open C++ tools menu"

[[keys.command]]
key = "prefix+shift+b"
type = "shell"
command = "herdr-cpp-tools compile"
description = "build invoking pane's C++ project"

[[keys.command]]
key = "prefix+shift+y"
type = "shell"
command = "herdr-copy-output raw"
description = "copy last command output"

[[keys.command]]
key = "prefix+alt+c"
type = "shell"
command = "herdr-copy-output formatted"
description = "copy formatted command + output"
```

---

## 4. Items Parked for Live Testing / Revisit During Implementation

1. **`pane_gaps = false` vs `true`:** Visually compare shared 1-cell split borders (`false`) vs separated pane borders (`true`) alongside `pane_outer_borders = false`.
2. **`window_title = "{workspace}: {terminal_title}"`:** Verify Sioyek -> Neovim LaTeX inverse search (`VimtexEventViewReverse` in `nvim/lua/plugins/documents.lua`) with another pane/tab/workspace active and multiple Foot windows. Finding a window by title does not itself select a hidden editor pane.
3. **Theme Appearance (`one-dark` / `one-light`):** Visually inspect Herdr's sidebar and bottom tab bar next to `foot` (`#1c1c1c` / `#f5f5f5`) and `nvim` (`#282c34` / `#f5f5f5`), test `Mod+Alt+T` with Herdr open in foot and no signal sent by the script (the sidebar and tab bar should flip on their own; if not, use the clients-only `SIGWINCH` fallback in Step 4), and check whether `panel_bg = "reset"` is wanted on top.
4. **Live shortcut delivery through Foot:** Parser validation passed on 0.9.5, but Herdr's docs warn that `Alt` chords and punctuation depend on what the terminal sends, and a scripted PTY cannot answer that. Press each physically in Foot: `Prefix+$` (`rename_workspace`), `Prefix+|`, `Prefix+Alt+g`, `Prefix+Alt+c`, `Alt+Shift+Left/Right` and direct `Alt+1..9`. `|` and `$` need Shift and are the least certain. A failing key is fixed by choosing a different binding.
5. **Unified `herdr-copy-output`:** Design the source/routing/command-boundary mechanism first. Then test both shortcut routes in plain Foot and Herdr, including output exceeding 500 lines, soft wrapping, prompt-like output, simultaneous shells, directory changes, focus changes, evicted output and failure preserving the clipboard. Verify automatic capture reports unavailable inside running TUIs. Separately verify `Prefix+e` opens useful retained text for each of OpenCode, Claude Code and Codex, and selecting text with `\y` copies the intended portion.
6. **Neovim & Vim Simplification:** Remove `christoomey/vim-tmux-navigator` from `nvim/lua/plugins/editor.lua`, add native `<C-h/j/k/l>` and `<C-\>` split maps in `nvim/lua/config/keymaps.lua`, check `vim/`, and run `nvim --headless -c 'lua dofile("tests/runtime.lua")'` and `:checkhealth`.
7. **Restart recovery:** Test detach/reattach separately from a full server restart and reboot. Verify several projects in one session/workspace, editor files/splits/tabs, all three agent integrations, the agreed ordinary-tool relaunch policy, and exclusion of temporary editors. A returned screen image is not evidence that a program resumed.
8. **Terminal behavior:** Verify clipboard selection/paste, including a multi-line paste into zsh and nvim via `Ctrl+Shift+v`, and where copies land: tmux sent every copy to both the clipboard and the primary selection (so middle-click pastes without auto-running), and Herdr's docs do not say where copy-mode `y` or `copy_on_select` puts text. Copy with `y` and by mouse selection, then paste with `Ctrl+Shift+v` and middle-click. Also verify Shift+Enter in agents and the graphics/previews actually used. `kitty_graphics = false` matches the outer terminal choice; Foot's Sixel support does not establish image support through Herdr.
9. **Live config and cutover:** The current `~/.config/herdr/config.toml` is an independent file and its directory also contains live sockets/logs/session state. Preserve existing state and link only tracked files, not the whole directory. Map config/icon/helpers in `install.sh`, cover them in config-drift, and leave feature/submodule changes for review. After validation and review, switch the launcher, retire tmux mappings and leftover links, then uninstall local tmux. Do not use installation or package removal as validation.

---

## 5. Current Discussion and Remaining Agenda

1. **Step 7 — Capture implementation:** Initial scope is agreed: automatic copying of the most recent completed shell command at the prompt, with complete retained output or an explicit unavailable result; manual `Prefix+e` selection for agent text. Design and prove the routing, metadata and command boundaries before locking in a helper implementation.
2. **Step 2R — Recovery implementation:** Fresh-process relaunch is accepted for ordinary tools in persistent panes/tabs; all temporary popup instances are excluded and deeper application-memory recovery is deferred. Establish a feasible mechanism for editor/agent/tool recovery, including project environments/database paths, session saving for ordinary Vim and editor launch cases not currently covered by Neovim's auto-tracking.
3. **Step 8D — Remaining C++ port details:**
   - The unified popup on `Prefix+C`, quick build on `Prefix+B`, project build-tab rules, and separate run/debug/profile destinations are decided. Continue from existing `bash/tmux-cpp-tools` behavior; implement project-specific targeting and the launcher/runner, checking lifecycle/concurrency before reusing any non-build destination. The draft helper name is provisional.
4. **Step 8C — Rethinking Layouts in Herdr:**
   - Keep this basic: `Prefix+W` layout picker, `Prefix+A` agent picker, separate agent tabs and multiple agents per project. Repeated layout invocation focuses the project's existing editor and preserves its layout. Remaining work is initial layout sizing/focus and launcher implementation. Existing hooks and dashboards, coordination and the rest of the agentic layer are explicitly deferred to a dedicated future design session.
5. **Step 9 — System Touchpoints & Cutover Checklist:**
   - fzf will use a temporary split pane inside Herdr, subject to proving the caller/result bridge and cleanup; plain Foot retains inline fzf. See the Step 9 inventory above for launcher, updater, installation/drift, retirement and validation scope.
   - `niri/config.kdl` (`Mod+Return` -> `footclient herdr`)
   - `zsh/functions/fzf.zsh` (replace the tmux popup option with the temporary-pane adapter once validated)
   - `zsh/functions/sysup/plugins.zsh` (removing TPM plugin updates)
   - `install.sh`, `bash/config-drift`, `README.md`, `docs/architecture/`, and retiring `tmux/`.
