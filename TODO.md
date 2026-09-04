# TODO — actions that need me, not the config

Only open items live here. Closed ones are removed rather than struck through: the
reasoning worth keeping is in `AUDIT-2026-08.md` (what changed and why), `revisit.md`
(investigated and deliberately accepted) and `CLAUDE.md` (how the system works now).
Everything else is in git — the last version carrying items 1–16 is
`git show 92bcf79:TODO.md`.

---

## 1. Merge the remaining `.pacnew` files — **OPEN**, 2026-09-04

Found by `config-drift`, which `sysup` now runs after every update. Nine had accumulated
since May because nothing looked for them. **Eight are done, all on 2026-09-04** — one remains.

| File | What happened |
|---|---|
| `tlp.conf` | Moved to a `/etc/tlp.d/10-local.conf` drop-in, verified live by `tlp-stat -c` |
| `ly/config.ini` | Merged, verified by a reboot. One deviation left, `clock = %H:%M` — see `etc/README.md` |
| `locale.gen` | Merged, and `de_DE.UTF-8` generated alongside `en_US.UTF-8`. See `environment.d/defaults.conf` for which categories use it |
| `conf.d/wireless-regdom` | Merged, `WIRELESS_REGDOM="DE"` re-applied, `iw reg get` confirms `country DE` with 6 GHz intact |
| `bluetooth/main.conf` | Merged, `AutoEnable=false` re-applied, adapter still `Powered: no` after restart |
| `tpm2-tss` ×2 | Taken wholesale. `pacman -Qkk tpm2-tss` now reports every fapi profile matching the package |
| `pacman.d/mirrorlist` | `.pacnew` discarded and the list **regenerated** — see below |

**The mirrorlist was the one where discarding the `.pacnew` was only half the answer.** That
file is the upstream *catalog*: 425 servers with every line commented, so taking it would have
left pacman with no mirrors. But the live list deserved the suspicion — 96 entries, half of them
plaintext-http duplicates, and **12 hosts that Arch had since retired from its catalog entirely**
(including `ftp.uni-bayreuth.de`). Arch delists mirrors that fall out of sync, so those were the
ones most likely to serve a stale database.

Regenerated with `use_mirror_status=on` (only mirrors Arch currently reports in sync) piped
through `rankmirrors -n 10` — `pacman-contrib`, already installed for `pacdiff`, so `reflector`
was not needed. Result: 10 https mirrors, no plaintext, and `ftp.fau.de` moved from position
**46 to 1**. All ten verified responding with a valid `lastupdate`, worst 2.5 h behind.

```bash
curl -s "https://archlinux.org/mirrorlist/?country=DE&protocol=https&ip_version=4&use_mirror_status=on" \
  | sed 's/^#Server/Server/' > /tmp/ml
rankmirrors -n 10 /tmp/ml | sudo tee /etc/pacman.d/mirrorlist >/dev/null
```

Worth re-running every few months; nothing automates it, and `config-drift` cannot see this
(mirror staleness is not a `.pacnew`, and the check would need network access).

### Needs a decision, not a merge

**`/etc/mkinitcpio.conf`** — Arch changed the default `HOOKS` from udev-based to
**systemd-based** (`base systemd … sd-vconsole`). Yours is the udev form and works.
This is a deliberate migration, not a config merge. Either adopt it knowingly or discard the
`.pacnew`. Note `mkinitcpio.conf` is deliberately **not tracked** in this repo — it describes
this machine (`MODULES=(btrfs)`, `BINARIES=(/usr/bin/btrfs)`), see `etc/README.md`.

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
