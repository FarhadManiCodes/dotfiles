# Omarchy comparison — closed 2026-09-08

Read 2026-09-05 against `~/projects/omarchy` at `49306774`..`36e56f4f` (v4.0.0.alpha) in four
passes: the reference docs and `plans/`, then `install/`, then every config both repos have,
then the 179-file `default/` tree. Omarchy is DHH's Arch distribution — Hyprland, Quickshell,
gaming, branding, ~440 commands for many users. This is one machine, one user, niri. Most of it
does not transfer; this records the part that did, and the part that deliberately did not.

**Every item below carries a disposition. Nothing here is open.** It is kept for two jobs: so a
declined proposal is not re-raised at the next audit, and so a later audit does not treat
Omarchy as the reference implementation and "harmonise" toward it.

> **On the shape of this file.** It was 1780 lines. Each finding carried its original argument,
> then the correction that overturned half of it, then the disposition — and once a claim is
> withdrawn, the correction to it has nothing left to correct. Both halves were dropped together
> on 2026-09-08. Item numbers are unchanged because `TODO.md` cites them;
> the full argument for any of them is in git history at the old path: `git log -p -- omarchy-comparison.md`.

---

## Adopted

| # | Change | Where it lives |
|---|---|---|
| 1 | Spotify `app.toml` drift detection — parsed-TOML comparison, `client_id` excluded | `bash/config-drift`, `tests/test_config_drift.py` |
| 4 | `/etc/vconsole.conf` tracked (`FONT=default8x16`) — reproducibility, not a boot defect | `etc/vconsole.conf` |
| 5 | `/etc/conf.d/wireless-regdom` tracked — preserves `WIRELESS_REGDOM="DE"` across a rebuild | `etc/conf.d/wireless-regdom` |
| A | `pacman.log` scanned per **transaction** across the whole update window, not just the last one | `sysup` records a `device:inode:bytes` boundary, passes `--pacman-since` |
| B | Symlink integrity — expected mappings from `install.sh` checked for missing, replaced, dangling and wrong-target links | `bash/config-drift` |
| 12 | SSH keepalives — `ServerAliveInterval 20`, `ServerAliveCountMax 3` (~60 s to detect a dead link) | `ssh/config` |
| 14 | lazygit's four broken custom commands repaired — wrong source path, missing prompt `key:`, two unguarded tools | `48aaca4` |
| 17 | `TAG+="uaccess"` instead of `MODE="0666"` — access follows the logind session and ends at logout | `etc/udev/rules.d/51-android.rules` |
| 19 | USB autosuspend denied for the **fingerprint reader only**, not globally as Omarchy does | `etc/tlp.d/10-local.conf` (`USB_DENYLIST="27c6:6594"`) |
| 19 | `pcmanfm-qt` moved to `footclient`, the last launcher still spawning a standalone `foot` | `pcmanfm-qt/settings.conf`, three keys |
| 23 | `VerbosePkgLists` (no CLI equivalent) and `Color` (pacman defaults to **off**, so there is nothing to select without it) | `etc/pacman.conf` — `a816e96` |
| — | Two identical floating window-rules merged under one rule with two `match` lines, keeping distinct app-ids | `niri/config.kdl` — `0990e49` |
| 16 | An `<S-CR>` completion binding — the one change the withdrawn Shift+Enter finding did produce | `nvim` submodule, branch `audit-2026-09` |
| — | `capture-ocr` (from their `tesseract` entry, done better: Gemini REST, stdlib-only) and `bash/qrscan` (from `zbar`) | `bash/`, `revisit.md` |

Three adopted items are corrections found *while* comparing rather than things Omarchy has:
finding 14's lazygit commands, finding 19's `pcmanfm-qt`, and the window-rule merge.

## Declined

Recorded with the reason, because a bare "no" gets re-proposed.

| # | Proposal | Why not |
|---|---|---|
| 2 | `vm.swappiness = 150` | 10 works; zero `pswpin`/`pswpout` since boot, zero pressure. Not "wrong for the hardware" — that claim was withdrawn. `revisit.md` |
| 3 | Fixed-byte dirty limits (64 MiB / 256 MiB) | Theirs are **smaller**, not larger. No stalls observed; 5% / 10% kept as a baseline. `revisit.md` |
| 6 | Restoring `/etc/pam.d/{login,ly}` to the package stack | `login` differs by one blank line. `ly` genuinely differs (includes `system-login` directly) but works; changed nothing. `revisit.md` |
| 8 | A broad convention test suite to match their 284 files | Add tests for a concrete failure worth preventing, never to match a count. Standing position — see the invariant table below |
| E | 10 GiB free-space precheck in `sysup` | `CheckSpace` is on in `pacman.conf` and the filesystem is 3% used. Defends a condition this machine is nowhere near — and a root-only guard would miss the separate `/boot`, which is the small one at 993 MiB. (`flock`, the other half of E, was already present, though **not unconditional**: `sysup` continues without a lock if the lock file cannot be opened) |
| 9 | Full-disk encryption | Deferred to the next rebuild, not rejected — see below |
| 10 | A niri `scroll-factor` for touchpad scrolling | Touchpad scrolling is comfortable. niri accepts it globally **and** per window-rule (both pass `niri validate`); the window-rule form is the narrower start if it ever matters |
| 11 | Pinning Vim/Zsh/tmux plugins to match nvim's lockfile | Priced, conscious acceptance. Three more lockfile mechanisms for 20 mostly-cosmetic packages. `revisit.md` |
| 12 | `dirmngr.conf` keyservers | Not a security feature — `makepkg` checks against a fingerprint the PKGBUILD pins, so keyservers deliver, they do not vouch. Zero key-import failures since 2025-11-20. `revisit.md` |
| 15 | A fontconfig emoji alias | **No defect existed** — see 25 |
| 16 | foot `[text-bindings]` for Shift+Enter | foot 1.28.0 speaks the Kitty protocol and `tmux.conf` already declares `foot*:extkeys`, so applications negotiate it at runtime. **Do not adopt later**: `[text-bindings]` is unconditional and never reverts, so programs receiving a plain newline today would start receiving `\e[13;2u`. `revisit.md` |
| 18 | `pull.rebase`, `rerere.autoupdate`, `tag.sort` | Integration here is deliberately `--no-ff`; seeing a replayed rerere resolution unstaged is wanted; there are no tags. `78db45d` took four *other* settings from the same file |
| 20 | `systemd-oomd` | The architectural one — see below |
| 21 | `zram-size = ram` | Their 3:1 zstd assumption holds for ordinary anonymous memory. Large float arrays approach 1:1, so on a numeric-work machine a `ram`-sized device could consume ~58 G for no gain. `ram / 3` stands. Their other two lines are already true here: `zstd` is the kernel default, and `swap-priority = 100` is what the generator sets when zram is the sole swap — theirs is explicit only because they also carry a disk swapfile at `pri=0` for hibernation, which this machine deliberately does not |
| 24 | Firefox `policies.json` (5 prefs) | vaapi already on; no fractional scaling (`scale: 1.0`); `widget.disable-swipe-tracker=false` **is** Firefox's default, so it is a no-op; the rest cosmetic |
| 26 | ALPM hooks | Theirs force users through `omarchy-update`. `snap-pac` already brackets every transaction here regardless of what invoked it. Worth remembering only as the mechanism: `PreTransaction` + `AbortOnFail` is the only hard gate in front of pacman |
| 28 | Not exporting `BROWSER` | Their claim is true (`xdg-settings set` refuses while `$BROWSER` is set, so Firefox's "Make Default" button silently fails here) but their conclusion inverts: `XDG_CURRENT_DESKTOP=niri` is not in xdg-utils' DE list, so `xdg-open` takes the generic path where `$BROWSER` is a real fallback ahead of a hardcoded guess-list. `environment.d` stays its home — `zsh/.zshenv` would reach only zsh, losing systemd user units. The cost is a button we do not use, since `mimeapps.list` is hand-maintained |
| 29 | `xcompose`, `themed/btop.theme.tpl`, `themed/claude.json.tpl`, `launcher.hides`, the yt-dlp browser button | No compose key is configured (would be two changes); btop is pinned by decision; Claude Code's `"theme": "auto"` is already the terminal-native mechanism their template exists to work around; pasting a URL is how downloads happen here |
| — | `zswap` tmpfiles rule | `zswap.enabled=0` is already on the kernel command line |
| — | `fs.inotify.max_user_watches` | Already 524288, set by `/usr/lib/sysctl.d/10-arch.conf` — same value they set |
| — | `DefaultLimitNOFILE=65536:524288` | systemd's own docs caution against raising the **soft** limit past 1024: `select(2)` cannot handle descriptors above 1023. A service with a demonstrated need can set `LimitNOFILE=` itself |
| — | `DefaultTimeoutStopSec=5s` | No stop-timeout problem recorded. Five seconds globally gives every service little recovery time, including rclone's lazy FUSE unmount in `ExecStop` |
| — | The migration system, the `omarchy-*` command router, `omarchy-hook`, `omarchy-state` | All four exist so thousands of installs and third parties can be served without patching. One machine, one user, no third party. (One trick worth remembering: their migration files are mode 0644 with **no shebang**, run as `bash -euo pipefail <file>`, so they cannot execute by accident) |
| — | Chromium web apps | `--app=` is a Chromium feature; Firefox has no equivalent and no Chromium-family browser is installed. Adopting it means a second browser and a second cookie jar. `firefox --new-window` gets no distinct `app-id`, so no niri rule can single it out — which removes most of the point |
| — | `xdg-terminal-exec` and their `foot.desktop` `X-TerminalArg*` keys | Not installed; `TERMINAL=footclient` and per-app settings cover every case since `pcmanfm-qt` moved |
| — | Software: `dua-cli`, `expac`, `tldr`, `gum`, screen recording, `localsend`, `ffmpegthumbnailer`, `mise-bin`, `fcitx5` | `ncdu -x` is already aliased and covers the one thing `dua-cli` was wanted for; the rest are closed on taste or overlap |

### 9. Disk encryption — deferred to the next rebuild

Omarchy makes full-disk encryption mandatory and opens its security chapter with the reason:
*"Where losing a laptop can't lead to a security emergency."*

**Deferred 2026-09-07.** Retrofitting is a reinstall or a carefully planned, backup-verified
`btrfs send`/restore cycle, so it belongs to the next rebuild rather than to an in-place
migration. One prerequisite is already done: `mkinitcpio` uses the systemd initrd, so
`sd-encrypt` is reachable and `systemd-cryptenroll` can enrol a TPM or FIDO2 key rather than
requiring a passphrase at every boot.

It interacts with the still-absent off-machine backup (`TODO.md` §10 D), and the backup is the
one to build first.

### 20. `systemd-oomd` — declined for a reason specific to this machine

Their prerequisites are all met here and their reasoning is sound: cgroup v2, `MemoryAccounting`
on `app.slice`, and niri does the same placement Hyprland does — apps land in `app-niri-*.scope`,
the compositor does not. It is still wrong here, and only inspecting the live cgroup tree shows why.

Omarchy launches every app through `uwsm-app`, so each gets its own scope and oomd's granularity
is per-app: it takes the browser, the session survives. **This repo's single-foot-server design
collapses every terminal into one cgroup.** `app-niri-foot-*.scope` is a leaf holding the foot
server, the tmux server, every shell, the editor, the agent — and every process spawned from a
shell, so a runaway numeric job is *inside* it rather than beside it. An oomd kill takes all of
it. The kernel OOM killer kills the single highest-scoring process and leaves the desktop alive.

Both halves are affected: `ManagedOOMSwap` and `ManagedOOMMemoryPressure` draw from the same
candidate set. And the trigger is far more conservative than it looks — `SwapUsedLimit` requires
memory **and** swap both past 90%, roughly 70 G committed here, which is already unrecoverable.

What fits instead needs no daemon, and is the actual want for a polars or DuckDB run of
uncertain size:

```bash
systemd-run --user --scope -p MemoryMax=200M -- <job>
```

Revisit only if terminal jobs ever get independent scopes — not merely because memory pressure
is observed.

### 25. `fontconfig` — no defect existed, and finding 15 is withdrawn

Omarchy ships a fontconfig file and this repo ships none, which produced finding 15's claim that
`otf-font-awesome` was hijacking emoji codepoints. It was an artifact of the probe. `fc-match`
answers a **charset** query and models neither emoji presentation nor colour-font preference, so
it ranked Font Awesome above `Noto Color Emoji` for a question no renderer asks. The glyphs that
looked wrong are `Emoji_Presentation=No` codepoints, which Unicode requires to render as text
without `U+FE0F`. Both foot and GTK were always correct. Nothing was changed.

**Do not copy their fontconfig and do not write a replacement.** Tested: their weak `<accept>`
binding changes nothing here, and every form strong enough to change the ranking also makes bare
`sans-serif`/`serif`/`monospace` and CJK resolve to the emoji font.

To check emoji rendering, print the characters and look — including the `U+FE0F` form where the
codepoint is default-text. The general lesson is in `docs/system-notes.md` under "Verifying claims".

---

## Where this repo is ahead

So a later comparison does not regress toward Omarchy.

**`unblock-fuse` is correct where their `unmount-fuse` is not.** Same failure, three defects,
each already documented in `docs/architecture.md` as a tested finding: their `post` hook backgrounds a
subshell, which `systemd-suspend.service` (`Type=oneshot`, `KillMode=control-group`) SIGTERMs
mid-`sleep`, so the gvfs restart their comment promises almost certainly never happens; their
`pre` hook lazy-unmounts with `fusermount3 -uz`, which detaches the mountpoint but does **not**
release a task blocked in an unanswered FUSE request — writing `1` to the connection's `abort`
does; and their `post` hook calls `systemctl --user` while `user.slice` is still frozen, which
dies instantly with `Transport endpoint is not connected`. Their `sleep 5` is an attempt to wait
the freeze out by guess; `unblock-fuse` polls `FreezerState`. Theirs also unmounts every
`gvfsd-fuse` mount unconditionally, where ours samples twice two seconds apart and acts only on
connections with requests genuinely outstanding.

**Snapshots per transaction, not per update.** Omarchy snapshots inside `omarchy update`, so a
direct `pacman -Syu` gets none — which is why they need an `AbortOnFail` guard hook to forbid
one. `snap-pac` brackets every transaction here whatever invoked it. No guard needed and no way
to bypass it.

**`.pacnew` handling.** Their `docs/update-process.md` closes with it listed as still missing;
`config-drift` has reported them with changed-line counts and ages since 2026-09-04.

**The sleep inhibitor.** Both hold `systemd-inhibit --what=sleep:idle` across an update; theirs
escalates to `sudo -v`/`pkexec`. `sleep:idle` block inhibitors need no privilege, and `sysup`
already carries the note saying so.

**`config-drift` has no equivalent there** — nor does anything in their tree have its founding
rule, *assert on rendered behaviour, not on configuration*. That rule catches the regression
where an option is still read into a variable while the code using it has been replaced by a
hardcoded value, which is exactly what the tmux-power clock did. The status-bar check that
demonstrated it was removed by decision on 2026-09-08; the principle now lives in the checker's
header and still governs the rest — `.pacnew` counts changed lines, the root check compares
bytes, the symlink check resolves targets.

**Ours is richer, nothing to take:** `starship` (140 lines to 32 — and their `command_timeout=200`
against our `2000` costs nothing, since the prompt renders in 5–10 ms everywhere, including
inside the rclone FUSE mount), `git`, `foot` keybindings, `tmux` (466 to 106), `mimeapps.list`,
`snapper` (finding 22 — two configs to one; they ship no `home` config at all, which is the one doing the
load-bearing work here), `yt-dlp` (twelve substantive lines to their single package name), and
the seven `.desktop` launchers, which `desktop-file-validate` passes clean.

**Nothing to take, no overlap:** `btop` (`save_config_on_exit=false` here is correct — `true`
would rewrite through the symlink and dirty the repo every run), `environment.d` (four fcitx5
lines against our locale/session/podman), `wireplumber` (ours is an empty directory),
`modprobe.d` (disjoint — theirs disables USB autosuspend globally, ours blacklists `kvm_amd` and
`sp5100_tco`), `tmpfiles.d`, `systemd/user` (nine units each, no shared name), `sysctl`,
`pacman.conf` beyond finding 23, xdg user-dirs, and `lazygit` (theirs is empty).

**The `default/` folders that do not apply, so none was silently skipped:** `alacritty`,
`ghostty`, `hypr` (48 files — niri here), `limine` (GRUB here), `sddm` (`ly` here), `plymouth`,
`nautilus-python` (vifm), `chromium` (Firefox), `fonts` (their own icon font), `foot/` (a
screensaver profile; there is no screensaver here), `audio` (a Dell XPS speaker EQ keyed on
Dell's DMI SKU), `udev` (a Framework 16 keyboard), `omarchy/` and `uwsm/` (their own launcher and
session mechanism), `voxtype`/`tensaku` (software we do not have), `wayland-sessions`,
`xdg-terminal-exec`, and `themed/` (16 of its 17 entries are for software not installed here —
and `foot.ini.tpl` and `neovim.lua.tpl`, the two that are, are both worse than what this repo
already does).

---

## 13. Checked and clean — recorded so they are not re-checked

- **No daemon started twice.** niri's eight `spawn-at-startup` lines against the nine units in
  `systemd/user/` show no overlap; every daemon has exactly one instance at runtime.
- **plocate is not installed**, so the btrfs interaction their `install/config/locate.sh` fixes
  does not apply — but this layout would trigger both halves if it ever is:
  `PRUNE_BIND_MOUNTS="yes"` treats btrfs subvolume mounts as bind mounts and would exclude
  **`/home` entirely**, and unpruned `/.snapshots` plus `/home/.snapshots` would be walked once
  per snapshot, ~30 full traversals.
- **Snapper rollback does not restore `~/.config`** — true here as for them, but materially less
  dangerous: `~/.config` is symlinks into a git repo, so config history is in git.
- **`pam/swaylock` uses direct `auth` module lines rather than `include system-auth`**, so
  `pam_faillock` is not in the lock screen's stack and repeated empty-Enter attempts (the
  fingerprint trigger) cannot accumulate lockouts. Checked because Omarchy ships a script to
  *raise* the lockout limit; here the limit never applies.
- **`avahi` is installed** (a dependency of `libcups`, `passim`, `pipewire-pulse`, `tinysparql`)
  but **`nss-mdns` is not**, and `/etc/nsswitch.conf` has no `mdns` entry, so `.local` names do
  not resolve. Fine until a LAN device has to be reached by name.
- **No printing stack, confirmed intentional 2026-09-08.** There is no printer; one would be set
  up if that changes. `libcups` is present via GTK, so Print-to-PDF works and still produces A4
  from `LC_PAPER=de_DE`. A USB printer would not care about the mDNS gap above; a network
  printer advertising over mDNS would need it closed first.
- **Documentation drift (7)** — both originally cited discrepancies were already fixed by the
  time they were rechecked. Nothing to do.
- **Links open in Firefox, local HTML files open in `vimb` — by design, not a defect.**
  `mimeapps.list` maps `x-scheme-handler/http(s)` to Firefox and `text/html` to `vimb.desktop`.
  These are two independent mechanisms: changing `environment.d`'s `BROWSER` alone switches only
  the CLI half (`gh`, python's `webbrowser`, xdg-open's generic path), while GUI links and
  portals follow `mimeapps.list`. A future browser switch has to edit both, by hand — see 28.

## The invariant table (8) — the spec for a future test, not a backlog

Add tests for a concrete failure worth preventing, never to match a count. These four are the
decisions already argued elsewhere in the repo, each expressible as a one-line grep; they are
recorded so a future regression has somewhere to attach.

| Convention | State |
|---|---|
| `install.sh` never executes sudo | Holds — its two mentions are a comment and a printed instruction. No assertion |
| No user unit orders against `network-online.target` | Holds — current matches are comments. Unit verification exists but does not enforce this rule |
| Installed user-config links keep their intended mapping | **Asserted** since item B |
| `bash/tmux-theme` uses explicit background hex in the relevant slots, never `default` | Holds, **nothing asserts it** — the status-rendering check and its test were removed in `939f89d`, and they did not cover this rule anyway |

## Parked — each needs its own session

Design decisions, not config edits. Full design notes live in `TODO.md`, which is
self-contained and does not need the Omarchy checkout.

| # | Item | Where |
|---|---|---|
| C | Fold `check-skills` and the invariant table into one runner | `TODO.md` 10 C |
| D | Off-machine backup — restic, **not** `rclone sync`, which mirrors deletions and ransomware to the destination | `TODO.md` 10 D |
| 27 | An editor + agent tmux layout — the user rates this important | `TODO.md` 10 F |
| 30 | Their skill layering (a routing `SKILL.md` plus sibling topic guides) as the shape for `config-audit` | `agent-skills.md` |

Also found here but unrelated to Omarchy: 62 accumulated `git fsmonitor--daemon` processes
holding 326 MB, noticed while measuring the oomd cgroup. Resolved 2026-09-09 by turning
`core.fsmonitor` off — the count was one daemon per repository, not a leak, and 59 of them
watched plugin clones. See `docs/architecture.md`; `TODO.md` §11 is closed and removed.

---

## Traps this comparison produced

Both are instances of `docs/system-notes.md`'s "a probe that answers confidently may be answering a
different question", which is where the general rule lives.

- **`fc-match` withdrew a whole finding** (25). It answers a charset query and nothing else.
- **`xdg-settings set` rewrites `mimeapps.list`.** The control run for finding 28 clobbered
  `text/html=vimb.desktop` and stripped trailing semicolons from four lines — and
  `~/.config/mimeapps.list` is a symlink into this repo, so the write landed in the tracked file.
  Restored from backup and verified identical to HEAD. Test this against a throwaway
  `XDG_CONFIG_HOME`/`XDG_DATA_HOME`.

One more worth keeping, from finding 19: **"not a simple fix" was wrong, and the tell was in its
own verdict.** `pcmanfm-qt` was filed as hard because `terminals.list` knows `foot` and not
`footclient`, so an unlisted name might get an `-e` that `footclient` rejects. The note's own
conclusion was "probably work — unsupported and untested", and the answer to *untested* is to
test it. One word, three lines, verified in under a minute.
