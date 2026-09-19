# Light/dark theme — how tools follow `Mod+Alt+T`

`bash/toggle-foot-theme.sh` signals foot (SIGUSR1 dark / SIGUSR2 light) and writes
`~/.local/state/foot_theme_state`. Tools follow in one of two ways, **preferring the
first**:

1. **Terminal-native** — the tool asks the terminal. `bat` uses `--theme=auto:always`
   (OSC 11), tmux uses palette indices (`colour13`, `default`) that foot re-resolves per
   theme. Nothing to maintain; works for future tools too.
2. **The state file** — for tools that can't self-detect, because inside tmux an OSC 11
   query is answered by *tmux*, not foot. `ptpython/config.py` and
   `ipython/profile_default/startup/01-theme.py` read it directly; `vim/config/basic.vim`
   picks onedark/PaperColor at `VimEnter` (`<leader>tt` still cycles manually); `nvim`
   maps it to onedark/newpaper at startup via `config.themes.from_desktop()`, with
   `<leader>th` as a session override and `last_theme.txt` only as fallback; and
   `bash/tmux-theme` sets the status bar, called after tpm and again by the toggle script.

   **tmux's colours must be real hex, never `default` or a palette index.** tmux-power
   uses its `g0`/`g2`/`g4` values in *foreground* slots — active-label text, the inactive
   window's trailing separator, copy-mode text — and `default` there means the terminal's
   *foreground*, not background. That capped label contrast at 2.4 whichever accent was
   chosen, and sent an earlier hunt for the "best worst-case palette index" to colour13,
   hot pink. With `g0` as the real background the same green scores 8.52 dark / 4.24
   light.

Deliberately **not** following: GTK apps (always light — see below), Firefox, the readers
(sioyek F8, zathura fixed gruvbox), and **btop**. btop was checked 2026-09-05 and left
alone by decision, not oversight: it's pinned to `color_theme = "tokyo-night"` with
`theme_background = true`, and could be wired up (41 themes, 10 light) but isn't wanted.
`theme_background = false` isn't either — btop has no terminal-following mode for
foreground colours, so tier 1 isn't available here. Note vim applies its theme on
`VimEnter`, which fires *after* `-c` commands.

## GTK appearance — dconf, not settings.ini

**Not tracked here, deliberately.** GTK font/theme/icons/cursor are governed by dconf,
read through the `xdg-desktop-portal` Settings interface, which overrides
`gtk-{3,4}.0/settings.ini` for every key it serves. Verified: a user `settings.ini`
asking for a different font is ignored even with the distro's own hidden. Both
`settings.ini` files were removed in the 2026-07-27 audit — they silently set nothing,
and a commit intending `Noto Sans 11` never took effect (GTK apps render in `Adwaita Sans
11`, GTK's own default).

To change GTK appearance: `gsettings set org.gnome.desktop.interface font-name '<font>'`
(same for `gtk-theme`, `icon-theme`, `cursor-theme`, `color-scheme`). `color-scheme` stays
`default` on purpose — GTK apps are always light and don't follow the foot/foliate theme
toggles.
