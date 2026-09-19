# Window manager (Niri)

- `niri/niri-session-isolated` and `niri/niri-isolated.desktop` — separate Ly session,
  root-owned copies installed by `install-root.sh`. Application defaults remain in
  `environment.d`; only named login metadata is forwarded. Implementation and remaining
  live checks: [isolated session](../../niri/isolated-session.md).
- `niri/config.kdl` — keybindings, workspaces, window rules
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
  `install-root.sh`, root-owned). One hook here; the other file there, `tlp`, belongs to
  the `tlp` package — don't track that one.

## Sleep hooks

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
