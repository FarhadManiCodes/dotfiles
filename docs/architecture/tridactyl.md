# Tridactyl (Firefox vim bindings)

- **Config**: `tridactyl/tridactylrc` → `~/.config/tridactyl/tridactylrc`
- **Theme**: tokyonight
- **Hints**: numeric + vimperator-reflow filter, 100ms delay
- **Editor**: `footclient --app-id tridactyl-editor vim +%l %f` — opens as half-width
  tiled column in niri (see niri window rule)
- **Native messenger**: not a package — `~/.local/share/tridactyl/native_main`,
  self-installed via Tridactyl's `:installnative`, owned by no package. Required for
  `Ctrl+I` editor integration and every `tri.native.run` binding below (`,p`, `,y`, `,Y`,
  `;y`, `;Y`). The add-on itself is the `firefox-tridactyl` package.
- **Search engines**: DDG (default), `g`, `eco`, `yt`, `ss`, `gs`, `gh`, `aw`, `wiki`, `cpp`
- **Quickmarks**: `gocl` (Claude), `gogem` (Gemini), `goyt` (YouTube)
- **Key bindings**: `dt` close+move left (plain `d` unbound), `D` close, `gr` reader mode,
  `Ctrl+E` open Downloads in vifm, `f`/`F` hints current/new tab
- **Reload config**: `:source` in Firefox command bar
