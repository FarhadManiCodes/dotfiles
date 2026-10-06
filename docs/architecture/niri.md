# Window manager (Niri)

- `niri/niri-session-isolated` and `niri/niri-isolated.desktop` — separate Ly session,
  root-owned copies installed by `install-root.sh`. Application defaults remain in
  `environment.d`; only named login metadata is forwarded. Implementation and remaining
  live checks: [isolated session](../../niri/isolated-session.md).
- `niri/config.kdl` — keybindings, workspaces, window rules
- `bash/cliphist-store-guard` — clipboard-history capture with a three-second deadline; see [Clipboard history](#clipboard-history).
- Shift+Print runs `flameshot gui`: select a region and annotate it in place on the dimmed
  screen. Flameshot works on Niri without a wrapper. `flameshot gui` starts a background
  `flameshot` daemon (about 40 MB) that stays alive and **owns the clipboard**, so the copied
  image survives the editor closing (verified 2026-10-04 with `wl-paste --type image/png`
  after the window was gone); killing the daemon empties the clipboard.
  The UI colour is Catppuccin blue, matching niri's focus border, set once with
  `flameshot config -m '#89b4fa'` (it writes `uiColor` to `~/.config/flameshot/flameshot.ini`).
  That file is deliberately **not tracked**: Flameshot also writes `drawColor`, the last
  colour you drew with, on every use, so a tracked copy would be dirty after almost any
  annotation. Ctrl+S saves straight to `~/Pictures/Screenshots/` with no dialog, named
  `annotated_%Y-%m-%d_%H-%M` (`flameshot config -f '<pattern>'`, plus `savePath` and
  `savePathFixed=true` in the ini; Flameshot appends `_1` to a name already taken, tested, so
  two saves in one minute do not overwrite), so edited captures sort beside niri's own
  `Screenshot from …` files but are told apart. The help card stays on for now
  (`flameshot config -s false` hides it), and the daemon starts on first use rather than
  at login.
- `mako/config` — notification daemon
- `fuzzel/fuzzel.ini` — app launcher
- `swaylock/config` — lock screen. `daemonize` is **required** (swayidle runs with `-w`,
  which blocks until the lock command exits; without it the power-off/suspend timeouts
  never fire). `ignore-empty-password` is off so an empty Enter reaches PAM and activates
  the fingerprint reader. swayidle locks via `bash/lock-once`, a no-op when a live
  swaylock already exists, so a repeated `before-sleep` can't queue locks. Fails safe:
  nothing short of a confirmed live swaylock of our own stops it locking, since niri has
  no lock-state query and swaylock never sets logind's `LockedHint`.
- `pam/swaylock` → `/etc/pam.d/swaylock` (copied by `install-root.sh`, root-owned) —
  fingerprint + password unlock. Order: `pam_unix` (typed password unlocks instantly) →
  `pam_fprintd` (empty Enter then swipe) → `pam_deny`. swaylock can't auto-switch modes;
  both methods are always available.
- `system-sleep/` → `/usr/lib/systemd/system-sleep/` (installed 0755 by
  `install-root.sh`, root-owned). Two hooks here; the other file there, `tlp`, belongs to
  the `tlp` package — don't track that one.

## Sleep hooks

**`fprintd-resume`** submits an asynchronous conditional restart of an active fprintd daemon on `post`, recovering a reader left busy by an interrupted scan. A three-second stop-timeout drop-in bounds a stuck stop. The existing Swaylock PAM stack stays unchanged. Hardware verification is pending; evidence, rollout, checks and rollback are in [system notes](../system-notes.md#fingerprint-recovery-after-resume-2026-10-05).

**`unblock-fuse`** releases tasks wedged in an unanswered FUSE request. This is a
**correctness fix for a failure mode that already cost a full night**, not a nicety. A
task waiting on a FUSE reply is uninterruptible — the freezer can't freeze it and SIGKILL
doesn't reach it — so suspend aborts with `EBUSY` and, with the lid shut, logind retries
every ~100s forever. On 2026-09-02 one stray `du` on an rclone mount produced **460
suspend attempts (456 aborted, 4 succeeded)** plus 1831 wifi disconnects — every retry
also re-ran the since-removed `fix-wifi.sh` and swayidle's `before-sleep`. `pre` samples
twice 2s apart, so a merely-slow mount is left alone, and only aborts connections with
requests actually outstanding; `post` restarts the `rclone@` units, but only when `pre`
acted. Verified on 7.2.2: writing `1` to a connection's `abort` releases a waiter SIGKILL
couldn't.

`fix-wifi.sh` used to unload/reload `ath11k_pci` around suspend because the Qualcomm
QCNFA765 wouldn't reliably re-associate on resume. **Removed 2026-09-04**: the kernel
fixed it. Measured on 7.2.2 with the hook disabled — nine resumes, including one 8.7
hours overnight — wifi came back every time, and faster (1s vs 3s, since the link
survives instead of being torn down). Keeping it wasn't neutral: it ran on *failed*
suspend attempts too, so on 2026-09-02 it cycled the module 912 times and was the
amplifier that turned one wedged `du` into an all-night notification storm. Recover with
`git show 73716b9:system-sleep/fix-wifi.sh` if a resume ever comes back without wifi, but
measure first: the fix is `modprobe -r ath11k_pci && modprobe ath11k_pci`.

**A sleep hook can't talk to the user manager directly, and fails silently if it tries.**
Post hooks run while `user.slice` is still frozen, so `systemctl --user --machine=…` dies
at once with `Transport endpoint is not connected` — fast, so backgrounding alone doesn't
help, and `systemd-suspend.service` is `Type=oneshot` with `KillMode=control-group`, so a
child left behind is SIGTERMed when the hook returns. `unblock-fuse` hands off via
`systemd-run --no-block`, whose transient unit outlives the cgroup and polls
`FreezerState` until the thaw. Never discard stderr here.

A third hook, `restart-swayidle`, was **removed 2026-09-03**: it had this exact bug and
had never once run — across 1002 resumes and 31 boots of journal history, every swayidle
start was a boot, never a restart. Nothing regressed, since the lock loop it guarded
against was already fixed by `swayidle.service` locking directly rather than through
`loginctl lock-session`. Recover with `git show 45d7536:system-sleep/restart-swayidle` —
but repairing it would switch on behaviour absent for a thousand resumes, not restore any.

Note the lid only suspends on battery — `HandleLidSwitchExternalPower=lock` means closing
it on AC just locks. Reproducing anything here requires being unplugged.

## Clipboard history

Niri starts `wl-paste --watch cliphist-store-guard`. The helper stages each copy in a unique mode-0600 file under `$XDG_RUNTIME_DIR`, with a three-second deadline for reading stdin and a 5,000,000-byte payload limit matching cliphist 0.7.0. Capture reads at most 5,000,001 bytes: the extra byte detects oversized streams, which are discarded without calling cliphist or waiting for the owner to close. A copy exactly at the limit still needs EOF before the deadline. Only a completed read within the size limit reaches `cliphist store`; the database operation itself is not timed out. Sensitive events are skipped and clear events retain cliphist's existing behavior. Failed reads and oversized copies are dropped and diagnosed on stderr without clipboard contents or desktop notifications. Temporary files are removed on exit and catchable termination.

A legitimate transfer exceeding three seconds is omitted from history without changing the current clipboard. The existing helper installation loop supplies the user-level symlink. Startup changes take effect at login; a config reload does not replace the running watcher. Immediate activation requires identifying its exact command and starting one replacement through Niri. The guarded watcher was activated on 2026-10-05; the audit records verification.

Rollback restores `wl-paste --watch cliphist store` in the startup configuration, stops only the verified guarded watcher, and launches `/usr/bin/wl-paste --watch cliphist store` through `niri msg action spawn --`. No history database deletion or clipboard clearing is needed. Remove the helper's symlink if reverting its tracked source, to avoid leaving a dangling link.

## Power menu shutdown protection

Confirmed Shutdown and Reboot in `bash/powermenu` acquire blocking `sleep:idle:handle-lid-switch` inhibitors before stopping `rclone@*` through the user manager. The inhibited child requests `systemctl poweroff` or `systemctl reboot` only after teardown succeeds. Protection lasts from inhibitor acquisition through acceptance of that request; successful submission does not prove that shutdown has completed. The locks are released when the child exits.

If acquiring the inhibitors, stopping rclone, or submitting the final request fails, the menu cancels the operation, preserves its nonzero status and diagnostic, and reports a critical notification. A notification failure does not replace the operation's exit status. Teardown is not rolled back if the final request fails; rclone mounts may already be stopped. Logout, Lock, Suspend, and the confirmation dialogs retain their existing behavior. `~/.local/bin/powermenu` symlinks into this checkout, so editing the script activates the change before branch merge.

Validation uses isolated command substitutes in `tests/test_powermenu.py`; no test stops real mounts or requests a power action. The earlier harmless live inhibitor probe succeeded without root. **Pending hardware verification:** on battery, confirm Shutdown and immediately close the lid, then verify the laptop completes shutdown rather than suspending. Closing the lid on AC only locks and cannot exercise the battery lid-suspend path.
