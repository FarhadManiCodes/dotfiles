# Dotfiles

Personal dotfiles for **Arch Linux + Niri (Wayland)** — data engineering / scientific computing setup.

All user configs are symlinked from this repo via `install.sh` so changes here immediately take effect. System-level files are installed via `install-root.sh`.

## Stack

| Category | Tools |
|---|---|
| Shell | Zsh + Starship + Zoxide + Direnv |
| Editor | Neovim (primary) · Vim (lightweight editing) |
| Terminal | Foot |
| Compositor | Niri |
| Multiplexer | Tmux |
| Browser | Firefox (userChrome) + Tridactyl · vimb |
| File Manager | vifm (TUI) · pcmanfm-qt (GUI) |
| Launcher | Fuzzel |
| Notifications | Mako |
| Lock screen | Swaylock |
| Status / OSD | wob |
| Git TUI | Lazygit |
| Python REPL | ptpython |
| Data | DuckDB |
| PDF / Reading | Zathura · Sioyek · Foliate · Papis |
| Video | mpv |
| Music | spotify-player · cmus |
| AUR Helper | paru |

## Installation

```bash
git clone --recurse-submodules git@github.com:FarhadManiCodes/dotfiles.git ~/dotfiles
cd ~/dotfiles
bash install.sh           # user-level: symlinks into ~/.config (no sudo)
sudo bash install-root.sh # system-level: root-owned files under /etc
```

> `--recurse-submodules` is required to pull the Neovim config.

### After install

```bash
# Zsh plugins (cloned locally, not tracked)
~/.config/zsh/update-plugins.sh

# Restart shell
source ~/.zshrc

# Vim plugins
vim +PlugInstall +qall

# Tmux plugins — inside a tmux session:
# Prefix + I
```

### Fresh machine: Git identity

`install.sh` creates `~/.config/git/config.local` with a placeholder if it does not exist. Fill it in:

```ini
[user]
    name = Your Name
    email = you@example.com
```

## Architecture & Structure

```
dotfiles/
├── install.sh              # Symlinks user-level configs (no sudo)
├── install-root.sh         # Copies system-level configs to /etc
├── .gitignore
├── .claudeignore
├── CLAUDE.md               # Claude/agent instructions and repo overview
│
├── nvim/                   # Neovim config (git submodule → FarhadManiCodes/nvim-config)
├── vim/                    # Vim config (lightweight editing)
│   ├── vimrc
│   └── config/             # basic, plugins, mappings, autocmds, languages
│
├── zsh/
│   ├── .zshrc / .zshenv
│   ├── aliases
│   ├── helpers.zsh
│   ├── functions/          # auto-loaded functions (fzf, cpp, pdf, search, etc.)
│   ├── generate-completions.sh
│   └── update-plugins.sh
│
├── tmux/
│   ├── tmux.conf
│   └── layouts/            # default and archive layouts
│
├── git/
│   ├── config              # aliases, delta, diff/merge settings (no user info)
│   └── ignore              # global gitignore
│
├── firefox/                # Firefox userChrome.css
├── tridactyl/              # Firefox vim bindings config
├── vimb/                   # vimb browser config
├── uv/                     # uv configuration
├── pam/                    # PAM config for Swaylock (root-owned)
├── system-sleep/           # systemd sleep hooks (root-owned)
├── systemd/user/           # User systemd services
│
├── niri/config.kdl         # Window manager
├── foot/foot.ini
├── swaylock/config
├── mako/config
├── wob/wob.ini             # overlay bar (volume/brightness)
├── fuzzel/fuzzel.ini
├── environment.d/          # Wayland environment variables
├── paru/paru.conf          # AUR helper config
├── lazygit/config.yml
├── ptpython/config.py
├── starship.toml
├── bat/config
├── btop/btop.conf
├── zathura/zathurarc
├── sioyek/                 # Sioyek PDF reader config
├── foliate/                # Foliate e-book reader themes & settings
├── papis/                  # Bibliography manager config
├── mpv/mpv.conf
├── yt-dlp/config
├── spotify-player/         # CLI Spotify client
├── cmus/rc                 # CLI music player
├── glow/glow.yml
├── gh/config.yml           # hosts.yml not tracked — contains auth tokens
├── direnv/direnvrc
├── ripgrep-all/config.jsonc
├── clangd/config.yaml
├── ccache/ccache.conf
├── handlr/handlr.toml
├── latexmk/latexmkrc
├── vifm/                   # vifm file manager config & colors
├── gtk-3.0/settings.ini
├── gtk-4.0/settings.ini
├── pcmanfm-qt/default/     # settings & bookmarks
├── mimeapps.list
├── xdg/user-dirs.dirs
├── bash/                   # Helper scripts linked to ~/.local/bin/
├── applications/           # Custom .desktop files linked to ~/.local/share/applications/
├── duckdb/.duckdbrc
├── fonts/                  # Custom fonts copied to ~/.local/share/fonts/
└── aur/                    # Local AUR PKGBUILD overrides (e.g. llama.cpp-vulkan patch)
```

## What is not tracked

| Path | Reason |
|---|---|
| `~/.config/git/config.local` | Name + email |
| `~/.config/gh/hosts.yml` | Auth tokens |
| `~/.config/zsh/plugins/` | Plugin repos — cloned by `update-plugins.sh` |
| `~/.config/zsh/completions/` | Generated by `generate-completions.sh` |
| `gtk-3.0/bookmarks` | Personal folder paths |


## Neovim submodule

The Neovim config lives at [FarhadManiCodes/nvim-config](https://github.com/FarhadManiCodes/nvim-config) and is included as a submodule at `nvim/`.

To update the nvim config pointer:

```bash
cd ~/dotfiles/nvim && git pull origin main
cd ~/dotfiles && git add nvim && git commit -m "chore(nvim): update submodule"
```

## TODOs

- [ ] Decide on `zsh/archive/productivity/duckdb.sh` — revive or delete
