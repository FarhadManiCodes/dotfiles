# TODO — actions that need me, not the config

Only open items live here. Closed ones are removed rather than struck through: the
reasoning worth keeping is in `AUDIT-2026-08.md` (what changed and why), `revisit.md`
(investigated and deliberately accepted) and `CLAUDE.md` (how the system works now).
Everything else is in git — the last version carrying items 1–16 is
`git show 92bcf79:TODO.md`.

---

## 1. Merge the remaining `.pacnew` files — **OPEN**, 2026-09-04

Found by `config-drift`, which `sysup` now runs after every update. Nine had accumulated
since May because nothing looked for them. Two are done: **`tlp.conf`** (moved to a
`/etc/tlp.d/10-local.conf` drop-in, verified live by `tlp-stat -c`) and **`ly/config.ini`**
(merged 2026-09-04, verified by a reboot; see `etc/README.md` for the one line it still
carries). Seven remain.

Review with `sudo pacdiff`, or `config-drift -v` for the full diffs.

### Take upstream, re-apply one line — trivial

| File | Your one change | Note |
|---|---|---|
| `/etc/locale.gen` | `en_US.UTF-8 UTF-8` uncommented | Two new locales upstream. Run `sudo locale-gen` after |
| `/etc/conf.d/wireless-regdom` | `WIRELESS_REGDOM="DE"` | Five new country codes added |
| `/etc/bluetooth/main.conf` | `AutoEnable=false` | Rest is new commented options + a `[ChannelSounding]` section |

### Just take upstream — nothing of yours in them

| File | Note |
|---|---|
| `/etc/tpm2-tss/fapi-profiles/P_ECCP384SHA384.json` | Format changed to lowercase (`TPM2_ALG_ECC` → `ecc`). **No TPM/LUKS setup here — unused** |
| `/etc/tpm2-tss/fapi-profiles/P_RSA3072SHA384.json` | Same |

### Discard the `.pacnew` — do NOT take it

**`/etc/pacman.d/mirrorlist`** — the `.pacnew` has **every server commented out**. Taking it
leaves pacman with no mirrors at all. Your current file is a ranked German mirror list.
```bash
sudo rm /etc/pacman.d/mirrorlist.pacnew
```
It is 86 days old, so refreshing is reasonable, but with `reflector` rather than the `.pacnew`.

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
