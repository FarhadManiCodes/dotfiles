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

## 2. `nsswitch.conf` and `pacman.conf` — never diffed

Both are modified package-owned files (`pacman -Qkk`) that could not be compared, because
neither package is in the cache. Both looked like stock Arch. To settle it:
```bash
sudo pacman -Sw filesystem pacman     # fetch without installing
```
then diff the live file against the copy in `/var/cache/pacman/pkg/`.

---

## 3. Optional, carried over

- **NVMe health timer.** The sane alternative to `smartd`, which was rejected in August as
  built for multi-disk ATA rather than one NVMe. Still does not exist. A user timer running
  `smartctl -H` weekly would close the one hardware fault nothing here would warn about.
- **`/root/logind.conf.bak`** and **`/etc/pam.d/swaylock.bak`** — both inert, both safe to
  remove, neither urgent.
- **Off-machine backup.** Still nothing. `/home` is snapshotted hourly with ~4 months of
  retention, but those snapshots share a filesystem with the data: they protect against
  mistakes, not against a dead disk or anything running as root. This remains the only
  unanswered part of the threat model that motivated the SSH and podman work.
