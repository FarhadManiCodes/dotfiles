# TODO

Open work and decisions that need the user. Planning clarified 2026-09-11; renumbered again on
2026-09-16 when the test runner was delivered and closed. Item 4, the ath11k regulatory-domain
error, was closed to `revisit.md` on 2026-09-18 once 5GHz was tested and the error confirmed
cosmetic. Item 5, removing `mate-polkit`, was run by the user and closed to `revisit.md` the
same day. Item 4, Alt+p resolving citations from refinery, was built and verified 2026-10-02 and
closed to `revisit.md`; item 6, review copies for four imported books, was delivered 2026-10-02
by refinery's `--from review` stage (see `skills/papers-and-pdfs/references/convert.md`); item 9,
screenshot annotation, was delivered 2026-10-04 with Flameshot on Shift+Print. The remaining
numbers are kept. Accepted findings remain in
`revisit.md`; the runner's dropped follow-on scope is recorded there.

Suggested order: agree the editor + agent layout first. Off-machine backup remains deferred.

| Item | Status | Next requirement |
|---|---|---|
| 1. Off-machine backup | **Deferred by the user** | Explicitly reopen, then choose destination and scope |
| 2. Editor + agent layout | Important to the user; design needed | Agree layout and invocation behavior |
| 3a. Sensitive-site Tridactyl rules | **Closed 2026-10-02, verified** | — |
| 3b. Tridactyl workflow review | **Closed 2026-09-16, no action** | — |
| 3c. Firefox containers | **Closed 2026-09-16, no action** | — |
| 5. Move useful study-library books into papis | Open 2026-09-27 | User picks the books |
| 7. Router drops wifi every ~8 h | Found 2026-09-29 | Check the router's schedule |
| 8. Battery alarm wakes the laptop at 5% | Found 2026-09-29 | Decide whether to keep the wake |
| 10. Evaluate pv, entr and strace | Open 2026-10-02 | Audit usefulness, overlap and dependency cost |
| 11. Install qalc and VisiData for the study books | qalc installed 2026-10-04 | Install VisiData with `uv tool`, then try both |
| 12. Python venv for the study-book experiments | Open 2026-10-03 | Pick which venv, then install |
| 13. Rewrite sysup's yts step for the C++ rewrite | Done on branch `yts-cpp` 2026-10-06, awaiting review | Review, run `sysup` once, then close |
| 14. Image viewer and Qt icon theme | Open 2026-10-05; user will work on it | Pick a viewer, then set the Qt icon theme |
| 15. Fingerprint recovery after resume | Installed; hardware verification pending | Several normal cycles, including an active scan; check fingerprint and password unlock |

## 1. Off-machine backup

**Deferred by the user 2026-09-07.** Revisit later; no implementation now.

**Problem:** snapshots share the data's filesystem. They protect against mistakes, but cannot
recover a lost or failed disk. See `docs/architecture/btrfs.md`.

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
  is recorded in `docs/architecture/niri.md`, "Sleep hooks". Verify intended coverage: needed
  data across filesystem boundaries requires an explicit plan.
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

Interacts with the NVMe health check now in `sysclean` (`docs/architecture/sysclean.md`) — a
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
3b and 3c closed 2026-09-16 and 3a on 2026-10-02; nothing under this heading remains open.

### 3a. Sensitive-site Tridactyl rules — closed 2026-10-02

**Decided 2026-09-18, verified by the user 2026-10-02.** `blacklistadd` (avoid shortcut
interference; the content script still runs and a few keys stay bound) for the user's
Sparkasse branch (wildcarded in `tridactylrc` as `https://www.sparkasse-*.de/*` rather than
named literally, since this repo is public), `https://app.n26.com/*` and
`https://passwords.google.com/*`. Live via the existing symlink. The user reloaded Tridactyl
and confirmed each login flow works.

**Mechanism note kept for a later change:** Tridactyl 1.25.0 describes `blacklistadd` as a
DocStart autocmd entering ignore mode, so `<C-o>`, `<S-Insert>`, `<S-Escape>`, `<AC-Escape>`
and ``<AC-`>`` remain bound. A more thorough disable is `seturl <url-regex> superignore
true` (see [Tridactyl's documentation](https://github.com/tridactyl/tridactyl)); switch only
if a site misbehaves.

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

## 5. Move the useful study-library books into papis, then drop the copy

**Opened 2026-09-27** when `book-resources` (Mod+z) was deleted. Mod+z is now
`papis-fuzzel --books`: the papis picker filtered to entries tagged `book`, so a book
shows there only if its papis entry has the `book` tag (all 14 current books do).

**What is left:** `~/.local/share/study-library`, a static copy of Drive's `FAU/Library`
(21 files, newest 2026-05-16, no sync). The user picks which books are worth keeping;
Gottschling (Discovering Modern C++) and Meyers (Effective Modern C++) are already in
papis. Add the rest with a `book` tag plus the folder's topic as a tag (`control`, `cpp`,
`hpc`, `linear-algebra`, `math`, `multiscale`, `numerical-methods`, `PDE`).

Nothing reads the copy any more: `fbook`/`rgbook` (`zsh/functions/pdf.zsh`, mirrored in
`bash/vifm-pick`) search the papis library since 2026-09-27.

**Done when:** the kept books open from Mod+z and `~/.local/share/study-library` is deleted.

## 7. The router drops wifi every ~8 hours

Found while fixing `net-notify` (2026-09-29). Since at least 2026-09-18 the 5 GHz access
point (BSS `dc:a6:33:87:41:fb`, SSID Vodafone-6139) deauthenticates the laptop at about
05:10, 13:15 and 21:15, drifting a couple of minutes later each day. Reason 3,
`DEAUTH_LEAVING`, means the access point itself is going away, not a client problem. The
first reconnect attempt times out, and wifi is back after 20-90 s, usually ~44 s. That is
most of the 27 drops logged while the machine was awake that month.

Check the router for a scheduled restart, a WiFi on/off timer, or automatic 5 GHz channel
changes. It is the router's behaviour, so there is nothing to change on this machine.
`net-notify` reports these drops as they happen. To see the pattern:

```bash
journalctl -u iwd --since -7d | grep 'from_ap: true'   # the router's drops; resume drops say false
```

## 8. The battery alarm wakes the laptop from sleep at 5%

Found while redoing `power-notify` (2026-09-29). The firmware's battery alarm (`BAT0/alarm`,
3791000 µWh = 5%) makes the kernel wake a suspended laptop when the charge crosses it:
measured with an alarm set just below the charge, which woke the laptop from s2idle about
4 min later, without a lid event (EC interrupt, IRQ 9). This is the firmware and kernel
default, with or without `power-notify`. There is no hibernation here (swap is zram only),
so the wake has nothing to save: in a bag it only shows the danger notice to nobody, and
lid-closed re-suspend after this kind of wake was not tested.

The knob is the battery device's wakeup setting,
`/sys/devices/pci0000:00/0000:00:14.3/PNP0C09:00/PNP0C0A:00/power/wakeup` (now `enabled`),
set to `disabled` by a root udev rule. Untested whether that stops this wake. Decide whether
to keep the wake; the alarm itself should stay, since `power-notify` reads it for 5%.

## 10. Evaluate pv, entr and strace

**Requested 2026-10-02.** Look at `pv` for progress and throughput reporting in data
pipelines, `entr` for rerunning commands when selected files change, and `strace` for
diagnosing system calls, failed file access and subprocess behavior.

**Audit scope:** identify concrete uses in the current workflow, compare with existing tools
and scripts (including `inotify-tools`), and check package size plus any additional
dependencies. Try representative examples before deciding which tools are worth installing.

**State 2026-10-04:** `pv` is installed for the trial; `entr` and `strace` are not.
`inotify-tools` is already installed, so it is the baseline for the `entr` comparison.

**Done when:** record an evidence-backed keep-or-skip decision for each tool and the reason.

## 11. Install qalc and VisiData for the study books

**Requested 2026-10-03.** Two small tools for reading DDIA and *Fundamentals of Data
Engineering* (`~/projects/DDIA_study`, `~/projects/DataEngineering_study`):

- `libqalculate` (16 MB, ships the `qalc` command) for unit-aware sizing arithmetic such
  as `1 TB / (200 MB/s) to hours`. `numbat` is the smaller alternative; `qalc` was preferred
  for its larger unit database. **Installed 2026-10-04**, with `qalculate-qt` (4 MB on top of
  Qt libraries already present) as the GUI.
- `visidata` for browsing CSV, JSON, SQLite and Postgres, installed as a uv tool rather than
  from pacman, like `jupytext`: `uv tool install visidata --with pyarrow`. Parquet needs
  `pyarrow` in the environment `vd` runs from, so it goes into the tool's own environment
  and `vd` reads Parquet from any directory. `sysup` upgrades uv tools.

Skipped on purpose: Miller (overlaps DuckDB, no Parquet), Graphviz (the books carry their
own figures; revisit if redrawing topologies), `qalculate-gtk`.

**Done when:** `uv tool install visidata --with pyarrow` has been run and `qalc` and `vd`
both open, `vd` on a Parquet file.

## 12. Python venv for the study-book experiments

**Requested 2026-10-03.** Libraries for small experiments while reading DDIA and
*Fundamentals of Data Engineering*, not system tools:

- `pyarrow`, `fastavro`, `protobuf`: write one record as Parquet, Avro and Protobuf and
  compare the bytes with `xxd` (DDIA ch. 5). VisiData has its own `pyarrow` (item 11), so
  this venv is only for the experiments.
- `numpy`, optionally `matplotlib`: simulate tail latency and why averaging percentiles is
  wrong (DDIA ch. 2).
- Later, optionally `dbt-duckdb`: local transformation practice against DuckDB.

**Decide:** which of the three environment locations to use; read `skills/python-venv`
first and do not create a new environment as a side effect. Nothing is installed yet.

**Done when:** the packages import from the chosen venv and one encoding comparison runs.

## 13. Rewrite sysup's yts step for the C++ rewrite

**Found 2026-10-05**, while moving off GTK4. `yts` is being rewritten from Python/GTK4 to
C++ with Qt 6 (one `yts-core` library, the fuzzel menu and a Qt Widgets window), done in
`~/projects/yts` by the user. `_sysup_yts` in `zsh/functions/sysup.zsh` and the "yts, the one
locally-built app" section of `docs/architecture/zsh.md` describe the Python install and
will be wrong after it:

- `make test` and `make install`, which run pytest and `uv pip install .` into a venv under
  `~/.local/share/yts-gui/`, become a CMake configure, build, `ctest` and install into
  `~/.local`. Build with `-j8`, the physical core count.
- The proof that the result works is an import of the Python package; it becomes running the
  installed binary, for example its `--version`.
- `.installed-commit` and the refusal of a dirty worktree, untracked files included, still
  apply and are worth keeping. The `uv venv --clear` caveat goes away with the venv.
- The step is non-fatal by design: a stale launcher is an older working app.

**Today:** the installed `yts-gui` has not started since `python-gobject` was removed as an
orphan on 2026-10-01. The step does not notice because it only runs when the repo's HEAD
differs from the installed commit; if that happens before the rewrite lands, it will run
the Python `make install`, fail its import check and warn without stopping `sysup`.

**Done when:** the step builds and installs the C++ version, a failed build leaves the
previous binary in place, and `docs/architecture/zsh.md` describes the new flow.

**2026-10-06, on branch `yts-cpp`:** the C++ `make install` exists (yts `cpp-port`). The
step now builds with `CMAKE_BUILD_PARALLEL_LEVEL=8`, proves the result by running
`~/.local/bin/yts --version`, and takes the binary directory as a third argument for the
tests; `tests/test_sysup_yts.py` covers it (10 cases, 4 of them fail against the old step).
yts's `make install` builds before copying, so a failed build keeps the previous binary.
`bash/yts-play` (Tridactyl's ,y) now wraps `yts --play`. Close after review and one real
`sysup` run.

## 14. Image viewer and Qt icon theme

**Raised 2026-10-05**, while moving off GTK4. The two are linked: any Qt viewer shows its
menu and toolbar icons from the system icon theme, and Qt applications here have none yet.

**Image viewer.** `gthumb` (GTK3) opens ten image types in `mimeapps.list` and stays until
a replacement is chosen. GTK3 stays installed regardless (Firefox, `xdg-desktop-portal-gtk`;
see the GTK3 entry in `revisit.md`), so replacing it is for consistency, not to free GTK.

- `imv`: tried and does not do what the user wants. `exec` bindings and auto-reload would
  allow saved rotation with `jpegtran` or `magick`, but crop has no way to learn the
  image's position in the window.
- `gwenview`: crop and rotate, official, but a long list of KDE Frameworks dependencies.
- `qimgv-git` (AUR): the one Qt viewer documented with crop, rotate and resize and saving.
  Upstream is slow (last release 2021, commits through January 2026) and it builds from git.
- `qView` (AUR only): Qt 6, minimal, maintained (7.1, commits through April 2026). Rotate,
  mirror, flip, rename, trash, slideshow and sorting; **no crop**. Needs `qt6-imageformats`
  (72 KB) for WebP and TIFF and `kimageformats` (0.66 MB, depends only on `qt6-base`) for
  AVIF, HEIC and JXL. A local crop patch was floated: a rubber-band selection in
  `qvgraphicsview.cpp` using `mapToScene`, built from a local PKGBUILD or `~/Installs/qview`
  like sioyek. The build needs `qt6-tools` (6.9 MB download).
- `swayimg` (`extra`, no toolkit): rotate and flip of the view only, no crop or save
  documented.

**Qt icon theme.** `QT_QPA_PLATFORMTHEME` is unset in `environment.d/wayland.conf`, so Qt
falls back to `hicolor` and every icon looked up by name is missing. Tested 2026-10-05 with a
small Qt 6 program under Wayland: `QT_QPA_PLATFORMTHEME=gtk3` gives Adwaita (the current
GTK setting) with all five icons found; `xdgdesktopportal` gives `hicolor` again. Papirus is
installed and has those icons; getting it means
`gsettings set org.gnome.desktop.interface icon-theme Papirus` as well, which also changes
Firefox's and gthumb's icons. `pcmanfm-qt` already sets `FallbackIconThemeName=Papirus` itself.

**Decide:** the viewer (or keep `gthumb`), whether to add the crop patch to `qView`, and
Adwaita or Papirus for the machine. Setting the platform theme is a change to
`environment.d/wayland.conf` and needs its own branch.

**Done when:** one viewer opens the ten image types with crop and rotate working, and a Qt
application shows icons from the chosen theme.


## 15. Verify fingerprint recovery after resume

**Recovery installed 2026-10-05; hardware verification pending.** During several normal suspend/resume cycles, include one scan active before suspend. Confirm the `fprintd-resume` submission and fprintd stop/start evidence in matching journal windows, fingerprint recovery after wake, and password fallback. Also observe a cycle with fprintd inactive: the hook should leave it inactive. No automatic suspend or forced scan failure. Procedure and rollback: [system notes](docs/system-notes.md#fingerprint-recovery-after-resume-2026-10-05).
