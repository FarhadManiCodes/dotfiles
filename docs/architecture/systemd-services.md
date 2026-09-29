# systemd user services & failure notification

Units live in `systemd/user/`, symlinked by `install.sh`, enabled from an **explicit
list** (a glob can't enable the `rclone@` template, and never enables the instances
actually mounted).

Failures are surfaced by `OnFailure=notify-failure@%n.service` → `bash/service-failed-notify`,
which raises a mako notification *and* appends to
`~/.local/state/service-failures/failures.log` — a popup is useless if nobody is at the
machine. `notify-failure@.service` has no `OnFailure` of its own, and the script always
exits 0, so a failing notifier can't loop. Check remotely with `systemctl --user --failed`.

## wob: socket activation in the graphical session

The installed wob package supplies `wob.socket` and `wob.service`; tracked overrides
in `systemd/user/wob.socket.d/` and `wob.service.d/` keep the existing
`$XDG_RUNTIME_DIR/wobpipe` interface. Only `wob.socket` is enabled, under
`graphical-session.target` instead of the package's `sockets.target`. Both units are
ordered after and part of the graphical session, so they stop with it. The socket
inherits `SocketMode=0600`, `RemoveOnStop=yes` and `FlushPending=yes` from the package.

The first update from `wob-control` starts `/usr/bin/wob` with socket input; systemd
holds the FIFO open, so individual writers closing it do not end the renderer.
One wob process stays resident after first use. Its standard configuration lookup
finds the live `~/.config/wob/wob.ini` symlink; keybindings, styles and the separate
Niri `wob-control led-sync` startup command are unchanged. Both units report failures,
and the service restarts after 5 s on failure. Niri no longer starts a shell and
`tail -f` pipeline. The installer already maps drop-ins; the only enable-list addition
is `wob.socket`.

Live migration verified 2026-09-29 without restarting Niri: the socket was listening
with the service inactive before the first write; the write started exactly one wob
process. Real volume, brightness, speaker-mute and microphone-mute controls worked,
with LED state checked and original control settings restored. Narrow screenshots
confirmed the same 400×24 bar at the top, 50 px margin, blue/yellow/red/green styles,
and disappearance after the 1000 ms timeout. Successive writes after 2 s idle periods
and 100 rapid writes, each closing its writer, kept the same PID. SIGKILL produced a
failure-log entry and a mako notification, restarted the renderer after 5 s, and a
subsequent write rendered successfully.

Idle PSS snapshots used the `Pss:` line of each process's `/proc/<pid>/smaps_rollup`
after showing `50 volume` and letting the bar disappear. Immediately before switching,
the old scope held shell PID 1698 (587 KiB), tail PID 1732 (267 KiB), and wob PID 1733
(334 KiB): three processes, 1188 KiB total. After recovery, the service cgroup held only
wob PID 209111 (326 KiB): one process, an observed reduction of 862 KiB. The removed
helpers accounted for 854 KiB of that snapshot. PSS varies with shared mappings;
these totals cover the renderer chain, excluding changes to the existing user manager.

Bash syntax, ShellCheck, Niri validation and verification of the merged package units
and overrides passed. Effective paths, FIFO mode, ordering and restart policy were
checked after reload. `config-drift` reported zero items needing attention and three
access exclusions (two unreadable snapper configs and an incomplete root-only directory
scan). The full repository test suites were not run for this configuration change.

Fresh-login behavior remains untested until the next natural graphical login.
Then check that the socket is listening and the service inactive before the first
OSD update, and that the first volume or brightness key starts the renderer.

## Sandboxing: the notifiers, one pattern

**`battery-watch.service` was the first sandboxed unit** (2026-09-18) and the pattern for
the rest; it was merged into `power-notify` on 2026-09-29 (below), whose unit has the same profile plus
`AF_NETLINK` for `udevadm`. Its profile came from a measured inventory, not a template: `/proc/<pid>/fd`
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

**`batsignal -o` was not usable to test this** (batsignal is gone since 2026-09-29). It looked like the obvious harness and wasn't:
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
`/proc/net/netlink` instead), and `is-active` isn't evidence for this unit — it ran six
processes, so count `cgroup.procs`. **Since 2026-09-29 it is `AF_UNIX` only**: one
`dbus-monitor` carries iwd, systemd-networkd's wired `CarrierState` and logind's
`PrepareForSleep`, so `ip monitor` and its netlink socket are gone (7 processes → 2). **The
same day it became a C program** and `AF_NETLINK` came back, now as its only source.

**`mic-notify` and `power-notify` completed the set**, both with trigger-level proof (a
real capture stream, a real charger unplug/replug). `AF_UNIX` alone for
`battery-watch`/`mic-notify`, plus `AF_NETLINK` for `power-notify` (`udevadm monitor`;
`net-notify` needed it too until 2026-09-29). Scores 3.2/3.3. `PrivateDevices=yes` is
safe even for process substitution — systemd's private `/dev` still provides
`/dev/fd -> /proc/self/fd`, though `man systemd.exec` doesn't say so.

**`power-notify` absorbed `battery-watch` (2026-09-29).** Measured with a udev recorder
on a real unplug, suspend, cable re-seat and charge to the limit: plug/unplug and `BAT0`
status changes are events, including `Not charging` + `CAPACITY=81` when TLP stops at
its limit; the battery level is not (40 min on battery, zero events), and resume sends
none either. batsignal's `-m 300` turned out to be a multiplier (wait = (level − next
alert) × 300 s, i.e. it assumes ≤ 9 W): at 81% it waited 4.25 h, while full CPU load on
battery measures 35.4 W and empties it in 1.8 h. `power-notify` now reads the level only
while unplugged, waiting the time to the next alert at an assumed 30 W (+1%), capped at
20 min because timers don't count suspend. The same test found the old charging-complete
rule firing at 64% when the cable was re-seated (BAT0 says `Not charging` for a moment);
"complete" now also requires the capacity to be at `charge_control_end_threshold` − 1.

**`mic-notify` became a C program watching the kernel (2026-09-29).** A recording
opens an ALSA capture device (`/dev/snd/pcmC2D0c` is the built-in mic, `pcmC1D0c` the
headset jack), and inotify reports the open and the close; `/proc/asound/card*/pcm*c/sub*/status`
says whether each is open. A speaker-monitor recording opens only a playback device and
never counts; Bluetooth mics bypass `/dev/snd` and are not seen (accepted). PipeWire
keeps an idle device open 5 s by default, so "released" came ~5 s late;
`wireplumber/wireplumber.conf.d/51-mic-suspend.conf` closes idle inputs after 1 s. When
WirePlumber starts it probes each capture device (~10 open/close pairs in ~60 ms), so
the program checks only after 300 ms without events. "Active" shows ~0.3 s after the
open and "released" ~1.3 s after the app stops (measured). The program (the
`mic-notify` submodule, developed in `~/projects/mic-notify`, built by `install.sh`) is
freestanding C with no libc: one process, 16 KB, against 3.3 MB for `pactl subscribe` +
bash. Its sandbox keeps `PrivateDevices=yes` and binds `/dev/snd` back in read-only
(score 3.2); the bound nodes remain openable, since a user manager doesn't enforce the
device policy. A SIGTERM from `pkill` is a clean stop to systemd, so test the failure
path with `systemctl --user kill -s SEGV`, not `pkill`.

**`net-notify` became a C program watching the kernel (2026-09-29).** One route-netlink
socket reports every link change: the interface's UP flag cleared is "WiFi turned off",
the operational state UP is "connected" (iwd runs wifi in dormant mode, so UP comes only
after the WPA handshake, when iwd says connected), anything else is a drop. The network
name is one nl80211 query after a connect. Suspend needs no logind: `CLOCK_BOOTTIME`
counts time asleep and `CLOCK_MONOTONIC` does not, and the kernel drops wifi inside its
suspend step, so the drop is read only after waking, when the clock gap has already
grown; the 10 s after-wake rule is kept on that basis. All of this was recorded with
`ip monitor link` and `iw event` across a real suspend, wifi off/on and a manual
disconnect before the code was written. Only interfaces with a `device` in sysfs count,
so container and VPN links are ignored. Failed reconnects no longer repeat
"disconnected": the link never reaches UP, so there is nothing to report until it does.
The program (the `net-notify` submodule, developed in `~/projects/net-notify`, built by
`install.sh`) is freestanding C: one process, 20-24 KB, no D-Bus, against 1.16 MB for bash +
`dbus-monitor` and an `iwctl` + `awk` pair on every connect.

## Two things that shipped broken

**The silent-exit bug.** If a monitor died, the pipeline reached EOF, the script fell off
the end with status 0, and systemd read it as a clean finish — no restart, no
`OnFailure=`. **Fixed 2026-09-18** in all three monitor scripts (`bash/mic-notify`,
`bash/net-notify`, `bash/power-notify`): each now ends in `exit 1`, since none has a
normal exit path. Verified by killing `pactl`/`udevadm` and watching the units report
`Failed with result 'exit-code'`, trigger `OnFailure=`, and restart. `Restart=on-failure`
was always correct; the bug was the exit status. `net-notify` still had a hole: its
ethernet watcher ran in the background, and killing its `ip monitor` left the unit
"running" with ethernet notices gone. Since 2026-09-29 it has a single listener, so
there is no second half left to die.

**`ProtectSystem=strict` mounts `$XDG_RUNTIME_DIR` read-only, and `mic-notify` needed
`ReadWritePaths=%t`** (until it stopped using libpulse, 2026-09-29). Shipped broken 2026-09-18, caught only on the next reboot:
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
