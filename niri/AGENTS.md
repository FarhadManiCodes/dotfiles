# Niri-specific instructions

Read `README.md` in this directory for the configuration map, keybindings, paths,
and operational details. Root dotfiles instructions also apply.

- Edit `config.kdl` using its existing KDL structure. Use `/-` to comment out a node.
- Multiple `match` nodes in a window rule are OR; properties within one `match`
  are AND. Preserve password-manager screen-capture exclusions.
- Output positions use logical pixels. Keep `eDP-1` as the origin and position
  external monitors relative to it; query actual outputs before changing hardware settings.
  Portrait displays use `transform "90"` or `transform "270"`.
- Preserve vim-style navigation, Caps-to-Ctrl, focus behavior and the existing
  launcher/terminal integration unless the task requests a change. `Mod` means
  Super on a TTY and Alt when Niri runs in a window.
- Idle management belongs to `systemd/user/swayidle.service`, not an additional
  `spawn-at-startup`. Consult the root architecture's locking/suspend section first.
- The book picker uses the local study-library mirror for offline access. Do not
  restore an rclone-mounted source, cache file, or startup pre-warm without new evidence.

Validate with `niri validate` after confirming it resolves the edited config.
Use `niri msg outputs`, `niri msg windows`, and `niri msg workspaces` for live evidence.
Verify the unit exists before interpreting `journalctl --user -u niri` output.
The reference lists reload and quit commands; quitting ends the compositor session
and is not an ordinary validation step. Check the installed CLI before using reload commands.
