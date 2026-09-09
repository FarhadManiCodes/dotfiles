# `etc/` — root-owned config, mirrored path-for-path

Everything here installs to the same path below `/etc`, copied (never symlinked)
by `install-root.sh`, `0644 root:root`.

This directory began with files **owned by no package** — hand-written at some
point and then forgotten. It also preserves selected modified package-owned configs. That is the whole reason this directory exists: an untracked file in
`/etc` is invisible until a rebuild silently comes up without it. The same trap
already caught `fix-wifi.sh`, `sysctl/99-performance.conf`, the zsh plugin list
and `zram/zram-generator.conf` before this sweep found the rest.

Found by diffing `find /etc -type f` against every path in `pacman -Ql`
(2026-09-04): 183 unowned files, of which these were the hand-written ones.

## Both sweeps now run automatically

Coverage is explicit: a failed pacman inventory is not compared. A partial `/etc`
traversal can establish additions but not removals. The modified-backup inventory
also reports additions only, because unreadable files may be absent from its output.
The checker reports differing root copies without using mtimes to recommend which
one to overwrite. User-unit verification is batched in user-manager scope.

`bash/config-drift` runs them after every `sysup` and diffs each against a tracked baseline:
`etc/unowned.txt` (44 paths) and `etc/modified.txt` (24). A path not in its baseline is a
finding; accepting one means adding the line in a commit that says why. The counts move on their
own — unowned was 183 on 2026-09-04 and 172 two days later — so only the diff carries
information.

The 131 files under `/etc/ca-certificates/{extracted,trust-source}/` are excluded rather than
listed: `update-ca-trust` rewrites them wholesale, and a baseline that churns on every
`ca-certificates` update is a warning nobody reads.

## Package-owned configurations

`/etc/nftables.conf` **is** package-owned (`nftables 1:1.1.7-3`) and modified —
it holds the actual firewall ruleset. The sweep above cannot see files like this,
because it tests ownership rather than content. Two probes find them, and
**neither is a superset of the other** (measured 2026-09-06):

```bash
pacman -Qii | grep -oE '/[^ ]+ \[modified\]'   # 40 ms, content-compared, 22 files
sudo pacman -Qkk | grep "backup file"          # 19 s observed; includes metadata checks; root avoids unreadable files
```

`-Qii` is the default for backup-file content changes; it was about 475x faster
in the recorded sweep. It is blind to
files it cannot **read** — `/etc/shadow` and `/etc/gshadow` never appear, reported
as unmodified rather than as unknown. `-Qkk` sees those, but flags mtime-only
mismatches over identical content (`/etc/systemd/logind.conf`), and run without
root it degrades to `failed to calculate SHA256 checksum`, which means unreadable
and not altered.

Tracking it makes this repo the source of truth, so a future `nftables` upgrade
shipping a `.pacnew` cannot quietly replace the ruleset. The ruleset itself is
default-drop with nothing listening, which is why it is safe in a public repo:
it discloses only that the machine runs a restrictive firewall and serves nothing.

`/etc/pacman.conf` joined this class on 2026-09-05, and is a much smaller case:
it was **byte-identical to the shipped default** until then (verified by diffing
against `etc/pacman.conf` extracted from `pacman-7.1.0.r9.g54d9411-2-x86_64.pkg.tar.zst`;
`pacman -Qkk pacman` agreed with "0 altered files"). The tracked copy differs from
upstream in **exactly two uncommented lines**, and is kept that way deliberately so
that `diff /etc/pacman.conf /etc/pacman.conf.pacnew` shows only what upstream changed:

```
33c33   #Color            ->  Color
36c36   #VerbosePkgLists  ->  VerbosePkgLists
```

`VerbosePkgLists` is the one that earns the edit — it turns the upgrade confirmation
into a table with old version, new version, net change and download size per package,
which is what makes `sysup`'s pacman step reviewable rather than a flat name list.
There is no CLI equivalent (`pacman -Syu --help` offers `--color`, `-v` and `--config`
and nothing else), so the file is the only place it can be set. `Color` came along
because pacman emits **no colour at all** by default — it is off, not auto — and once
the file is modified it costs nothing further. It is tty-aware: verified that piped
output carries no escape sequences, so logs stay clean.

The cost is a permanent `.pacnew` obligation on a file that previously had none.
That is bounded by `config-drift`'s first check, which reports pending `.pacnew` with
changed-line counts and ages — the exact failure it was written for.

`conf.d/wireless-regdom` is another package-owned configuration, from `wireless-regdb`.
Tracked on 2026-09-06 as an exact copy of the live file, it preserves the single active
`WIRELESS_REGDOM="DE"` assignment and the package's commented country examples. The
installed udev helper reads it and requests that country domain. Review `.pacnew` changes
and review the country setting when using the machine elsewhere. The effective device
rules also depend on driver/firmware and other regulatory inputs; tracking this file is
not a guarantee of specific channels or transmit power.

## PAM package comparison (2026-09-06)

Read-only comparison used `util-linux-2.42.3-1-x86_64.pkg.tar.zst` from the local
pacman cache and `ly-1.4.1-1-x86_64.pkg.tar.zst` downloaded from the
[Arch Linux Archive](https://archive.archlinux.org/packages/l/ly/ly-1.4.1-1-x86_64.pkg.tar.zst).
Each extracted PAM original matched its installed package's `%BACKUP%` MD5 record
in `/var/lib/pacman/local/`: `b42499bb09b7d6d649080f46f32fd0aa` for login and
`0d62d3512df8976f6dc0f2430e39e532` for Ly. This verifies the compared file against
the installed backup record; it is not an archive signature verification.

- `/etc/pam.d/login`: only the blank line following `#%PAM-1.0` was removed.
  Every nonblank line is identical; no authentication policy difference.
- `/etc/pam.d/ly`: the live file consists of the header and four `include
  system-login` rules (`auth`, `account`, `password`, `session`). The package uses
  `include login` and adds optional GNOME Keyring and KWallet rules, an optional
  elogind session rule, and `-session optional pam_systemd.so class=greeter`
  before the session include.

The installed `system-local-login`, `system-login` and `system-auth` files belong
to `pambase 20260616-1` and are reported unmodified. The normal include path is
`login` → `system-local-login` → `system-login`. Including the latter directly
skips the wrappers, but it still supplies `pam_nologin.so`, the common auth stack,
and `-session optional pam_systemd.so`. Do not describe the live Ly file as
removing systemd integration or all nologin checks.

GNOME Keyring, KWallet and elogind PAM modules were absent on inspection;
`pam_systemd.so` was present. Removing its explicit `class=greeter` call is a
real stack difference whose runtime effect was not tested. A leading `-` on a
PAM rule suppresses missing-module logging; it does not disable the rule (see
[Linux-PAM configuration semantics](https://man7.org/linux/man-pages/man5/pam.d.5.html)).
The reason and date of the local changes were not established.

No live configuration or installation mapping changed. Both paths remain in
`etc/modified.txt`: the baseline reflects byte differences, including whitespace.
Agreed 2026-09-06: leave live PAM unchanged. Tracking Ly or changing its greeter
session behavior remains a separate decision; see `TODO.md`.

## What each file is for

| Path | Why |
|---|---|
| `pacman.conf` | **Package-owned and modified** — see the exceptions section above. Differs from the shipped default in two lines only: `Color` and `VerbosePkgLists`. |
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
| `systemd/logind.conf.d/10-lid-and-power.conf` | Power-button and lid behaviour. A **drop-in**, not an edit to `logind.conf`, so systemd keeps owning every default not named here. Carries only the three settings that actually deviate: `HandlePowerKey=suspend`, `HandlePowerKeyLongPress=poweroff`, `HandleLidSwitchExternalPower=lock`. The last is why reproducing suspend behaviour requires being unplugged. `/etc/systemd/logind.conf` itself is left at the package default — verified on 2026-09-04 that the drop-in alone supplies all three. |
| `tlp.d/10-local.conf` | Power management. A **drop-in**, so `/etc/tlp.conf` stays at the package default and upstream keeps owning 22KB of documented settings. Carries 21 values: CPU governors and boost, platform profile, PCIe ASPM, and the 75/81% charge thresholds. TLP reads its defaults, then `tlp.d/*`, then `tlp.conf` — so anything left in `tlp.conf` still wins over this. |
| `vconsole.conf` | Preserves the existing `FONT=default8x16` Linux console setting. Tracked 2026-09-06 for rebuild reproducibility; the current `sd-vconsole` hook warns and uses defaults when the file is missing/empty. |
| `environment` | `QT_QPA_PLATFORM=wayland` — without it Qt apps fall back to XWayland. |
| `conf.d/wireless-regdom` | **Package-owned and modified** — preserves the existing Germany regulatory-domain request (`WIRELESS_REGDOM="DE"`). Location-dependent; review when operating elsewhere. |
| `conf.d/snapper` | `SNAPPER_CONFIGS="home root"`. One line, and it is what makes `snapper-timeline.timer` and `snapper-cleanup.timer` act on both configs rather than neither. |
| `udev/rules.d/51-android.rules` | USB access to a Samsung (`04e8`) tablet, connected every month or two to move files; the MTP software is installed on demand, so the rule must be right before it exists. `MODE="0660", TAG+="uaccess"` since 2026-09-08 — logind grants the device to whoever is logged in at this laptop and revokes it at logout. It replaced `MODE="0666"` (every process on the machine) plus an inert `GROUP="users"`, a group this user is not in. |

## Not everything in `/etc` belongs here

Tracking is for files that are **hand-written and safe to copy onto any machine**. A file can
be both customised and a bad thing to track:

**`/etc/fstab`, `/etc/default/grub` and `/etc/mkinitcpio.conf` — deliberately not tracked,
decided 2026-09-04.** All three describe *this machine* rather than this configuration:

- `fstab` mounts by UUID, and those UUIDs belong to this NVMe.
- `grub` carries `amdgpu.dcdebugmask=0x10` (an AMD GPU workaround) and `rootfstype=btrfs`,
  the latter a boot failure on a machine that is not btrfs. Since 2026-09-09 it also carries
  `GRUB_TOP_LEVEL="/boot/vmlinuz-linux"`, a path into this machine's own `/boot`.
- `mkinitcpio.conf` sets `MODULES=(btrfs)` and `BINARIES=(/usr/bin/btrfs)`, both tied to the
  filesystem design rather than to any preference.

**`mkinitcpio.conf` HOOKS migrated udev → systemd on 2026-09-04**, taking the `.pacnew`'s
`HOOKS` line and nothing else. `MODULES` and `BINARIES` were **kept**: the `.pacnew` blanks
both because it is the stock file, not because upstream dropped them, and pulling those lines
is the easy mistake in that vimdiff.

```
HOOKS=(base systemd autodetect microcode modconf kms keyboard sd-vconsole block filesystems fsck)
```

Verified by reboot, and at the binary level — `init` in the image is now a symlink to
`usr/lib/systemd/systemd`, where the old one was a `#!/usr/bin/ash` busybox script. Boot time
is unchanged within noise (23.5s vs 23.7-24.2s), but the phase is now *measurable*: the udev
init never reported its timing, so `systemd-analyze` folded it into "kernel" (~4.5s); it now
reads `846ms (kernel) + 3.218s (initrd)`.

The honest case for the migration is alignment and options, not speed. On a single-device
btrfs the two flavours do the same work. What it buys is Arch's tested default, early boot in
the journal, and the prerequisite for `sd-encrypt`, which keeps `systemd-cryptenroll` TPM/FIDO2
enrolment available as an option.

**Boot-path facts worth knowing before touching this again.** Since 2026-09-09 **two kernels are
installed** -- `linux` and `linux-lts 6.18.50` -- and `PRESETS=('default')` still means **no
fallback image is built for either**. That is `mkinitcpio`'s own shipped default rather than a
local edit (verified against `/usr/share/mkinitcpio/hook.preset`), and it was left alone
deliberately: a fallback image covers a driver `autodetect` trimmed out, a second kernel covers a
bad kernel or module version, and on this machine the second failure is the likelier one.
Reasoning in `TODO.md`'s closed list. `/boot` sits at 144 MB of 1.1 GB, up from 81 MB.

`/boot` is its own vfat partition outside btrfs, so **no snapshot contains a kernel or an
initramfs** and a snapshot rollback cannot repair a broken boot image. Before the LTS install
every GRUB entry loaded the same `/initramfs-linux.img` -- the handful in `grub.cfg` plus the
`grub-btrfs` snapshot ones, which live in `grub-btrfs.cfg` and are loaded by `configfile` at
`grub.cfg:183`; that total drifts with snapshot churn and was 12 when first measured, 16 on
2026-09-09. `grub-btrfs.cfg` was regenerated after the install and now offers **both** kernels for
every snapshot -- 36 references each to `vmlinuz-linux` and `vmlinuz-linux-lts`, counted
2026-09-09 -- so LTS is reachable from the snapshot submenu as well as from **Advanced options**,
and a broken `initramfs-linux.img` no longer takes every entry in the menu with it. That single
point of failure is why the `HOOKS` migration was done with
`cp /boot/initramfs-linux.img /boot/initramfs-linux-prev.img` first and recovery via the GRUB
`e` key.

**`10_linux` sorts filenames, not versions.** Installing `linux-lts` silently moved LTS into the
top-level `GRUB_DEFAULT=0` entry: the reverse version sort at `10_linux:205` runs over the
`/boot/vmlinuz-*` **filenames**, and `vmlinuz-linux-lts` sorts ahead of `vmlinuz-linux`. Nothing
warns about it and the only symptom is `uname -r` after a reboot. `/etc/default/grub` now carries
`GRUB_TOP_LEVEL="/boot/vmlinuz-linux"`, which `10_linux:208` uses to force that kernel back to the
front, and `GRUB_TIMEOUT` went 2 -> 5 so the Advanced options submenu is actually reachable in the
seconds the menu is up. **No pacman hook regenerates `grub.cfg`** -- `/etc/pacman.d/hooks/` is
empty and `/usr/share/libalpm/hooks/` ships none, by Arch's design -- so a newly installed kernel
reaches the menu only after `grub-mkconfig -o /boot/grub/grub.cfg` is run by hand.

Note also that the pacman hook `90-mkinitcpio-install.hook` rebuilds on `PostTransaction`, so
leaving an edited `mkinitcpio.conf` unbuilt means the next kernel update builds it unattended. An
edited `linux.preset` would survive those updates:
`/usr/share/libalpm/scripts/mkinitcpio` moves a modified preset aside to `.pacsave` on kernel
removal and moves it back on install, deleting only one that is byte-identical to the template.

A cosmetic consequence recorded after the systemd-hook migration was that
`systemd-vconsole-setup` ran early enough to hit `fbcon: Deferring console take-over`
and logged `'/dev/tty1' has no font support, skipping`. These are historical boot
observations, not a fresh check that the font is or is not applied today.

The existing `FONT=default8x16` setting is now preserved in tracked `etc/vconsole.conf`
(decided 2026-09-06). Its purpose is reproducibility of the console preference. The
current installed `sd-vconsole` hook warns and uses defaults when this file is absent
or empty; the missing-file error recorded in November 2025 does not establish a
current build failure. The file's timestamp does not establish its author or origin.

The reasoning behind each — why the subvolumes are split the way they are, why btrfs is in the
initramfs — belongs in `docs/architecture.md`, and is there. The files themselves are a record of one
machine's hardware, and copying them onto different hardware ranges from useless to
unbootable.

**The original fstab-specific note follows.** Every line mounts by UUID, and
those UUIDs belong to this specific NVMe. Copying this file onto a rebuilt machine would point
every mount at a filesystem that does not exist there: it would not boot, and `install-root.sh`
would have done it silently. The layout it encodes — which subvolumes exist, where each mounts,
and why `@docker`/`@pkg`/`@postgres` are separate — is already in `docs/architecture.md`, the part
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
- **`/etc/pacman.d/mirrorlist`** — generated, location-specific, and goes stale by design, so
  tracking it would be actively wrong: a committed list is a snapshot of which German mirrors
  were fast on one afternoon. Regenerated 2026-09-04 from Arch's own generator with
  `use_mirror_status=on`, ranked by `rankmirrors -n 10` (`pacman-contrib`, already installed for
  `pacdiff` — `reflector` is deliberately not installed for this). The procedure, its recovery
  path and the `sudo tee` trap are in `docs/system-notes.md`; `sysup` warns past 90 days.
  The previous list was 86 days old and carried **12 hosts Arch had already retired**, which is
  the failure this file class invites — nothing errors, a delisted mirror just quietly serves an
  older database.
- **`/etc/ly/config.ini`** — merged to 1.4.1 on 2026-09-04 and now deviates from the shipped
  default by **exactly one line**, `clock = %H:%M` (upstream ships `clock = null`, i.e. no
  clock at all). Not tracked on purpose: pacman never overwrites a modified backup file, it
  writes a `.pacnew`, which `config-drift` already reports — so tracking buys no protection
  and would put 13.5 KB in the repo to go stale on every ly release. What a rebuild loses is
  that one cosmetic line, recorded here instead. The same merge dropped `min_refresh_delta`,
  which upstream **removed** in favour of `animation_frame_delay` and which had been sitting
  in the file doing nothing.

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

## Never `systemctl restart systemd-logind` on a live session

logind owns session and seat tracking, so restarting it under a running Wayland session can
leave the compositor orphaned. That happened on 2026-09-04 while reverting `logind.conf` to
the package default: the session became unusable and needed a forced restart. The end state
was correct and nothing was damaged — but the transition cost a session.

**Reboot instead.** logind config changes are not urgent; they apply at the next boot, and no
setting here is worth ending a session over.

The general lesson is worth more than the specific one: checking that the *end state* will be
correct is not the same as asking what the *transition* does to a running system. Both forced
restarts on 2026-09-04 came from that gap.
