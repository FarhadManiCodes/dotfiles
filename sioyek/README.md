# Sioyek

User config for [sioyek](https://github.com/ahrm/sioyek) — vim-flavored PDF reader for research papers and technical books. Replaces Zathura.

## Files

| File | Purpose |
|---|---|
| `prefs_user.config` | Preferences (colors, page cache, smooth scroll, SyncTeX). Overrides defaults in the binary's adjacent `prefs.config`. |
| `keys_user.config` | Keybindings. Overrides defaults in the binary's adjacent `keys.config`. |

Both are symlinked into `~/.config/sioyek/` by `install.sh`. Sioyek picks them up automatically at startup; no other wiring needed.

## Sioyek itself (not in this dotfile)

This config assumes a custom build sitting at `~/.local/share/sioyek/sioyek` with a wrapper at `~/.local/bin/sioyek`. The build source lives at `~/Installs/sioyek/` on branch `personal` and is **not** part of this dotfile repo.

Build summary:
- `-march=znver4 -O3 -flto=auto` for Ryzen 7 PRO 7840U
- Wayland-only (`QT_QPA_PLATFORM=wayland` set by the wrapper)
- Bundled mupdf submodule (static-linked into sioyek; `mutool` also installed to `~/.local/bin/` for vifm previews etc.)
- `SIOYEK_NO_TTS` flag — no `qt6-speech` dependency
- Portable layout under `~/.local/` — no system install

See `~/Installs/sioyek/CLAUDE.md` for the full build/flag rationale.

## Keybinding reference

| Key | Action | Notes |
|---|---|---|
| `<right>` / `<left>` | next / previous page | Zathura-style. Overrides upstream's odd default (arrow keys do horizontal pan). |
| `<f8>` | Toggle gruvbox custom-color mode | Background `#282828`, text `#ebdbb2`. Off by default. |
| `<f7>` | Toggle visual (smooth) scroll | Upstream default. Smooth scroll is enabled on startup. |
| `F` | Keyboard smart-jump | Vimium-style hint overlay on every citation / fig-ref. Type the hint letter to jump. |
| `f` | Keyboard open-link | Same overlay style for native PDF hyperlinks. |
| `v` | Keyboard text selection | Vim-style. |
| `<A-f>` | Keyboard overview | Same hint overlay as `F`, but opens an overview window instead of jumping. |
| `O` | Quick-open | Fuzzy search reading history. |
| `t` | TOC fuzzy search | Auto-generated for PDFs without a real TOC. |
| `m<letter>` / `` ` ``<letter> | Set / goto mark | Lowercase = local to doc, uppercase = global. |
| `b` | Add named bookmark | Fuzzy searchable. |

For everything else: command palette via `:` (e.g., `:toggle_dark_mode`).

### Custom commands

Defined with `new_command` in `prefs_user.config`, bound in `keys_user.config`. Each
shells out to a script in `dotfiles/bash/` (symlinked into `~/.local/bin`).

| Key | Action | Script |
|---|---|---|
| `<A-n>` | Append a note for this page + selection to the document's papis `notes.md`, then open it in nvim | `sioyek-papis-note` |
| `<A-p>` | Upsert a selected DOI / title into papis — opens the entry if present, else adds it | `sioyek-papis` |
| `i` | Jump to the end of the selection in nvim (SyncTeX) | `sioyek-to-source` |
| `<A-i>` | SyncTeX at the mouse cursor, no selection needed | built-in `synctex_under_cursor` |
| `ss` | Search the selection on Google Scholar | `scholar-search` |
| `sw` | Search the selection on Wikipedia | `wike` |

**`<A-n>` note format.** Quotes are wrapped in `<!--quote-->` fences and the page
position is stored as an HTML comment, so that papis-ask can strip both before
embedding — the paper's own text is already indexed from the PDF, and embedding it a
second time from a note would crowd out other sources. A selection is optional; with
none you get just the page heading to write a page-level thought under.

**Two placeholder facts, verified in sioyek's source, that cost a broken note before they
were found** (`pdf_viewer/main_widget.cpp`):

- **`%{page_number}` is 0-based in commands.** The command path substitutes
  `get_current_page_number()` raw (`:4210`), while the status bar renders
  `get_current_page_number() + 1` (`:1440`) — so a script receives one *less* than the
  page the reader sees. `sioyek-papis-note` adds it back; the number it writes is also
  what `goto_page_with_page_number` expects, since that does `stoi(text) - 1`.
- **`%{current_page_label}` does not exist as a command placeholder.** It is substituted
  only into the status-bar format string (`:1441`); the command substitution list
  (`:4188`–`4270`) does not include it, so in a `new_command` it arrives as the literal
  text `%{current_page_label}`. It reached a note heading exactly that way.

The valid command placeholders are: `file_path`, `file_name`, `selected_text`,
`selection_begin_document`, `selection_end_document`, `page_number`, `command_text`,
`mouse_pos_window`, `mouse_pos_document`, `paper_name`, `sioyek_path`, `local_database`,
`shared_database`, `selected_rect`, `line_text`, `offset_x`, `offset_y`,
`offset_x_document`, `offset_y_document`, `zoom_level` — plus legacy `%1`–`%5`. Anything
else passes through untouched, **silently**.

```markdown
## p.7 — 2026-08-05
<!--sioyek page=6 label=7 offset_y=3412.8-->

<!--quote-->
> the residual is bounded by the discrete inf-sup constant
<!--/quote-->

this is the assumption that breaks for a non-conforming mesh
```

Both `page` and `label` are recorded because sioyek does not document which of
`%{page_number}` / `%{current_page_label}` is 1-based. The label is what the heading
shows; if it ever reads one off from what sioyek displays, swap the two in
`prefs_user.config`.

Notes are answerable by `pask`: papis-ask embeds them, stripping the fenced quotes and
HTML comments first, and cites them as `@ref (note)` so an answer never passes your own
thinking off as the authors'. A capture you have not written under yet is skipped
entirely — a heading and a quote alone have nothing in them to index.

Editing a note re-embeds only that note (`determine_file_status` keys on mtime), so
`pask index` after a reading session is cheap.

## Notable prefs

| Pref | Value | Why |
|---|---|---|
| `num_cached_pages` | 7 | Smoother long scrolls (default 5). Each cached page is a rasterized texture; RAM cost is modest. |
| `custom_background_color` | `0.157 0.157 0.157` | Gruvbox `#282828` — used by toggle_custom_color (F8). |
| `custom_text_color` | `0.922 0.859 0.698` | Gruvbox `#ebdbb2` — same. |
| `startup_commands` | `toggle_visual_scroll` | Smooth scroll on by default. |
| `fit_to_page_width_ratio` | `1.0` | Fit-to-width uses full window width (zathura `adjust-open width` equivalent). |
| `smartcase_search` | `1` | Case-insensitive search unless query has uppercase. |
| `should_highlight_unselected_search` | `1` | Highlight every search match, not just the current. |
| `wheel_zoom_on_cursor` | `1` | Zoom toward cursor on scroll (not viewport center). |
| `preserve_image_colors_in_dark_mode` | `1` | Don't recolor raster images when in custom-color mode. |
| `inverse_search_command` | `nvim --headless -c "VimtexInverseSearch %2 '%1'"` | SyncTeX → nvim via vimtex's server registry; the foot window is then focused by the `VimtexEventViewReverse` autocmd in nvim-config (Wayland/niri). |

## Known gotcha: ASCII only

**Both config files must be pure ASCII.** Sioyek's config parser (`pdf_viewer/utils.cpp:2231` → `open_wifstream`) opens config files as `std::wifstream` with the C locale and no UTF-8 codecvt. The first multi-byte UTF-8 sequence (em-dash, box-drawing characters, arrows, smart quotes) silently puts the stream into a fail state, and every setting *past that point* is dropped — with no error message.

Symptom we hit: gruvbox colors looked like sioyek's slate-blue defaults even though the file appeared correct. The bug happened because pretty Unicode comments (`—`, `─`, `→`) sat above the `custom_background_color` line.

If you ever want to upstream the fix, it's a one-liner in `open_wifstream` to imbue a UTF-8 codecvt on the returned stream.

Original Unicode-in-comments version saved as `~/.config/sioyek/prefs_user.config.bak.unicode` as a regression reproducer (not in this dotfile repo).

## Rebuilding sioyek

```bash
cd ~/Installs/sioyek
git checkout personal
git rebase development      # pull upstream + replay personal commits
# Rebuild only what changed
cmake --build build-cmake -j8
install -m 755 build-cmake/sioyek ~/.local/share/sioyek/sioyek
```

If upstream's `development` branch has new commits, see the commit log on the `personal` branch — each commit explains *why* its hunk exists, which is the only thing that matters during a rebase conflict.

## Migrated-from-zathura mapping

| Zathura | Sioyek |
|---|---|
| `recolor true` + `recolor-lightcolor #282828` + `recolor-darkcolor #ebdbb2` | `toggle_custom_color` (F8) with the `custom_background_color` / `custom_text_color` set above |
| `recolor-keephue true` | No 1-to-1 — closest is regular `toggle_dark_mode` (hue-preserving invert), or `preserve_image_colors_in_dark_mode 1` for raster images only |
| `map <Right> navigate next` | `next_page <right>` in keys_user.config |
| `map <Left> navigate previous` | `previous_page <left>` |
| `adjust-open "width"` | `fit_to_page_width_ratio 1.0` |
| `synctex-editor-command "... %{input} %{line}"` | `inverse_search_command ... %1 %2` (Qt placeholder syntax) |
| `selection-clipboard clipboard` | Default behavior, no setting needed |
| `statusbar-basename true` / `window-title-basename true` | Not configurable in sioyek |
