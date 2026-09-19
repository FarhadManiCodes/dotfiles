# USB media — vifm `:media`, no automount daemon

**Nothing mounts USB media automatically, on purpose.** udisks2 + polkit already permit
user mounts without sudo (landing in `/run/media/$USER/<label>`), but on a bare niri
session nothing listens for the device-added event. When a drive "won't mount" it's
almost always this, not a hardware fault — check `lsblk` before debugging anything else.

The mount trigger is **vifm's built-in `:media`**, bound to `<space>m` (`vifm/vifmrc`),
backed by `set mediaprg=/usr/share/vifm/vifm-media` — both already present, no extra
package and no daemon. In the menu: `Enter` mounts an unmounted device and navigates into
it, `m` toggles mount/unmount, `r` reloads, `[`/`]` jump between devices.

Don't reintroduce a shell wrapper for this. A `usbm`/`usbu` zsh pair was written and
deleted 2026-08-11 as pure duplication, and the older `<space>m`/`<space>u` →
`udisksctl -b %f` bindings it replaced were worse still — they acted on the file under
the cursor, so they only worked with a pane parked on the device node in `/dev`. `:media`
needs neither.

A whole-disk filesystem with no partition table is normal here (a tiptoi pen is vfat
written straight to `/dev/sda`); `vifm-media` and `lsblk` both handle it.
