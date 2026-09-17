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
| 4. ath11k regulatory-domain error | Needs user input | Check router for 5GHz/6GHz, then re-test |

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

## 4. ath11k regulatory-domain error

**Problem:** every boot logs, twice, from the wifi driver:

```
ath11k_pci 0000:02:00.0: Failed to set the requested Country regulatory setting
ath11k_pci 0000:02:00.0: failed to process regulatory info -22
```

Not previously in `revisit.md`; surfaced 2026-09-17 during a package-maintenance sweep that
also checked journal warnings.

**Evidence so far:**

- Persistent across every boot checked (back to 2026-09-14) — not a fluke.
- Fires immediately after the firmware handshake, 2.4s before the interface associates:
  `chip_id 0x12 chip_family 0xb board_id 0xff soc_id 0x400c1211`, then
  `fw_version ... WLAN.HSP.1.1-03125-QCAHSPSWPL_V1_V2_SILICONZ_LITE-3.6510.41`. `board_id 0xff`
  is the chip's own factory-reported ID (read before any driver/firmware-file selection), not
  something a different `board-2.bin` would change — it means no board-specific
  calibration/country table is programmed into this particular card.
- Despite the error, wifi works normally: associates within 2.4s, `iw reg get` correctly shows
  `country DE` with full ETSI channel/power tables, and TX power is correctly limited to what
  the AP advertises. No `regulatory domain changed` kernel line appears anywhere in the boot log
  for comparison, though.
- **Working hypothesis, not confirmed:** the driver is pushing a country code to the *firmware*
  over QMI (device-side enforcement) and getting rejected because board_id 0xff has no
  calibration slot for it — separate from the *kernel's* own regulatory enforcement
  (`cfg80211`/`wireless-regdb`), which is what `iw reg get` reflects and is demonstrably working.
  Not verified against the `ath11k` QMI source, so this is plausible, not proven.
- **Side finding, unconfirmed:** the Bluetooth controller (same laptop) reports manufacturer
  `0x001D` via `bluetoothctl show` — Bluetooth SIG company ID for **Qualcomm**, not MediaTek.
  That would make wifi and Bluetooth the same Qualcomm WCN6855 combo chip, both carrying this
  board_id-0xff quirk. This conflicts with the existing `revisit.md` bluez entry, which says
  "Controller is MediaTek MT7922". Worth a separate correction if confirmed — not actioned yet.
- **Untested:** 5GHz and 6GHz association. Only a 2.4GHz connection (`Vodafone-6139`, channel 1)
  has been observed. `iwctl station wlan0 get-bsses "Vodafone-6139"` shows exactly one BSS —
  no 5GHz BSS currently broadcasting under that SSID, so the router's 5GHz may be off, or
  under a different SSID not appearing in the scan (18 networks scanned, none obviously a
  `-5G` variant of this one).

**Decisions needed:** user to check the router admin page (2026-09-18 or later) for whether
5GHz/6GHz is enabled and under what SSID.

**Next steps once 5GHz is available:** connect, then compare
`journalctl -b -k | grep -i ath11k`, `iw reg get`, and `iw dev wlan0 info | grep -i txpower`
against the current 2.4GHz-only baseline. Ideally test a DFS channel (5250–5350 or
5470–5725 MHz) specifically, since that is where regulatory enforcement actually does
something (AP-side Channel Availability Check, client-side radar channel-switch behavior) —
a clean non-DFS 5GHz association would confirm less than a DFS one.

**Done when:** 5/6GHz (and ideally DFS) is tested and the outcome — clean, or a new failure
mode — is logged. Route to `revisit.md` as ACCEPTED if it stays cosmetic, or investigate
further (e.g. check whether a newer `linux-firmware-atheros` board file changes board_id
0xff) if not. If the router turns out to have no 5GHz/6GHz at all, this stays open as
unverifiable rather than resolved.

**Feasibility:** small — the test itself is a few commands, blocked only on router access.
