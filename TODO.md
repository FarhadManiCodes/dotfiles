# TODO

Open work and decisions that need the user. Planning clarified 2026-09-11; renumbered again on
2026-09-16 when the test runner was delivered and closed. Accepted findings remain in
`revisit.md`; the runner's dropped follow-on scope is recorded there.

Suggested order: agree the editor + agent layout first. Browser work needs specific use cases.
Off-machine backup remains deferred.

| Item | Status | Next requirement |
|---|---|---|
| 1. Off-machine backup | **Deferred by the user** | Explicitly reopen, then choose destination and scope |
| 2. Editor + agent layout | Important to the user; design needed | Agree layout and invocation behavior |
| 3a. Sensitive-site Tridactyl rules | Needs user input | Domains and desired disable behavior |
| 3b. Tridactyl workflow review | **Closed 2026-09-16, no action** | — |
| 3c. Firefox containers | **Closed 2026-09-16, no action** | — |

## 1. Off-machine backup

**Deferred by the user 2026-09-07.** Revisit later; no implementation now.

**Problem:** snapshots share the data's filesystem. They protect against mistakes, but cannot
recover a lost or failed disk. See `docs/architecture.md`, "btrfs subvolume layout".

**Deliverable when reopened:** recover irreplaceable data after losing the laptop, using
credentials available independently of it, with a demonstrated restore.

**Decisions needed:** destination and capacity/cost; data to include, including outside home;
acceptable data-loss window and retention; where to keep recovery credentials.

**Implementation sequence after those decisions:**

1. Inventory intended data, filesystem boundaries and regenerable exclusions. Define a
   consistent database-backup method if database data is included; backing up home alone does
   not cover separate Postgres storage.
2. Back up a small sample with restic, restore into a separate directory, and compare contents.
   Exercise recovery using independently stored credentials before broadening coverage.
3. Add scheduling, retention, maintenance and failure reporting after restore works. Test
   absent destinations, failed uploads and stale last-success reporting.

**Done when:** a recovery exercise succeeds, intended data is covered, and partial or failed
backups cannot appear as complete success. Document recovery as well as routine operation.

**Feasibility:** technically straightforward; destination, data scope and recovery arrangements
are the unresolved dependencies. The user must explicitly reopen this deferred task.

**Design constraints:** `~/projects/omarchy/plans/backup.md` is a revision-2 reference, not the
required feature scope. The parts that transfer:

- **restic**, and specifically **not `rclone sync`** — which mirrors deletions and ransomware
  to the destination, and whose versioning is provider-side or a `--backup-dir` hack. rclone
  stays the right transport for `~/Cloud` and the wrong basis for a backup.
- **`--one-file-system` is load-bearing on this machine.** `~/Cloud/gdrive` and
  `~/Cloud/Dropbox` are FUSE mounts under `$HOME`; without it a backup walks into them and
  pulls the whole Drive down through FUSE. What one stray `du` on an rclone mount already cost
  is recorded in the sleep-hook section of `docs/architecture.md`. Verify intended coverage:
  needed data across filesystem boundaries requires an explicit plan.
- **State the threat model before the feature**, the way the rclone `combine` note already
  does: this defends against disk death, theft and deletion found late. It does **not** defend
  against malware running as this user, because the machine holds credentials that can delete
  from the repository.
- A local destination must **verify the target filesystem's UUID before writing**, or an absent
  USB disk silently gets a backup written into an empty mountpoint on the root filesystem.
- Notification policy worth stealing regardless: a single failed run is silent, no success in
  24 h warns once and then weekly. A one-shot warning lets a dead credential rot for months.
- Two systemd details that cost a debug session each: `Persistent=true` only works on calendar
  timers, and **pause must not be a unit condition** — a `ConditionPathExists`-gated unit never
  runs while paused, so it can never notice the pause expiring.

Interacts with the NVMe health check now in `sysclean` (`docs/architecture.md`) — a
disk-health warning is only actionable if there is somewhere to restore from, which is why its
warning path points here.

## 2. An editor + agent tmux layout

From `docs/omarchy-comparison.md` §27, not from its A–E proposals. **The user rates this
important.** We have exactly one layout, `tmux/layouts/cpp_layout.sh` on `Prefix W`; an
editor+agent layout is the obvious second, and it is a design job rather than a config edit —
which panes, what starts in them, and how it is invoked all need deciding before anything is
written.

**Proposed first version, not yet selected:** one new window containing an editor, one agent
and a small terminal pane. A separate binding beside `Prefix W`, the invoking pane's directory,
editor focus, and a fresh window on each invocation would preserve existing work.

**Decisions needed:** agent command and whether it is fixed or an argument; pane arrangement
and sizes; invocation key; directory source; initial focus; repeated-invocation behavior.
Additional agents, a diff pane, per-directory windows and swarms are separate optional scope.

**Implementation sequence:**

1. Agree the first version and its behavior above.
2. Add the layout script and chosen binding. Inspect live links and installation mapping first.
3. Validate on an isolated tmux server with harmless placeholder commands, then visually check
   the agreed layout. Cover paths containing spaces, small terminal dimensions, missing
   commands, repeated invocation and focus changing while the script runs.

**Done when:** one invocation opens the agreed usable layout in the intended directory,
focuses the editor, and does not disrupt unrelated windows or execute unintended commands.

**Feasibility:** high once the workflow is chosen.

### Reference shapes and implementation notes

Their four functions are reproduced here **so this does not depend on the checkout**
(`~/projects/omarchy/default/bash/fns/tmux`, read at `36e56f4f`). Theirs is bash and ours would
follow `cpp_layout.sh` — a script in `tmux/layouts/` run by `bind-key … run-shell` — so nothing
ports literally; the value is the shapes and the techniques.

| Function | Shape |
|---|---|
| `tdl <ai> [ai2]` | Current window renamed to the directory. Editor pane top-left, terminal strip along the bottom (15%), AI on the right (30%). A second AI splits the AI pane. |
| `tds` | A 2×2 square: editor, `hunk diff --watch`, terminal, `opencode`. We have no `hunk`, so the diff pane needs a local answer. |
| `tdlm <ai> [ai2]` | One `tdl` window per subdirectory of `$PWD`; renames the session after the parent. |
| `tsl <n> <cmd>` | N tiled panes all running the same command — a "swarm" for agents. |

Techniques worth taking, which is the real content:

- **`$TMUX_PANE` rather than "the active pane".** A stable handle that survives the active
  window changing under you mid-script.
- **`split-window … -P -F '#{pane_id}'` returns the new pane's id** (`%3`), so every later
  `send-keys` addresses a pane explicitly instead of assuming where focus landed.
  `cpp_layout.sh` currently relies on focus following the split, which works but does not
  compose past two panes.
- **`send-keys -t <pane> -l "text"` then a separate `C-m`.** `-l` sends the string literally,
  so a command containing something like `C-m` or `Enter` is not reinterpreted as a key. They
  do this in `tds` but not in `tdl` — copy the `tds` form.
- **`-c "$current_dir"` on every split**, or panes open wherever tmux felt like.
- **`tr '.:' '--'` on a session name** — tmux disallows dots and colons.
- `select-layout tiled` after each split is what keeps `tsl` even.

Two corrections to make when writing ours, both verified 2026-09-08:

- **`tdl` has a live bug.** Its last line is `tmux select-pane -t "$opencode_pane"`, and
  `opencode_pane` is never set in that function — it is declared in `tds`. tmux gets an empty
  target, so the "select the nvim pane" the comment promises does not happen. Should be
  `$editor_pane`.
- **`-p 15` is the old spelling.** Both `-p 15` and `-l 15%` are accepted by tmux 3.7c here
  (tested on a throwaway server), but `-l %` is the current form and `cpp_layout.sh` already
  uses the percentage style via `resize-pane -y 30%`.

## 3. Firefox items

Moved from `firefox/firefox-notes.md` on 2026-09-09. These are independent tasks; browser
preferences remain documented there and tracked Tridactyl settings in `tridactyl/tridactylrc`.
3b and 3c closed 2026-09-16; only 3a remains open.

### 3a. Sensitive-site Tridactyl rules

**Problem:** banking and password-manager sites were intended to have site-specific disable
rules, but their domains and desired behavior have not been supplied.

**Decisions needed:** exact domains, including relevant login redirects, and whether the goal
is avoiding shortcut interference or more thoroughly disabling Tridactyl's page behavior.

**Next steps:** choose narrowly scoped URL rules, apply the selected mode, reload, and check
forms, redirects and password-manager interaction. Confirm ordinary sites remain unaffected.

**Done when:** the agreed behavior holds across each intended site's login flow.

**Feasibility:** small once the domains and behavior are chosen. The mechanism already exists:
`blacklistadd` entries cover `drive.google.com` and `docs.google.com`.

**Important distinction:** Tridactyl 1.25.0 help, inspected 2026-09-09, describes `blacklistadd`
as a DocStart autocmd entering ignore mode. The content script still runs, and `<C-o>`,
`<S-Insert>`, `<S-Escape>`, `<AC-Escape>` and ``<AC-`>`` remain bound. For a more thorough
disable, upstream documents `seturl <url-regex> superignore true`. These are different behaviors;
see [Tridactyl's documentation](https://github.com/tridactyl/tridactyl).

### 3b. Tridactyl workflow review — closed 2026-09-16

**Problem:** "deep-config session" has no defined outcome. Existing settings already cover
search engines, hints, tabs, editor integration and reading/media shortcuts.

**Resolution:** asked the user for three recurring annoyances or missing actions; there are
none. The item traced back to `docs/omarchy-comparison.md` rather than an observed problem in
this config. Current Tridactyl config retained as-is. Reopen only if a concrete friction point
shows up in normal use.

### 3c. Firefox containers — closed 2026-09-16

**Use case (2026-09-16):** separate personal from work sessions. Manual container selection —
no automatic per-site assignment, so the Multi-Account Containers extension is not needed.

**Evidence re-verified 2026-09-16** (profile `g9208rug.default-release`, the `Default=` profile
in `profiles.ini`, Firefox not running while inspected): Multi-Account Containers is still not
installed. `containers.json` already defines the four native identities — Personal (`id 1`),
Work (`id 2`), Banking (`id 3`), Shopping (`id 4`) — via `contextualIdentities`, Firefox's
built-in feature, not the extension. `privacy.userContext.enabled` is unset (defaults off), so
the "Open New Container Tab" option is currently hidden from the `+`/right-click menu.
`privacy.userContext.extension` is `tridactyl.vim@cmcaine.co.uk`. Installed extensions: uBlock
Origin, Proton VPN, DownThemAll!, Tridactyl (all active), Catppuccin Latte · Mauve theme
(inactive).

**Decision:** flip `privacy.userContext.enabled` to `true` (added to `firefox/firefox-notes.md`
about:config table). No extension install, so no Tridactyl link-interception question — manual
selection doesn't touch link-opening behavior.

**Verified 2026-09-16 (user, interactive):** enabled the pref, confirmed Personal/Work cookie
separation, confirmed both container tabs survive a full restart, confirmed Tridactyl hinting,
tab open/close/switch behave normally with containers in use. No extension needed.
