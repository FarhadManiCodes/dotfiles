# TODO

Open work and decisions that need the user. Planning clarified 2026-09-11; renumbered again on
2026-09-16 when the test runner was delivered and closed. Item 4, the ath11k regulatory-domain
error, was closed to `revisit.md` on 2026-09-18 once 5GHz was tested and the error confirmed
cosmetic. Item 5, removing `mate-polkit`, was run by the user and closed to `revisit.md` the
same day. Item 4, Alt+p resolving citations from refinery, was built and verified 2026-10-02 and
closed to `revisit.md`; item 6, review copies for four imported books, was delivered 2026-10-02
by refinery's `--from review` stage (see `skills/papers-and-pdfs/references/convert.md`); item 9,
screenshot annotation, was delivered 2026-10-04 with Flameshot on Shift+Print; item 13,
sysup's yts step for the C++ rewrite, was reviewed and merged 2026-10-09 and proven by the
user's `sysup` run the same day (see `docs/architecture/zsh.md`); item 2, an editor + agent
tmux layout, was removed 2026-10-23, superseded by the Herdr migration
(`docs/herdr-implementation.md`, Milestone 5). The remaining numbers are kept. Accepted
findings remain in `revisit.md`; the runner's dropped follow-on scope is recorded there.

Off-machine backup remains deferred.

| Item | Status | Next requirement |
|---|---|---|
| 1. Off-machine backup | **Deferred by the user** | Explicitly reopen, then choose destination and scope |
| 3a. Sensitive-site Tridactyl rules | **Closed 2026-10-02, verified** | — |
| 3b. Tridactyl workflow review | **Closed 2026-09-16, no action** | — |
| 3c. Firefox containers | **Closed 2026-09-16, no action** | — |
| 5. Move useful study-library books into papis | Open 2026-09-27 | User picks the books |
| 7. Router drops wifi every ~8 h | Found 2026-09-29 | Check the router's schedule |
| 8. Battery alarm wakes the laptop at 5% | Found 2026-09-29 | Decide whether to keep the wake |
| 10. Evaluate pv, entr and strace | Open 2026-10-02 | Audit usefulness, overlap and dependency cost |
| 11. Install qalc and VisiData for the study books | qalc installed 2026-10-04 | Install VisiData with `uv tool`, then try both |
| 12. Python venv for the study-book experiments | Open 2026-10-03 | Pick which venv, then install |
| 14. Image viewer and Qt icon theme | Open 2026-10-05; user will work on it | Pick a viewer, then set the Qt icon theme |
| 15. Fingerprint recovery after resume | Installed; hardware verification pending | Several normal cycles, including an active scan; check fingerprint and password unlock |
| 16. Offline PDF signatures | Explore; no implementation yet | Compare established tools with a small Sioyek integration |
| 17. Stale results and overlapping writes | Code findings; live reproduction pending | Guard header/source switching, bibliography updates, and Docs sync-back |
| 18. External text and download limits | Code findings; implementation pending | Four guards for notifications, OCR responses, Docs terminal text, and mirror downloads |
| 19. Phone clipboard link | Open 2026-10-16; user will build their own | Design a light PC-to-phone (and back) text path |
| 20. External browser links | Planning; implementation pending | Establish Firefox delivery and focus behavior across windows |
| 21. Test usefulness and reliability | Future audit | Inventory coverage and measure sequential suite durations |
| 22. Bounded Vifm image previews | Investigation only | Measure decoder costs, then choose a preview policy |
| 23. Timed notification snoozing | Investigation only | Explore Mako modes and transient timers; preserve critical alerts |
| 24. Claude release cleanup | Investigation only | Establish active-session risks and choose a retention policy |
| 25. Consistent battery reporting in batt | Planned | Align estimates and state labels with the status menu |
| 26. sysup upgrade lifecycle | Investigation only | Test dependency replacement, partial failures and recovery reporting |

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

## 16. Explore offline PDF signatures

**Requested 2026-10-12.** Currently uses online tools; an offline workflow would be useful for placing a handwritten signature on a PDF, adding text or dates, and saving a separate completed copy. Omarchy's Signed is excluded by preference.

**Explore:** established tools such as Xournal++ and Okular, compared with a small extension or feature in the user's Sioyek fork. Distinguish placing a signature image from certificate-based digital signing before choosing scope. For Sioyek, investigate visual placement and resizing, PDF coordinates and rotation, reusable signature storage outside the public dotfiles, and export that preserves the original document and existing PDF features.

**Next decision:** choose a standalone tool, a Sioyek command that opens one, or a narrowly scoped native signing feature. No installation or implementation is authorized by this exploration item.

**Done when:** choose a practical offline workflow and confirm a saved copy displays correctly in another PDF reader.

## 17. Guard stale results and overlapping writes

**Requested 2026-10-12.** Review of local code found three places where work based on earlier state can affect newer state. These are code findings, not reproduced live failures. This item records follow-up work; no implementation yet.

- **Neovim header/source switching — first priority:** `nvim/lua/config/lsp.lua` sends an asynchronous clangd `textDocument/switchSourceHeader` request and edits the returned file without checking whether the originating buffer or request is still current. Switching buffers or issuing another request before the response arrives can let an older response navigate away from newer state. Capture the originating buffer and a request generation; apply the response only while both still match. Verify delayed responses after switching buffers and responses arriving out of order.
- **Bibliography updates:** `bash/papis-bib` reads, computes, and atomically replaces `refs.bib` without a lock around the transaction. Separate editor instances, or pruning overlapping a compile, can overwrite changes computed from the same earlier file. Add a per-bibliography lock covering read through write; interactive pruning also needs to detect external edits before saving. Atomic replacement alone prevents partial files, not lost updates. Verify overlapping syncs preserve all additions and pruning refuses to overwrite intervening edits.
- **Google Docs sync-back:** `bash/gdocs-open` downloads directly over the original file. A local edit during the download or another sync terminal targeting the same file can be overwritten. Download to a temporary file, check that the original still matches its starting state, and only then replace it; serialize syncs with a per-file lock. Verify intervening local edits are preserved and overlapping syncs cannot overwrite one another unchecked.

**Done when:** each guard has focused behavioral verification, with stale navigation discarded and conflicting writes rejected or serialized.

## 18. Treat external display text as untrusted and bound downloads

**Requested 2026-10-12.** Four follow-ups from local source inspection; no implementation yet. Prioritize notification escaping and OCR response limits. Wi-Fi notification text already escapes markup and sanitizes control characters, so it needs no corresponding change.

1. **OCR and QR notification escaping:** `bash/capture-ocr` and `bash/qrscan` pass recognized text directly into notification bodies; Mako enables Pango markup by default. Escape ampersands and angle brackets in displayed text while preserving the original clipboard contents. Verify literal markup-like text displays correctly and clipboard bytes are unchanged.
2. **OCR response byte limits:** `bash/capture-ocr` parses successful JSON responses and reads HTTP error bodies without a byte cap. The short notification preview happens after downloading the response. Bound reads before parsing, including error responses, and reject oversized replies explicitly. Verify oversized success and error responses stop at the limit and are not reported as successful OCR.
3. **Google Docs terminal rendering:** `bash/gdocs-open` puts filenames and error text through `echo -e`, interpreting backslash escapes; embedded terminal control characters can also alter the display. Use fixed `printf` formats and sanitize control characters in variable display text while retaining the actual paths for file operations. Verify unusual filenames and error text cannot inject terminal formatting or controls.
4. **Mirror status download limit — lower priority:** `zsh/functions/sysup/mirrorlist.zsh` downloads the mirror status JSON with an eight-second timeout but no byte cap. Bound downloaded bytes and report an oversized response as an unsuccessful validity check. Verify ordinary responses still parse and oversized responses cannot produce a successful check.

**Done when:** all four guards have focused behavioral verification, preserving original data for clipboard and file operations while bounding external downloads and rendering external text literally.

## 19. Share text between the phone and the laptop

**Requested 2026-10-16.** KDE Connect does this but pulls about 200 MiB of KDE Frameworks
(`breeze-icons` alone is 57 MiB), so it was not installed. The user will build a lighter
version. Starting points: `ntfy` (`curl -d text ntfy.sh/<topic>`, use a self-hosted server or
a long random topic) for laptop to phone; Android 10+ blocks background clipboard reads, so
phone to laptop needs a manual share or notification action. Any `wl-copy` call needs
`setsid`.

**Done when:** copying on the laptop makes the text available on the phone and the reverse
path is chosen, with no heavy dependency pulled in.

## 20. Open external links in a predictable browser window and bring it into view

**Requested 2026-10-16. User story:** As a user with multiple Firefox windows, I want a link opened from another application to appear in a predictable window and bring that window into view, so I can continue without searching for which window received the tab. The user reports that links currently open out of sight and that two browser windows make the destination confusing.

**Goals:** make link delivery and focus agree, work across workspaces, and preserve normal/private browsing and profile boundaries. Prefer an on-demand solution using Firefox and Niri's existing capabilities; add no persistent daemon or idle polling.

**What Omarchy does — reference `9f49906d2`:** a hidden `applications/omarchy-browser.desktop` routes HTTP/HTTPS to `bin/omarchy-launch-browser` through `config/hyprland-mimeapps.list`. The actual browser remains in the ordinary `mimeapps.list`; `omarchy-cmd-default-browser` skips the routing entry to avoid recursion. After launch/handoff, `omarchy-hyprland-focus-app` sorts matching windows by `focusHistoryID` and focuses the most recently used one with a workspace-aware dispatcher. This is a destination heuristic, not confirmation that the window received the tab. `omarchy-cmd-browser-handoff` bypasses startup through Chromium-family singleton sockets only; Firefox falls back to its normal executable. Their tests establish handler resolution, recursion avoidance and selection by focus history, but do not prove real Firefox tab delivery with multiple windows/profiles. They also suppress browser default-handler checks because the wrapper sits in front of the actual browser; assess that tradeoff before adopting a wrapper.

**Implementation hints:**

- Reproduce with two normal Firefox windows and a distinguishable test link, including windows on different workspaces. Trace the actual caller paths: `xdg-open`, the OpenURI portal, and direct launches. Local HTTP/HTTPS defaults currently use `firefox.desktop`; `environment.d/defaults.conf` sets `BROWSER=firefox`, and `bash/gdocs-open` calls `setsid firefox --new-tab` directly. A MIME handler alone will not cover direct launches.
- First investigate whether the existing desktop entry and Firefox/Niri activation can reliably raise the receiving window. The installed Firefox desktop entry already has `StartupNotify=true`; trace whether activation information survives each caller path rather than assuming this flag alone solves it.
- If a helper is necessary, consider a hidden desktop handler forwarding URL arguments to a shared on-demand opener. Keep browser selection separate from routing and prevent recursion. Confirm desktop-specific MIME lookup on this Niri session before choosing a filename; do not copy Omarchy's Hyprland-specific path blindly. Include installation mappings for any new helper or desktop entry.
- Establish Firefox's actual window-selection behavior before choosing a focus strategy. Do not focus the first app-id match or assume the most recently focused compositor window is the browser's destination. Niri supports querying windows and `niri msg action focus-window --id ID`; inspect the installed IPC schema for usable selection information. If observing launch/window changes is needed, use a short-lived event subscription with a deadline. A compositor window list alone does not identify which existing window received a tab.
- Define and document the destination rule for ordinary external links, multiple profiles and private windows before implementation. Prefer normal Firefox window reuse where reliable; if delivery cannot be correlated, evaluate an explicit new-window fallback or user choice rather than silently guessing. Preserve explicit private/profile launch requests and pass URLs as arguments without shell evaluation or logging their contents.

**Acceptance criteria:**

1. With Firefox closed, an HTTP or HTTPS link opens once in Firefox and its window becomes visible. With one normal window open, the link opens once in that window and brings it into view, including from another workspace.
2. With two normal windows open, repeated distinguishable links from another application follow the documented destination rule; the focused window is the one containing the new tab. Verify after alternating which browser window was last used and with the two windows on different workspaces.
3. Verify `xdg-open`, a real application using the OpenURI portal, and the existing direct-launch path used by `gdocs-open`; document any intentionally excluded callers. Test the real desktop as well as isolated handler/argument tests.
4. Ordinary links do not unexpectedly enter a private window or a different profile. Explicit private/profile requests retain their requested context. Verify supported combinations with normal and private windows and multiple profiles; define unsupported cases visibly before shipping.
5. URLs containing query strings, ampersands, percent escapes and fragments arrive intact. Each invocation opens exactly once; there are no recursive handler launches, duplicate tabs, or arbitrary unrelated windows focused. Two rapid link requests do not let an older request steal focus after a newer one.
6. Browser default resolution remains coherent with any routing handler, existing unrelated MIME associations remain intact, and the change can be rolled back. Delivery or focus failure is reported usefully without re-opening an already delivered link or exposing its URL in diagnostics.
7. No persistent daemon, browser-debugging service, or idle polling is introduced. Any temporary observation or wait ends on success or a bounded deadline and cleans up its child processes.

**Scope:** planning and later implementation; this TODO change does not authorize installing or activating a handler now.

## 21. Audit the existing tests for usefulness and reliability

**Requested 2026-10-16.** Keep the current sequential runner. First establish how many tests exist, what they cover and how long the suites take; do not assume the suite is large or needs parallel execution. Inspired by Omarchy's test cleanup and synchronization improvements in the latest pull.

**Review:** inventory suites reached by `bash/run-tests` and any tests outside that entry point. Check that important behavior and failure paths are exercised, assertions can detect the failures they claim to cover, and stubs model the relevant real behavior. Look for inherited-environment dependencies, accidental live-system effects, leaked processes or temporary files, fixed sleeps, and cleanup that waits for deadlines unnecessarily. Distinguish mocked coverage from hardware or desktop checks that still need manual verification. Identify redundant tests and important gaps without adding tests merely to increase the count.

**Done when:** report the inventory, measured suite durations, coverage limits and a short prioritized list of evidence-backed improvements. Keep sequential execution unless measurements justify revisiting it; keep timing-sensitive checks isolated. Any proposed speedup must retain meaningful failure detection and cleanup. Follow the performance-measurement skill when timing suites. This is a future audit, not authorization to rewrite or expand tests now.

## 22. Investigate bounded and optional image previews in Vifm

**Requested 2026-10-17. Investigation only:** decide how to keep browsing responsive when a selected file is an expensive or malformed image, while retaining useful previews for ordinary images. Do not change preview behavior or install tools as part of this TODO.

**What Omarchy does — references `dc2b18098` and `f4357a3b2`:** `bin/omarchy-tailscale-receive` previously passed received image files to notifications through `--image`, choosing by filename extension. It now uses the same fixed file glyph for every received file, displays the filename and save location, and retains an explicit click-to-open action using `xdg-open` with the path as a separate argument. Receiving a file therefore does not automatically request image decoding just to announce delivery. This avoids that preview entirely; it is not a thumbnail optimization. Their follow-up tests inspect the notification's actual arguments/hints, rejecting `image-path` and `image-data` while checking the glyph, urgency, localization, and literal click-to-open path.

**Local relevance:** Vifm's `fileviewer` runs when a file is selected in the preview pane, before explicitly opening the image. `vifm/vifmrc` already has decoder-assisted JPEG downsampling; preserve that work. The BMP/GIF/ICO/PNG/TIFF/WebP/AVIF group still passes the original file directly to Chafa with a small output size. That output size alone does not establish bounded decoding memory or time. SVG uses a separate `resvg -w 800` path and should be considered when defining the preview policy. These are candidates from source inspection, not demonstrated failures for every format. The custom notification scripts checked in this review do not attach received image files, and the clipboard picker already lists text rather than thumbnails; neither currently needs the Taildrop change. Ordinary installed application icons are separate from previewing a received file. Third-party applications' notification behavior has not been audited.

**Options to investigate:**

- **Preview on request:** show basic file information or a fixed image label by default, with an explicit action to generate a preview or open the viewer. This is closest to Omarchy's approach; assess the extra interaction against the value of automatic previews.
- **Automatic previews within a budget:** keep ordinary images convenient, but run decoding with bounded memory, wall time, threads, and temporary storage, falling back to file information when a limit is reached. Scope limits to the entire preview pipeline and clean up decoder children. A byte-size check alone misses highly compressed images with huge dimensions; inspecting dimensions can itself invoke a parser and needs a budget.
- **Format-aware downsampling:** investigate each installed decoder's support for reducing work before full decoding, following the existing JPEG approach where supported. Resizing after a full decode and reducing Chafa's terminal output are not equivalent to limiting the initial decode. Treat animated images, multi-page TIFFs, and extreme SVG dimensions explicitly. Resource limits remain useful where early downsampling is unavailable.
- **Hybrid policy and optional caching:** compare bounded automatic previews for common cases with an explicit preview action for costly or unsupported cases. If caching is worthwhile, bound its size, invalidate it when the source changes, and define cleanup. Prefer short-lived helpers and existing Vifm capabilities; add no persistent daemon. Changing selection should stop obsolete preview work and prevent an older result from replacing the current selection's preview.

**Investigation outcome / acceptance criteria:** reproduce current behavior with ordinary and very large images before choosing a policy. Measure end-to-end preview latency and decoder peak memory, not just terminal output size, following the performance-measurement skill. Include a small compressed file with large pixel dimensions, animated or multi-page input, a malformed file, and rapid selection changes. Document which formats can decode at reduced resolution, which need limits or an explicit action, the proposed limits and fallback text, and the usability tradeoffs. A later implementation must preserve the existing JPEG improvement, keep browsing responsive, clean up children and temporary files, and still allow explicit opening of the original file. Resource bounds reduce exposure and cost; they do not establish that an image decoder is immune to malformed input. Choose the policy with the user before implementation.

## 23. Investigate timed notification snoozing with Mako

**Requested 2026-10-20. Planning only. User story:** temporarily silence ordinary notifications while concentrating, with an explicit duration and automatic resumption, without adding another persistent daemon. Keep Mako; start with global snoozing and consider per-application snoozing only if needed.

**Omarchy's philosophy:** quiet is a delivery policy rather than deleting notifications or stopping the notification service. A source or all sources can be snoozed until an absolute deadline. Non-ephemeral suppressed messages remain available for deliberate review in the panel; transient notifications are discarded. Expiry resumes delivery, while reviewing held messages is a separate action. Screen sharing offers a timed snooze rather than silently enabling it. Their implementation lives inside the existing Quickshell notification daemon, not a separate snooze service.

**Upstream references:** notification rewrite introduced in `4671ae2d3` ("Replace the notification engine with Omapager's stacks, snoozes and panel"), merged by `03ff1eff3`. Use the final reviewed snapshot `7901c449a` when studying the resulting design; intermediate helper/sandbox implementations in this pull were subsequently removed. Repository: https://github.com/basecamp/omarchy.

- [`Service.qml`](https://github.com/basecamp/omarchy/blob/7901c449a/shell/plugins/notifications/Service.qml): `snoozeSource`, `snoozedUntil`, `unsnooze`, `unsnoozeAll`, expiry handling, and IPC methods `snooze`, `snoozeAll`, `snoozes`. Stores per-source `since`/`until` timestamps; global key `*`. Extending an existing snooze and starting a fresh duration are distinct behaviors. Its expiry housekeeping uses a timer in the existing shell; this need not be copied into a new local polling loop.
- [`Delivery.js`](https://github.com/basecamp/omarchy/blob/7901c449a/shell/plugins/notifications/Delivery.js): pure `quietReason`, `bypassesQuiet`, and `isEphemeral` functions separate delivery policy from presentation. Their exceptions are own user-action toasts, critical messages named `notify-send`, and optionally detected verification codes. These names are self-asserted policy conventions, not authenticated identities. Do not copy this allowlist blindly: local power/network/service-failure notifiers have their own names.
- [`Store.js`](https://github.com/basecamp/omarchy/blob/7901c449a/shell/plugins/notifications/Store.js): validates and bounds quiet-state persistence and held history. State lives in `~/.local/state/omarchy/notifications/quiet.json`; history defaults to 100 entries/24 hours, with verification-code content redacted before persistence.
- [`NotificationPanel.qml`](https://github.com/basecamp/omarchy/blob/7901c449a/shell/plugins/notifications/NotificationPanel.qml) and [`Settings.js`](https://github.com/basecamp/omarchy/blob/7901c449a/shell/plugins/notifications/Settings.js): source/global controls, duration choices and preferences. [`docs/notifications.md`](https://github.com/basecamp/omarchy/blob/7901c449a/docs/notifications.md) documents silencing, snoozing, persistence and IPC.

**Local starting point:** `mako/config` defines ordinary/critical styling, expiry and service-failure grouping, but no quiet mode. `niri/config.kdl` currently binds Mod+N to dismiss all notifications; preserve that existing action. Investigate the installed Mako version's mode, visibility and history behavior before selecting rules. Hidden, expired and dismissed notifications are different: do not assume hiding preserves messages or that resuming will avoid a backlog burst.

**Possible implementation:** an on-demand helper enables a dedicated Mako snooze mode and arranges a transient systemd user timer to remove only that mode at the deadline. Use existing Mako/systemd capabilities, no sleeping background shell, new daemon or idle polling. Expose duration, remaining time and early cancellation through a shortcut/menu when requested. Treat timer creation and enabling quiet as one recoverable operation: failure must not leave quiet enabled indefinitely. Read the systemd-user-units skill before implementation. Define replacement/extension semantics, serialize overlapping requests, and prevent an older timer from cancelling a newer snooze through cancellation plus generation/deadline checks. Keep independent manual DND separate. Decide explicitly whether a snooze survives logout/reboot; if it does, store an absolute deadline and reconcile it at startup. Verify suspend/resume expiry rather than assuming a relative timer follows wall time.

**Decisions before implementation:** choose which local critical alerts must bypass quiet, whether suppressed messages should be retained and how to review them, expiry/backlog behavior, and a visible indication that snoozing is active. Verification-code detection and exceptions are optional later work, with false-positive and privacy costs; no need to reproduce Omarchy's full panel, web-source grouping, history store or screen-share integration.

**Acceptance criteria:**

1. Ordinary notifications are quiet for the selected duration, automatically resume, and can be resumed early. Approved critical alerts still appear; verify actual local notifier app names and urgencies.
2. Repeated, overlapping and cancelled requests behave predictably. An expired older timer cannot undo a newer snooze, and ending snooze leaves unrelated Mako modes unchanged.
3. Timer/helper failures do not strand the desktop in quiet mode. Mako restart, suspend/resume and logout/login follow the documented policy, with useful diagnostics and no notification-content logging.
4. Verify retained-message/history behavior and the chosen backlog policy with real Mako notifications; no unexpected flood when quiet ends. Existing Mod+N dismissal and ordinary grouping remain usable.
5. No additional persistent daemon, polling loop, heavy shell UI or package dependency is introduced. Test isolated timer/mode failure and race paths plus focused live desktop behavior before activation.

**Scope:** investigation and later implementation; this item does not activate snoozing or authorize installing software now.

## 24. Investigate Claude release cleanup around active sessions

**Requested 2026-10-20. Investigation only:** determine whether cleanup can remove a release still needed by a running Claude session, and choose a proportionate protection policy before changing it.

**Current behavior:** `_sysup_prune_claude_versions` in `zsh/functions/sysup/claude-prune.zsh`, called by both `sysup` and `sysclean`, preserves the release selected by `~/.local/bin/claude` and the newest other completed version. It removes older version-named entries from `~/.local/share/claude/versions` without checking whether sessions still execute them. A long-running session spanning several upgrades can therefore outlive the retained fallback. This is a source-level possibility, not a demonstrated session failure. Unlinking an executable on Linux does not by itself stop a process already executing it.

**Omarchy reference:** commit [`02da3adab`](https://github.com/basecamp/omarchy/commit/02da3adab54846eb9fe605e95d2229f596708b54) sets `upgrade.auto_prune = false` in `etc/mise/conf.d/omarchy.toml`, explaining that an upgrade must not delete an installation directory underneath a live session. Transfer the lifecycle principle; this system does not need Mise to apply it. Claude's versioned native binary layout differs from a tool installation containing runtime files, so establish the actual dependencies before claiming equivalent breakage.

**Investigation:**

- Inspect how the installed Claude updater retains/removes versions and how live processes identify their executable. Determine whether a session later reopens its own binary, launches helpers from that release, or needs adjacent files. Avoid inspecting or logging session contents or credentials.
- Use isolated versioned executable fixtures first to compare process identity before and after an upgrade and unlink, including a session older than both the selected release and fallback. Test any real Claude behavior only with an explicitly chosen disposable session; do not prune files underneath personal sessions as a probe.
- Compare retaining detected active releases alongside current plus fallback, deferring all pruning while Claude sessions exist, and leaving release cleanup to the native updater if it now provides a suitable policy. Consider disk cost and lifecycle uncertainty rather than adding a watcher or daemon.
- If using `fuser` or `/proc`, prove the probe detects a known running fixture. Define behavior for missing tools, permission/probe failures, deleted executable paths, PID reuse and sessions starting during cleanup. A one-time “not in use” observation is not synchronization with concurrent launches or the updater; document residual races or use a coordination mechanism the participants actually share.
- Keep scope limited to completed release binaries. Preserve current/fallback selection, updater staging files, unrelated files and symlinks outside the intended directory. Do not reintroduce Codex cleanup; it was removed separately at the user's request.

**Acceptance criteria:** report evidence of whether active-version removal causes a practical problem, or state that no failure was demonstrated. Recommend a clear retention policy with its limits. If a later fix is agreed, verify active older releases survive, eligible inactive releases can be removed, current/fallback and staging remain intact, uncertainty preserves files, and both `sysup` and `sysclean` use the same policy. Cover races/failure behavior with isolated fixtures and run focused Zsh/tests without live cleanup.

**Scope:** investigation and recommendation only; this TODO does not change Claude cleanup, install tools, stop sessions or remove release files.

## 25. Align batt with the status menu's battery reporting

**Requested 2026-10-23. Planning only:** make the terminal `batt` helper in `zsh/helpers.zsh` follow the sensible battery-reporting rules already used by `bash/status-menu`. No battery configuration or notifier changes are needed for this item.

**Current behavior:** `batt` calculates remaining time for any positive `power_now`, so a tiny transient reading after resume can produce an unrealistic estimate. It guards zero draw, but labels every non-discharging state as “Charging / AC”, including full or not-charging states. The status menu already suppresses power/time estimates below 1 W, handles unreadable charge data and estimates charging time to the configured charge limit.

**Omarchy reference:** [`eb0c5155c`](https://github.com/basecamp/omarchy/commit/eb0c5155c8e52509972f06971512bd8a0c6f0c50), `bin/omarchy-battery-status`, explicitly labels fully charged batteries and omits estimates or power readings that lack useful supporting data. Adopt the reporting principle while retaining this machine's existing threshold and charge-limit policy.

**Implementation hints:** inspect the current status-menu and power-notify behavior before choosing shared logic or a small helper adjustment. Distinguish charging, discharging, full, not charging and unknown states; do not infer charging merely from absence of discharge. Suppress remaining-time estimates for missing, zero or unsettled draw, and retain an explicit unavailable/calculating indication where useful. If adding a charging estimate, target the configured charge limit rather than assuming 100%. Preserve the existing sensor dashboard and introduce no daemon or polling.

**Acceptance criteria:** use isolated readings to check ordinary discharge, tiny/zero draw, charging to a configured limit, full/not-charging states and missing readings. Estimates remain finite and meaningful; labels reflect the reported state; unavailable readings do not become plausible zero values. Run focused Zsh checks and verify normal terminal output before considering the change complete. This TODO authorizes no implementation yet.

## 26. Investigate sysup dependencies across upgrades and partial failures

**Requested 2026-10-23. Investigation and isolated testing only:** establish whether `sysup` can finish reliably when an earlier update replaces executables, libraries or helpers needed by later steps. This is a possible failure class, not a demonstrated local bug.

**Omarchy reference:** [`ce39c5e9e`](https://github.com/basecamp/omarchy/commit/ce39c5e9e9e4f5db7e023a07d0eeda9351ef9c80), channel-switch handling in `bin/omarchy-channel-set` and its package-refresh path. A repository transition could downgrade Omarchy's own updater before it finished switching packages, leaving an incomplete transition and misleading recovery instructions. Their fix preserves the required machinery through the transition and checks installed packages before describing the resulting state. This system has no equivalent Omarchy channel switch; transfer the lifecycle and reporting questions rather than their package exclusions.

**Investigation:** inspect `zsh/functions/sysup.zsh`, its modules under `zsh/functions/sysup/`, and `docs/architecture/zsh.md`. Map which commands and on-disk helpers later steps resolve after paru, uv, Cargo, Herdr and plugin updates. Distinguish functions already loaded in the shell from external commands, dynamically loaded libraries and files reopened later. Check dependent-step ordering, whether a failed prerequisite permits unsafe continuation, and whether the final status describes actual completed, failed and skipped work. Inspect current behavior before proposing snapshots, version pinning or additional infrastructure. Keep Claude active-release retention in item 24 as a related but separate investigation.

**Acceptance criteria:** exercise the real orchestration with isolated command substitutes and temporary homes: an early update replaces a helper with a compatible version, an incompatible or missing version, or fails after partially changing fixture state. Confirm later steps either use a supported dependency or stop/skip with a clear reason; partial work never becomes an unqualified success. Check non-zero final status where appropriate, accurate failure summaries and actionable retry instructions; retries must not blindly repeat unsafe completed actions. Prove fixtures reached the intended transition and assert resulting files/calls as well as messages. Report existing protections, demonstrated gaps and coverage limits; recommend only evidence-backed changes. Do not run live `sysup`, upgrade packages, alter repositories or replace real tools as a test.
