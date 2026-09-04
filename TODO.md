# TODO — actions that need me, not the config

Only open items live here. Closed ones are removed rather than struck through: the
reasoning worth keeping is in `AUDIT-2026-08.md` (what changed and why), `revisit.md`
(investigated and deliberately accepted) and `CLAUDE.md` (how the system works now).
Everything else is in git — the last version carrying items 1–16 is
`git show 92bcf79:TODO.md`.

---

## 1. Merge the remaining `.pacnew` files — **CLOSED**, 2026-09-04

All nine merged in one evening; `config-drift` reports none pending. They had accumulated
since May because nothing looked for them, which is the whole reason that tool exists.

| File | What happened |
|---|---|
| `tlp.conf` | Moved to a `/etc/tlp.d/10-local.conf` drop-in, verified live by `tlp-stat -c` |
| `ly/config.ini` | Merged, verified by a reboot. One deviation left, `clock = %H:%M` — see `etc/README.md` |
| `locale.gen` | Merged, and `de_DE.UTF-8` generated alongside `en_US.UTF-8`. See `environment.d/defaults.conf` |
| `conf.d/wireless-regdom` | Merged, `WIRELESS_REGDOM="DE"` re-applied, `iw reg get` confirms `country DE` with 6 GHz |
| `bluetooth/main.conf` | Merged, `AutoEnable=false` re-applied, adapter still `Powered: no` after restart |
| `tpm2-tss` ×2 | Taken wholesale. `pacman -Qkk tpm2-tss` now reports every fapi profile matching the package |
| `pacman.d/mirrorlist` | `.pacnew` discarded, list **regenerated** — 10 https mirrors, `ftp.fau.de` from position 46 to 1 |
| `mkinitcpio.conf` | **HOOKS migrated udev → systemd**, verified by reboot — see `etc/README.md` |

Two were more than a merge:

**The mirrorlist.** Discarding its `.pacnew` was right — that file is the upstream *catalog*,
425 servers with every line commented, so taking it would have left pacman with no mirrors. But
the live list deserved suspicion: 96 entries, half plaintext-http duplicates, and **12 hosts Arch
had since retired**, `ftp.uni-bayreuth.de` among them. Arch delists mirrors that fall out of
sync, so those were the likeliest to serve a stale database, silently. Regenerated with
`use_mirror_status=on` through `rankmirrors -n 10` (`pacman-contrib`, already installed for
`pacdiff` — `reflector` was not needed):

```bash
curl -s "https://archlinux.org/mirrorlist/?country=DE&protocol=https&ip_version=4&use_mirror_status=on" \
  | sed 's/^#Server/Server/' > /tmp/ml
rankmirrors -n 10 /tmp/ml | sudo tee /etc/pacman.d/mirrorlist >/dev/null
```

Worth re-running every few months. Nothing automates it and `config-drift` cannot see it —
mirror staleness is not a `.pacnew`, and the check would need network access.

**mkinitcpio.** A migration, not a merge, and the only one that could have left the machine
unbootable. `MODULES=(btrfs)` and `BINARIES=(/usr/bin/btrfs)` are **ours** and were kept — the
`.pacnew` blanks both because it is the stock file, not because upstream dropped them. Only the
`HOOKS` line was taken. The reasoning and the boot-path facts are in `etc/README.md`.

---

## 2. `nsswitch.conf` and `pacman.conf` — **CLOSED**, 2026-09-04

Both were flagged modified by `pacman -Qkk` and neither could be compared, because neither
package was in the cache. `pacman -Sw filesystem pacman` fetched them without installing, and
the diffs settled it:

- **`pacman.conf` was byte-identical** to the package. `-Qkk` had been flagging it on
  modification time alone. Nothing to do.
- **`nsswitch.conf` was genuinely modified**, and undocumented: `systemd` removed from
  `passwd`/`group`/`shadow`/`gshadow`, and `subid` added to `group`. Edited 2025-12-05 during
  setup with no note anywhere, and nobody remembered why.

Both halves of that edit were wrong. Removing `systemd` disables an installed module
(`/usr/lib/libnss_systemd.so.2`) whose job is resolving `DynamicUser=yes` service users — free
today because this machine has none, but a *silent* failure later: if a systemd release moves
any service to `DynamicUser`, you get bare numeric UIDs in logs and `ls` with nothing to
explain it. And `subid` names `libnss_subid.so`, which **exists nowhere on the system**, in a
line where it would not belong even if it did — shadow reads `subid` as its own database, not
as a service of `group`. glibc `dlopen`s it, fails, and moves on in silence.

Rootless podman was never involved: it reads `/etc/subuid` directly, not through NSS.

Restored by extracting from the package rather than hand-editing, which also restores the
package's mtime so `-Qkk` goes fully clean:

```bash
sudo bsdtar -xpf /var/cache/pacman/pkg/filesystem-*.pkg.tar.zst -C / etc/nsswitch.conf
```

Verified: identical to the package, absent from `pacman -Qkk filesystem`, `getent` resolves
users and groups, `nobody` is 65534, and `podman ps` still shows `pg` healthy. The `hosts:`
line — the one that could have broken DNS — was already at the default and never changed.

---

## 3. Optional, carried over

- **NVMe health timer.** The sane alternative to `smartd`, which was rejected in August as
  built for multi-disk ATA rather than one NVMe. Still does not exist. A user timer running
  `smartctl -H` weekly would close the one hardware fault nothing here would warn about.
- **Stray backups**, all inert and safe to remove, none urgent: `/root/logind.conf.bak`,
  `/etc/pam.d/swaylock.bak`, `/etc/nsswitch.conf.bak`, `/etc/pacman.d/mirrorlist.bak`,
  `/etc/ly/config.ini.bak`, and `/boot/initramfs-linux-prev.img` (46 MB, kept through the
  initramfs migration and no longer needed now that it has booted).
- **`PRESETS=('default')` in `/etc/mkinitcpio.d/linux.preset`** — no fallback initramfs is
  built. Disabled deliberately at some point, and it would not have helped during the systemd
  migration (a fallback uses the same `HOOKS`, only without `autodetect`). Worth one conscious
  re-decision now that it is known all 12 GRUB entries share a single image; see
  `etc/README.md`.
- **Off-machine backup.** Still nothing. `/home` is snapshotted hourly with ~4 months of
  retention, but those snapshots share a filesystem with the data: they protect against
  mistakes, not against a dead disk or anything running as root. This remains the only
  unanswered part of the threat model that motivated the SSH and podman work.
