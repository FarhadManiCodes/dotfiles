# Vim (lightweight editing)

Used for markdown, config files, quick edits — not development.

- **Entry**: `vim/vimrc` → sources `~/.config/vim/config/*.vim`
- **Modules**: `basic.vim`, `plugins.vim`, `plugins_config.vim`, `autocmds.vim`,
  `mappings.vim`, `python.vim`, `yaml.vim`, `json.vim`
- **Plugins** (14): auto-pairs, vim-surround, tcomment, vim-repeat, vim-unimpaired,
  lightline, onedark, PaperColor, vim-markdown, Goyo, Limelight, vim-tmux-navigator,
  rainbow_csv, vim-envx
- **Theme toggle**: `<leader>tt` — cycles onedark → PaperColor light → PaperColor dark
- **Clipboard**: `\y` copies to Wayland, `\P` pastes — built `-clipboard`, so the mappings
  pipe to `wl-copy`/`wl-paste` rather than using `"+`/`"*`
- **Leader**: `\`

Config auto-reloads on save.
