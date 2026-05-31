# Revisit

Issues to come back to.

---

## libinput: event lag after resume from s2idle

Libinput reports "your system is too slow" and 1000ms+ event lag after lid open. Caused by
slow s2idle resume path on P16s Gen 2 — events queue during the ~1s wake-up then arrive
late. s3 (deep sleep) is not available on this hardware. Purely cosmetic, inputs work fine.
Needs BIOS/firmware improvement or kernel s2idle optimisation for this platform.

---

## wireplumber: UPower battery warning at boot

One warning at boot from the bluez5 SPA plugin trying to get Bluetooth device battery
levels via UPower (`org.freedesktop.DBus.Error.NameHasNoOwner`). UPower is not installed
by design — preference is to not run unnecessary daemons. The warning is priority 4
(warning, not error) and bluez5 continues normally without it.

---

## bluetoothd: Failed to set default system config for hci0

One-time error at every boot. Bluetooth works fine (all endpoints register). Likely a
bluez 5.86 bug — occurs before the adapter is fully initialized. `/etc/bluetooth` directory
mode already corrected to 555 (was 755).
