# systemd user services & failure notification

Units live in `systemd/user/`, symlinked by `install.sh`, enabled from an **explicit
list** (a glob can't enable the `rclone@` template, and never enables the instances
actually mounted).

Failures are surfaced by `OnFailure=notify-failure@%n.service` → `bash/service-failed-notify`,
which raises a mako notification *and* appends to
`~/.local/state/service-failures/failures.log` — a popup is useless if nobody is at the
machine. `notify-failure@.service` has no `OnFailure` of its own, and the script always
exits 0, so a failing notifier can't loop. Check remotely with `systemctl --user --failed`.

## Sandboxing: four notifiers, one pattern

**`battery-watch.service` is the first sandboxed unit** (2026-09-18) and the pattern for
the rest. Its profile came from a measured inventory, not a template: `/proc/<pid>/fd`
showed only `/dev/null`, the journald sockets and one session D-Bus socket — no network,
no disk writes. Denying everything else took it from 9.4 UNSAFE to 3.2 OK on
`systemd-analyze security --user`.

Two directives are load-bearing, not boilerplate: `RestrictAddressFamilies=AF_UNIX` must
keep `AF_UNIX` (the whole notification path is the session bus — an empty set silences
the service without failing it, the worst outcome for a battery warning), and
`SystemCallFilter=@system-service` must stay permissive enough for `fork`/`execve` since
`-d 5` shells out to `notify-send`. `CapabilityBoundingSet=` is deliberately absent — a
user service has no effective capabilities and `NoNewPrivileges` blocks acquiring any,
the same reasoning `containers/pg.container` uses for `DropCapability`.

**Do not use `batsignal -o` to test this.** It looks like the obvious harness and isn't:
it hangs instead of exiting, with or without the sandbox (verified by A/B), and rejects
`-d` above `-c` outright. Test the *mechanism* instead: a transient `systemd-run --user`
carrying the same properties running `sh -c 'notify-send …'` proves fork+exec+D-Bus
survive, `makoctl list` confirms arrival, and a negative control (a write to `$HOME`,
which must fail `Read-only file system`) proves the probe can detect anything at all.

**`net-notify.service` followed**, with `RestrictAddressFamilies=AF_UNIX AF_NETLINK` —
`AF_NETLINK` is what `ip monitor link` needs for `eth_monitor`, mandatory since `enp1s0f0`
is a real device here. Losing `AF_UNIX` kills every notification; losing `AF_NETLINK`
kills only the ethernet half, silently, while wifi keeps working (proven by A/B). Score
9.4 → 3.3. Two probe traps: `ss -f netlink -apn | grep pid=<pid>` shows nothing for a
process that demonstrably holds netlink sockets (match the fd inode against
`/proc/net/netlink` instead), and `is-active` isn't evidence for this unit — it runs six
processes, so count `cgroup.procs`.

**`mic-notify` and `power-notify` completed the set**, both with trigger-level proof (a
real capture stream, a real charger unplug/replug). `AF_UNIX` alone for
`battery-watch`/`mic-notify`, plus `AF_NETLINK` for `net-notify`/`power-notify`
(`udevadm monitor`). Scores 3.2/3.3. `power-notify`'s charging-complete branch is
untested (TLP's 80% cap means `BAT0` never reads that state). `PrivateDevices=yes` is
safe even for process substitution — systemd's private `/dev` still provides
`/dev/fd -> /proc/self/fd`, though `man systemd.exec` doesn't say so.

## Two things that shipped broken

**The silent-exit bug.** If a monitor died, the pipeline reached EOF, the script fell off
the end with status 0, and systemd read it as a clean finish — no restart, no
`OnFailure=`. **Fixed 2026-09-18** in all three monitor scripts (`bash/mic-notify`,
`bash/net-notify`, `bash/power-notify`): each now ends in `exit 1`, since none has a
normal exit path. Verified by killing `pactl`/`udevadm` and watching the units report
`Failed with result 'exit-code'`, trigger `OnFailure=`, and restart. `Restart=on-failure`
was always correct; the bug was the exit status.

**`ProtectSystem=strict` mounts `$XDG_RUNTIME_DIR` read-only, and `mic-notify` needed
`ReadWritePaths=%t`.** Shipped broken 2026-09-18, caught only on the next reboot:
`libpulse` creates/validates `/run/user/1000/pulse` before connecting, so `pactl
subscribe` died on the `mkdir` (D-Bus itself is unaffected — connecting to an existing
socket works read-only). Invisible for three reasons: the script's own
`2>/dev/null` swallowed the error, the exit-0 bug above meant no restart or report, and
the original test ran hours into a boot where `/run/user/1000/pulse` already existed, so
the `mkdir` was never exercised. Test a runtime-directory dependency by asking "does it
work when the directory doesn't exist yet", not "does it work now". (Don't test this by
deleting `/run/user/1000/pulse` directly — it holds pipewire-pulse's live socket; recreate
with `systemctl --user restart pipewire-pulse.socket`, not by restarting the service.)

## What stays unsandboxed

**`swayidle` is deliberately NOT sandboxed.** It spawns `swaylock`, which would inherit
the sandbox, and `/etc/pam.d/swaylock`'s `pam_unix.so` shells out to the setuid-root
`/usr/bin/unix_chkpwd` for a non-root caller — `NoNewPrivileges=yes` blocks setuid
elevation, so hardening this unit would likely break password unlock. Don't "complete the
set" here. (`brightnessctl` already goes through logind over D-Bus rather than a sysfs
write — `/sys/class/backlight/amdgpu_bl1/brightness` is root-owned and unwritable by this
user — so `ProtectSystem=strict` is not what would break if this were sandboxed.)

## Never order a user unit against `network-online.target`

It doesn't exist in the user manager (`LoadState` reports `not-found`), and a user unit
can't order itself against a system unit, so `After=`/`Wants=network-online.target` is
inert on *every* machine, not just one where `systemd-networkd-wait-online` is masked.
Both `rclone@.service` and the since-removed `study-library-sync.service` carried it
until 2026-09-04. Nothing catches this — a missing `Wants=` is legal and silent by
design, so the only remedy is not writing the line.

The mechanism that actually works for a unit starting before the network is `Restart=`
plus a `StartLimitIntervalSec`/`StartLimitBurst` window wide enough for the backoff to
fit. Measured on the 2026-09-04 boot where wifi took 103s: `rclone@gdrive` failed its
first attempt on DNS and the retry had the mount serving 4.6s after the network became
usable — as early as any ordering could achieve, since there was no DNS before that.
Shortening the doomed first attempt (a smaller `--contimeout`) was considered and
rejected on the same evidence: it fails sooner without mounting sooner, and risks
spurious failure on a genuinely slow network.

Building the missing dependency instead — a user-level waiter polling until the system is
online — is the trap, not the fix. That's exactly what
`podman-user-wait-network-online.service` did, and why `pg.container` needs
`DefaultDependencies=false` (see [containers.md](containers.md)).
