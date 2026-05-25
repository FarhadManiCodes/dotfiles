# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a configuration directory for **niri**, a scrollable-tiling Wayland compositor. The primary configuration file is `config.kdl`, written in KDL (KDL Document Language) format.

## Configuration Structure

### Main Configuration File: config.kdl

The configuration is organized into these major sections:

1. **Input Device Configuration**
   - Keyboard settings (XKB layout, numlock)
   - Touchpad settings (tap, natural-scroll, acceleration)
   - Mouse and trackpoint settings
   - Focus behavior (focus-follows-mouse, warp-mouse-to-focus)

2. **Output Configuration**
   - Display setup for multiple monitors
   - `eDP-1`: Built-in laptop display (1920x1200, position 0,0)
   - `HDMI-A-1`: External monitor in portrait mode (1920x1080 rotated 90°, positioned at 1920,-300)
   - To list available outputs: `niri msg outputs`

3. **Layout Settings**
   - Window gaps, column widths, and window heights
   - Focus ring appearance and borders
   - Shadow configuration (currently disabled)
   - Struts for outer gaps

4. **Startup Programs**
   - swaybg (wallpaper)
   - wob (on-screen display for volume/brightness via FIFO at /tmp/wobpipe)
   - mate-polkit (authentication agent)
   - swayidle (idle management and screen locking)
   - cliphist daemon (clipboard history)
   - wlsunset (screen temperature adjustment)

5. **Window Rules**
   - Firefox picture-in-picture: floating
   - vifm file manager (launched in foot terminal via Mod+E)
   - Password managers (KeePassXC, GNOME Secrets, Bitwarden, 1Password): blocked from screen capture
   - Global 5px rounded corners for all windows
   - Default column width (50%): Firefox, Zathura (DjVu), foot

6. **Keybindings**
   - Vim-style navigation (Mod+H/J/K/L)
   - Workspace management
   - Window movement and resizing
   - Application launchers (Mod+T terminal, Mod+Return tmux, Mod+D fuzzel, Mod+B Firefox, Mod+P Firefox private, Mod+E vifm file manager in foot)
   - System controls (volume, brightness, screenshots)

## Common Commands

### Testing Configuration Changes
```bash
# After editing config.kdl, reload niri
niri msg action load-config-file

# Or restart niri entirely (from within a niri session)
niri msg action quit
```

### Querying Niri State
```bash
# List all outputs (monitors) and their properties
niri msg outputs

# List all workspaces
niri msg workspaces

# List all windows
niri msg windows

# Get current version
niri msg version
```

### Debugging
```bash
# Check if config is valid
niri validate

# View niri logs (if running as systemd service)
journalctl --user -u niri
```

## Key Configuration Patterns

### Monitor Setup
When configuring outputs, note that:
- Position coordinates are in logical pixels
- Portrait monitors need `transform "90"` or `transform "270"`
- The laptop display (`eDP-1`) is the anchor at position (0,0)
- External monitors are positioned relative to it

### Keybinding Syntax
```kdl
Mod+Key { action; }
Mod+Key hotkey-overlay-title="Description" { action arg1 arg2; }
Mod+Key allow-when-locked=true { action; }
```

Common modifiers: `Mod`, `Shift`, `Ctrl`, `Alt`
- `Mod` = Super on TTY, Alt when running as window

### Window Rules
```kdl
window-rule {
    match app-id="regex-pattern"
    match title="regex-pattern"
    property value
}
```

Multiple `match` nodes within a single `window-rule` are **OR** conditions — the rule applies if any one of them matches. Within a single `match` node, multiple properties are **AND** conditions.

Use `/-` prefix to comment out entire nodes (KDL syntax).

## Important Files and Paths

- Screenshot path: `~/Pictures/Screenshots/Screenshot from %Y-%m-%d %H-%M-%S.png`
- Background image: `/usr/share/backgrounds/fsi-zen.png`
- Library browser (Mod+z): `~/.local/bin/zathura-resources` — fuzzel picker, opens via xdg-open (sioyek/zathura/foliate)
- Library cache: `~/.cache/zathura-resources.txt` — pdf/djvu/epub under `FAU/Library/`
- Foot theme toggle: `~/.local/bin/toggle-foot-theme.sh`

## Configuration Documentation

Full documentation available at: https://yalter.github.io/niri/Configuration:-Introduction

Key sections:
- Input: https://yalter.github.io/niri/Configuration:-Input
- Outputs: https://yalter.github.io/niri/Configuration:-Outputs
- Layout: https://yalter.github.io/niri/Configuration:-Layout
- Window Rules: https://yalter.github.io/niri/Configuration:-Window-Rules
- Animations: https://yalter.github.io/niri/Configuration:-Animations

## Customization Notes

This configuration uses:
- Vim-style navigation (H/J/K/L) throughout
- Caps Lock remapped to Ctrl
- Focus follows mouse with no scroll requirement
- Mouse warps to center of focused windows
- No CSD (client-side decorations) preferred
- 5px rounded corners on all windows
- Tmux integration via Mod+Return
- Clipboard history via Ctrl+`
- wob for volume/brightness OSD (blue=volume, yellow=brightness, red=muted); controlled via ~/.local/bin/wob-control
- Foot theme toggle via Mod+Alt+T (toggle-foot-theme.sh)
