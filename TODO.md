# TODO

Open work and decisions that need the user. Planning clarified 2026-09-11; this rewrite
does not approve or start implementation. Accepted findings remain in `revisit.md`.

Suggested order: agree the editor + agent layout first, then build the test runner in small
increments. Browser work needs specific use cases; identity verification can wait for a real
occasion. Off-machine backup remains deferred.

| Item | Status | Next requirement |
|---|---|---|
| 1. Tmux identity | Awaiting a real-use check | SSH-started server or another-user session |
| 2. Test runner | Scoped; needs an implementation session | One entry point for existing checks |
| 3. Off-machine backup | **Deferred by the user** | Explicitly reopen, then choose destination and scope |
| 4. Editor + agent layout | Important to the user; design needed | Agree layout and invocation behavior |
| 5a. Sensitive-site Tridactyl rules | Needs user input | Domains and desired disable behavior |
| 5b. Tridactyl workflow review | Needs concrete problems | Name recurring browsing friction |
| 5c. Firefox containers | Needs a use case and browser trial | Choose accounts or sessions to separate |

## 1. Verify the tmux identity segment

**Problem:** exceptional cases need real-use visual confirmation. No defect is established.

`bash/tmux-identity` hides `user@host` when local as the usual user, which is confirmed live.
The other two branches were only tested by faking the environment on throwaway sockets: over
**ssh** it should show the bare hostname, and as **another user** the bare username.

**Next steps:** when either happens naturally, record the server's startup context, inspect
`@tmux_power_left_a`, and compare the rendered status bar with the expected text below.
Do not create an account or configure SSH solely to close this item.

| Context at config load | Expected identity text, alongside the user icon |
|---|---|
| Local, usual user | No identity segment — already confirmed live |
| SSH, usual user | Hostname |
| Local, another user | Username |
| SSH, another user | `user@host` |

Note `SSH_CONNECTION` is read from the
environment that started the *server*, so attaching over ssh to a locally-started tmux will
correctly show nothing — that is not a failure.

**Done when:** the exceptional cases have recorded real-use observations matching the expected
rendering. Automated branch tests in item 2 complement this check.

**Feasibility:** small and opportunistic; waiting for the occasion, not implementation work.

## 2. A test runner

**Problem:** `tests/test_config_drift.py` and `bash/check-skills` have separate entry points,
and a few documented decisions and script branches have no regression coverage.

**Deliverable:** one command that reports each suite's result and exits nonzero if any required
suite fails. Keep standard-library `unittest`; copying Omarchy's Bash harness was withdrawn
because it would duplicate infrastructure.

**Implementation sequence:**

1. Add the entry point for the existing unittest suite and `check-skills`. Resolve the checkout
   from the runner's own location and pass it explicitly to checks that need it. `check-skills`
   currently uses `DOTFILES` or `$HOME/dotfiles` and exits successfully if `skills/` is absent:
   missing required input must not look like a passing suite.
2. Add the three remaining conventions from `docs/omarchy-comparison.md`, "The invariant
   table (8)": `install.sh` never executes sudo; active user-unit ordering directives do not
   reference `network-online.target`; relevant `bash/tmux-theme` background slots use explicit
   hex rather than `default` or palette indices. Scope checks to active code/settings — comments
   and printed instructions already contain some of these words. Link mappings have coverage.
3. Test the real `bash/tmux-identity` using a fake `tmux` that records arguments. Cover item 1's
   four combinations, the usual-user override, and the username fallback when `USER` is unset.
4. Test the real `bash/lock-once` for absent, live, vanished and zombie processes, multiple
   candidate PIDs, and failure of the locking command. It reads `/proc/<pid>/stat`, so a fake
   `pgrep` alone is insufficient: design controlled process-state responses too. Replace
   `swaylock` with a fake before exercising any branch.

**Testing rules:** run real scripts against temporary fixtures and fakes that record calls.
Keep environment overrides inside test subprocesses. Never invoke the live locker or mutate
a live tmux server. A unittest assertion already stops its test method; do not add whole-file
abort semantics. Independent tests and subsequent suites must continue after a failure.

**Done when:** the runner works from outside the checkout, deliberate fixture failures are
detected, later suites still run, and the final status reflects failures or missing required
inputs. Tests leave live configuration and services untouched.

**Feasibility:** high; deliver each numbered increment separately. No new framework or CI is
required. Add coverage for concrete failures rather than every sentence in the architecture docs.

**Retained context:** `check-skills` already checks frontmatter, names, descriptions, body
length and referenced resources; its source is the current assertion inventory. It was verified
against a deliberately broken fixture on 2026-09-06, after repeated inline reviews had missed
a real description defect.

Deliberately **not** asserted: the journal query in
`skills/diagnose-boot-or-suspend/references/incident-2026-09-02.md`. Journal retention drops
that window around 2026-10-21, and a test that fails when the journal rotates is the tmux-power
mistake in a new costume.

## 3. Off-machine backup

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

## 4. An editor + agent tmux layout

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

## 5. Three open Firefox items

Moved from `firefox/firefox-notes.md` on 2026-09-09. These are independent tasks; browser
preferences remain documented there and tracked Tridactyl settings in `tridactyl/tridactylrc`.

### 5a. Sensitive-site Tridactyl rules

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

### 5b. Tridactyl workflow review

**Problem:** "deep-config session" has no defined outcome. Existing settings already cover
search engines, hints, tabs, editor integration and reading/media shortcuts.

**User input needed:** name three recurring annoyances or missing actions in normal browsing.

**Next steps:** map each problem to the current config, propose a specific change, and try it
on representative sites. Review search engines or bindings where they relate to those problems.

**Done when:** the named problems are resolved, or the current behavior is deliberately retained
with a reason. Avoid an unbounded review of every available setting.

**Feasibility:** depends on the problems selected; small binding changes are straightforward,
but usefulness needs interactive confirmation.

### 5c. Firefox Multi-Account Containers

**Problem:** account/session separation is being considered, but no concrete use case has been
chosen. Containers separate cookies and site storage; they are not a general extension-security
boundary. See [Mozilla's documentation](https://support.mozilla.org/en-US/kb/containers).

**Decision needed:** which accounts or sessions to separate, and whether automatic per-site
assignment is needed rather than manual container selection.

**Next steps:**

1. Compare the installed Firefox's native capabilities with the extension's additions for that
   use case. Recheck installed state before acting; the observations below are dated.
2. Trial one use case and verify Tridactyl compatibility, including opening links and redirects.
   The recorded preference is a compatibility question, not proof of a conflict.
3. Check session persistence after restart and document the chosen identities and assignment
   policy without committing browser session data or credentials.

**Done when:** intended accounts remain separate, links open in the intended container,
sessions survive restart, and Tridactyl behaves as expected. A trial can also conclude that
containers offer no needed benefit and close the item with that reason.

**Feasibility:** reasonable; requires an interactive browser trial.

**Evidence recorded 2026-09-09:** Multi-Account Containers was not installed. `containers.json`
held Personal / Work / Banking / Shopping, while `privacy.userContext.enabled` was unset.
`privacy.userContext.extension` was `tridactyl.vim@cmcaine.co.uk`; coexistence was unverified.
The profile had uBlock Origin 1.74.0, Proton VPN 1.3.6 and DownThemAll! 4.15.1, plus the
Catppuccin Latte · Mauve theme. Tridactyl was installed globally by `firefox-tridactyl`, explaining
its absence from the profile's add-on list; the theme explained the previously unidentified GUID.
