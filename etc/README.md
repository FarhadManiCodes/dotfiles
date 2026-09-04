# `etc/` — root-owned config, mirrored path-for-path

Everything here installs to the same path below `/etc`, copied (never symlinked)
by `install-root.sh`, `0644 root:root`.

These are files **owned by no package** — hand-written at some point and then
forgotten. That is the whole reason this directory exists: an untracked file in
`/etc` is invisible until a rebuild silently comes up without it. The same trap
already caught `fix-wifi.sh`, `sysctl/99-performance.conf`, the zsh plugin list
and `zram/zram-generator.conf` before this sweep found the rest.

Found by diffing `find /etc -type f` against every path in `pacman -Ql`
(2026-09-04): 183 unowned files, of which these were the hand-written ones.

## The one exception: `nftables.conf`

`/etc/nftables.conf` **is** package-owned (`nftables 1:1.1.7-3`) and modified —
it holds the actual firewall ruleset. The sweep above cannot see files like this,
because it tests ownership rather than content; `pacman -Qkk` is what finds them:

```bash
pacman -Qkk 2>&1 | grep "backup file"      # every modified package config
```

Tracking it makes this repo the source of truth, so a future `nftables` upgrade
shipping a `.pacnew` cannot quietly replace the ruleset. The ruleset itself is
default-drop with nothing listening, which is why it is safe in a public repo:
it discloses only that the machine runs a restrictive firewall and serves nothing.

## What each file is for

| Path | Why |
|---|---|
| `nftables.conf` | The firewall. Default-drop input, `forward` accept so container networking works. No SSH rule — no sshd. |
| `iwd/main.conf` | `EnableNetworkConfiguration=true` + `NameResolvingService=systemd`. **Without it iwd does not configure networking at all.** Credentials live in `/var/lib/iwd/*.psk` and are deliberately not here. |
| `systemd/system/iwd.service.d/override.conf` | 2s `ExecStartPre` buffer for the hardware to wake, plus `Restart=on-failure`. |
| `systemd/system/iwd.service.d/nowait.conf` | Orders iwd after `dbus-broker` and clears the packaged `Before=`/`Wants=`. |
| `systemd/system/nftables.service.d/override.conf` | `RemainAfterExit=yes`, so a `Type=oneshot` firewall reads as active rather than dead once it has loaded. |
| `systemd/journald.conf.d/size.conf` | Caps the journal at 200M on disk, 50M in RAM. |
| `systemd/network/20-wired.network` | DHCP on `e*` with `RouteMetric=10`, so wired outranks wifi when both are up. |
| `systemd/system/ly@.service.d/override.conf` | `SuccessExitStatus=15`, so ly exiting via SIGTERM is not logged as a failure. |
| `modprobe.d/kvm.conf` | `blacklist kvm_amd` — virtualisation off. |
| `modprobe.d/disable-sp5100-watchdog.conf` | `blacklist sp5100_tco` — the AMD watchdog, which fires spuriously on this platform. |
| `tmpfiles.d/polkit-silence.conf` | Creates `/run/polkit-1/rules.d` so polkit stops warning it is missing. |
| `snapper/configs/root` | Snapshots of `/` are pacman pre/post pairs only — `TIMELINE_CREATE="no"`, `NUMBER_LIMIT=10`. Its `TIMELINE_LIMIT_*` values are **inert**: with no timeline snapshots taken, nothing exists for them to prune. |
| `snapper/configs/home` | The one that matters. Hourly timeline snapshots of `/home`, retention `HOURLY=5 DAILY=7 WEEKLY=4 MONTHLY=4` — about four months, raised from one week on 2026-09-04. This is the only thing snapshotting `~`. |
| `environment` | `QT_QPA_PLATFORM=wayland` — without it Qt apps fall back to XWayland. |
| `conf.d/snapper` | `SNAPPER_CONFIGS="home root"`. One line, and it is what makes `snapper-timeline.timer` and `snapper-cleanup.timer` act on both configs rather than neither. |
| `mkinitcpio.conf` | `MODULES=(btrfs)` and `BINARIES=(/usr/bin/btrfs)` — the latter puts the btrfs tool in the initramfs, which is what lets a snapshot be rolled back from the emergency shell when root will not mount. Plus the hook order. |
| `udev/rules.d/51-android.rules` | USB access to Samsung devices (`04e8`). **`MODE="0666"` is world read/write** — the conventional form is `0664` with a group. Harmless on a single-user machine, but it is broader than it needs to be. |

## Not everything in `/etc` belongs here

Tracking is for files that are **hand-written and safe to copy onto any machine**. A file can
be both customised and a bad thing to track:

**`/etc/fstab` — deliberately not tracked, decided 2026-09-04.** Every line mounts by UUID, and
those UUIDs belong to this specific NVMe. Copying this file onto a rebuilt machine would point
every mount at a filesystem that does not exist there: it would not boot, and `install-root.sh`
would have done it silently. The layout it encodes — which subvolumes exist, where each mounts,
and why `@docker`/`@pkg`/`@postgres` are separate — is already in CLAUDE.md, which is the part
worth keeping. The file itself is a record of one disk, not a config.

The same test applies to anything hardware-specific: if installing it on different hardware
would break that machine, document the decision instead of tracking the file.

## Deliberately not tracked

- **`/etc/X11/xorg.conf.d/00-keyboard.conf`** — generated by `systemd-localed`, and
  says so in its own header. Tracking generated state invites it to drift against
  the tool that owns it. Reproduce with:
  ```bash
  localectl set-x11-keymap us pc105 "" terminate:ctrl_alt_bksp
  ```
- Generated or machine-local state: `ls-R`, `updmap.cfg`, `ly/save.txt`,
  `printcap`, `mkinitcpio.d/linux.preset`.

## `SYNC_ACL` — why `/home/.snapshots` reads as empty

`snapper/configs/home` sets `ALLOW_USERS="farhad"` but `SYNC_ACL="no"`, so those users are
never applied as ACLs on the `.snapshots` directory. The permission is **declared and not
granted**: the directory stays `root:users`, `farhad` is not in `users`, and `ls` prints
nothing rather than refusing.

That is not cosmetic. On 2026-09-03 it produced an apparently empty directory, which read as
"600 timeline runs, zero snapshots" and nearly led to `snapper-timeline.timer` being disabled
— the only thing snapshotting `~`.

**`SYNC_ACL` stays `"no"`, decided 2026-09-04.** Setting it to `"yes"` would make
`snapper -c home list` work without sudo and remove the trap at its source, but a snapshot
directory holds complete historical copies of `/home`, including files whose permissions have
been tightened since. Requiring sudo keeps reading them a deliberate act rather than something
any process running as this user can walk into. The mismatch between `ALLOW_USERS` and
`SYNC_ACL` is therefore intentional and should not be "fixed".

**Always use `sudo snapper -c home list`.** Never infer from `ls /home/.snapshots`: it prints
nothing on a permission failure, which is indistinguishable from an empty directory.
