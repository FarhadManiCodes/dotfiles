# Revisit

Investigated issues. All three below are **accepted** — each was diagnosed to a
non-config root cause (hardware/firmware or upstream bug), not anything these dotfiles
can fix. Recheck the listed trigger on the next relevant upgrade.

---

## libinput: event lag after resume from s2idle — ACCEPTED (healthy)

libinput logs `event processing lagging behind by ~1.3s, your system is too slow` on
Lid Switch / Power Button / keyboard at the instant of resume.

- **Investigated:** s2idle is the only sleep state (`/sys/power/mem_sleep` = `[s2idle]`;
  no s3 on this AMD platform). Hardware sleep is actually excellent — `last_hw_sleep`
  ≈ 276.8 s over a 277 s suspend (~99.9 % s0i3 residency), `amd_pmc` loaded. The lag is
  the intrinsic s2idle clock-gap: `CLOCK_MONOTONIC` keeps running across sleep, so on
  resume libinput sees overdue timers/events and complains. Purely cosmetic; input works.
- **Fix:** none (would need s3 — absent on this hardware — or a libinput change).
- **Recheck:** kernel / BIOS firmware update enabling s3, or a libinput update.

---

## wireplumber: UPower battery warning at boot — ACCEPTED (cosmetic)

One line per boot: `Failed to get percentage from UPower: NameHasNoOwner`.

- **Investigated:** the bluez5 SPA plugin reports the *host* (laptop) battery to BT
  headsets via Apple's HFP extension (`AT+IPHONEACCEV`), reading it from UPower. UPower
  is intentionally not installed. D-Bus already replies `NameHasNoOwner` (= not present);
  pipewire handles it gracefully, skips the feature, and watches for UPower to appear —
  everything else works. No per-feature toggle exists in pipewire 1.6 (checked the full
  `bluez5.*` property set; `hfphsp-backend=none` does **not** gate it — tested), and
  there is no alternative interface (UPower is the only host-battery source). It's simply
  logged too loudly (warning vs debug).
- **Fix:** none clean. Accept (chosen), or install `upower` (rejected — extra daemon).
- **Recheck:** pipewire/wireplumber update lowering the log level (Debian bug #1089234).

---

## bluetoothd: Failed to set default system config for hci0 — ACCEPTED (upstream race)

One line at (cold) boot. Bluetooth works fully — all A2DP endpoints register.

- **Investigated:** a nondeterministic timing race, **not** a config issue — proven by
  A/B testing. The error hits on cold boot and some warm restarts, but 5/5 warm restarts
  on *stock* config **and** 5/5 with an explicit `PageTimeout` both passed, so the
  parameter is irrelevant. btmon shows the `Set Default System Configuration` MGMT command
  actually succeeds (`Status: Success`) when sent — bluez logs the failure spuriously
  regardless. Controller is MediaTek MT7922 with quirky firmware (`HCI Enhanced Setup
  Synchronous Connection command advertised, but not supported`). `main.conf` is stock;
  `/etc/bluetooth` is mode 555. Matches upstream bluez issue #1905 (many machines, after a
  firmware bump, benign).
- **Fix:** none (upstream bluez bug; no config affects the race).
- **Recheck:** bluez update resolving #1905, or a BT controller firmware update.
