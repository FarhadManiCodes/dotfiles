# Firefox (userChrome)

- **Config**: `firefox/userChrome.css` → `~/.mozilla/firefox/<profile>/chrome/userChrome.css`
- **Theme**: Catppuccin Frappé — compact tab strip, flat tabs, Catppuccin-colored navbar
- **Prerequisite**: `toolkit.legacyUserProfileCustomizations.stylesheets` must be `true`
  in `about:config`
- **Install**: `install.sh` reads `~/.mozilla/firefox/profiles.ini` to find the
  default-release profile automatically
- **Note**: `userChrome.css` is the only stylesheet — no `userContent.css`.
- **about:config**: the authoritative list is the table in `firefox/firefox-notes.md`
  (documentation, not installed anywhere) — don't keep a second copy here; the two lists
  had already diverged once (2026-09-05). The portal-Inhibit warning Firefox logs on exit
  is investigated and accepted; see `revisit.md`.
