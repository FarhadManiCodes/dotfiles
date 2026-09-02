#!/bin/bash
# Updated install.sh for XDG-compliant zsh setup
# provide default values for environment variable if not defined
: "${XDG_CONFIG_HOME:=${HOME}/.config}"
: "${DOTFILES:=${HOME}/dotfiles}"
: "${XDG_DATA_HOME:=${HOME}/.local/share}"

echo "🚀 Installing dotfiles..."

# =========== vim ===============
echo "Setting up Vim..."

# Bootstrap ~/.vimrc to redirect vim to the XDG config location
cat > "${HOME}/.vimrc" << 'VIMRC'
" XDG Base Directory Specification compliance
" This file sources the actual vimrc from ~/.config/vim/vimrc
let $MYVIMRC = expand('~/.config/vim/vimrc')
if filereadable($MYVIMRC)
    source $MYVIMRC
else
    echoerr "Could not find vimrc at ~/.config/vim/vimrc"
endif
VIMRC

# Symlink entire vim config directory. This is the first section to write into
# XDG_CONFIG_HOME, so create it here — on a genuinely fresh machine ~/.config
# does not exist yet and this symlink silently failed.
mkdir -p "${XDG_CONFIG_HOME}"
ln -snf "${DOTFILES}/vim" "${XDG_CONFIG_HOME}/vim"
echo "Vim configured"

# ============ zsh ==============================
echo "🐚 Setting up Zsh..."
mkdir -p "${HOME}/.config/zsh"
ln -sf "${DOTFILES}/zsh/.zshenv" "${HOME}/.zshenv"
ln -sf "${DOTFILES}/zsh/.zshrc" "${HOME}/.zshrc"

mkdir -p "${XDG_CONFIG_HOME}/zsh/functions"
ln -sf "${DOTFILES}/zsh/aliases"               "${XDG_CONFIG_HOME}/zsh/aliases"
ln -sf "${DOTFILES}/zsh/helpers.zsh"           "${XDG_CONFIG_HOME}/zsh/helpers.zsh"
ln -sf "${DOTFILES}/zsh/generate-completions.sh" "${XDG_CONFIG_HOME}/zsh/generate-completions.sh"
ln -sf "${DOTFILES}/zsh/update-plugins.sh"    "${XDG_CONFIG_HOME}/zsh/update-plugins.sh"

for file in "${DOTFILES}/zsh/functions/"*.zsh; do
  ln -sf "$file" "${XDG_CONFIG_HOME}/zsh/functions/"
done

# Completions — generate if tools are available
mkdir -p "${XDG_CONFIG_HOME}/zsh/completions"
command -v gh      >/dev/null 2>&1 && gh completion -s zsh      > "${XDG_CONFIG_HOME}/zsh/completions/_gh"      2>/dev/null || true
command -v uv      >/dev/null 2>&1 && uv  generate-shell-completion zsh > "${XDG_CONFIG_HOME}/zsh/completions/_uv" 2>/dev/null || true
command -v podman  >/dev/null 2>&1 && podman completion zsh      > "${XDG_CONFIG_HOME}/zsh/completions/_podman"  2>/dev/null || true

echo "Zsh configured"

# ============ tmux ==============================
echo "🖥️  Setting up Tmux..."
mkdir -p "$XDG_CONFIG_HOME/tmux"
ln -sf "${DOTFILES}/tmux/tmux.conf" "${XDG_CONFIG_HOME}/tmux/tmux.conf"
mkdir -p "$XDG_CONFIG_HOME/tmux/layouts"

for file in "${DOTFILES}/tmux/layouts/"*.sh; do
  ln -sf "$file" "${XDG_CONFIG_HOME}/tmux/layouts/"
done
echo "✅ Tmux configured"

# ============ nvim ==============================
echo "Setting up Neovim..."
git submodule update --init --recursive
rm -rf "${XDG_CONFIG_HOME}/nvim"
ln -snf "${DOTFILES}/nvim" "${XDG_CONFIG_HOME}/nvim"
echo "Neovim configured"

# ============ ptpython ==============================
echo "🐍 Setting up ptpython..."
mkdir -p "${HOME}/.config/ptpython"
ln -sf "${DOTFILES}/ptpython/config.py" "${HOME}/.config/ptpython/config.py"
echo "✅ ptpython configured"

# ============ niri ==============================
echo "Setting up Niri..."
mkdir -p "${XDG_CONFIG_HOME}/niri"
ln -sf "${DOTFILES}/niri/config.kdl" "${XDG_CONFIG_HOME}/niri/config.kdl"
echo "Niri configured"


# ============ environment.d ==============================
echo "Setting up environment.d..."
mkdir -p "${XDG_CONFIG_HOME}/environment.d"
ln -sf "${DOTFILES}/environment.d/defaults.conf" "${XDG_CONFIG_HOME}/environment.d/defaults.conf"
ln -sf "${DOTFILES}/environment.d/wayland.conf" "${XDG_CONFIG_HOME}/environment.d/wayland.conf"
echo "environment.d configured"

# ============ paru ==============================
echo "Setting up paru..."
mkdir -p "${XDG_CONFIG_HOME}/paru"
ln -sf "${DOTFILES}/paru/paru.conf" "${XDG_CONFIG_HOME}/paru/paru.conf"
echo "paru configured"

# ============ swaylock ==============================
echo "Setting up Swaylock..."
mkdir -p "${XDG_CONFIG_HOME}/swaylock"
ln -sf "${DOTFILES}/swaylock/config" "${XDG_CONFIG_HOME}/swaylock/config"
# NOTE: /etc/pam.d/swaylock (fingerprint + password unlock) is root-owned and
# installed separately by install-root.sh — see the closing note below.
echo "Swaylock configured"

# ============ glow ==============================
echo "Setting up Glow..."
mkdir -p "${XDG_CONFIG_HOME}/glow"
ln -sf "${DOTFILES}/glow/glow.yml" "${XDG_CONFIG_HOME}/glow/glow.yml"
echo "Glow configured"

# ============ mpv ==============================
echo "Setting up Mpv..."
mkdir -p "${XDG_CONFIG_HOME}/mpv"
ln -sf "${DOTFILES}/mpv/mpv.conf" "${XDG_CONFIG_HOME}/mpv/mpv.conf"
echo "Mpv configured"

# ============ yt-dlp ==============================
echo "Setting up yt-dlp..."
mkdir -p "${XDG_CONFIG_HOME}/yt-dlp"
ln -sf "${DOTFILES}/yt-dlp/config" "${XDG_CONFIG_HOME}/yt-dlp/config"
echo "yt-dlp configured"

# ============ cmus ==============================
echo "Setting up cmus..."
mkdir -p "${XDG_CONFIG_HOME}/cmus"
ln -sf "${DOTFILES}/cmus/rc" "${XDG_CONFIG_HOME}/cmus/rc"
echo "cmus configured"

# ============ direnv ==============================
echo "Setting up Direnv..."
mkdir -p "${XDG_CONFIG_HOME}/direnv"
ln -sf "${DOTFILES}/direnv/direnvrc" "${XDG_CONFIG_HOME}/direnv/direnvrc"
echo "Direnv configured"

# ============ uv ==============================
echo "Setting up uv..."
mkdir -p "${XDG_CONFIG_HOME}/uv"
ln -sf "${DOTFILES}/uv/uv.toml" "${XDG_CONFIG_HOME}/uv/uv.toml"
echo "uv configured"

# ============ gh ==============================
echo "Setting up GitHub CLI..."
mkdir -p "${XDG_CONFIG_HOME}/gh"
ln -sf "${DOTFILES}/gh/config.yml" "${XDG_CONFIG_HOME}/gh/config.yml"
echo "GitHub CLI configured"

# ripgrep-all is not configured here: rga writes its own config.jsonc (and
# schema) on first run, and every adapter we want is enabled by default.

# ============ neocmakelsp ==============================
# The trailing "-" in its [format] args is load-bearing: gersemi with no file
# operand exits 0 printing nothing, which neocmakelsp applies as a successful
# empty format and blanks the buffer. See the comments in the file itself.
echo "Setting up neocmakelsp..."
mkdir -p "${XDG_CONFIG_HOME}/neocmakelsp"
ln -sf "${DOTFILES}/neocmakelsp/config.toml" "${XDG_CONFIG_HOME}/neocmakelsp/config.toml"
echo "neocmakelsp configured"

# ============ mako ==============================
echo "Setting up mako..."
mkdir -p "${XDG_CONFIG_HOME}/mako"
ln -sf "${DOTFILES}/mako/config" "${XDG_CONFIG_HOME}/mako/config"
echo "mako configured"

# ============ vifm ==============================
echo "Setting up vifm..."
mkdir -p "${XDG_CONFIG_HOME}/vifm"
ln -sf "${DOTFILES}/vifm/vifmrc" "${XDG_CONFIG_HOME}/vifm/vifmrc"
mkdir -p "${XDG_CONFIG_HOME}/vifm/colors"
ln -sf "${DOTFILES}/vifm/colors/catppuccin-mocha.vifm" "${XDG_CONFIG_HOME}/vifm/colors/catppuccin-mocha.vifm"
ln -sf "${DOTFILES}/vifm/colors/zenburn-rich.vifm" "${XDG_CONFIG_HOME}/vifm/colors/zenburn-rich.vifm"
echo "vifm configured"

# ============ tridactyl ==============================
echo "Setting up tridactyl..."
mkdir -p "${XDG_CONFIG_HOME}/tridactyl"
ln -sf "${DOTFILES}/tridactyl/tridactylrc" "${XDG_CONFIG_HOME}/tridactyl/tridactylrc"
echo "tridactyl configured"

# ============ fuzzel ==============================
echo "Setting up Fuzzel..."
mkdir -p "${XDG_CONFIG_HOME}/fuzzel"
ln -sf "${DOTFILES}/fuzzel/fuzzel.ini" "${XDG_CONFIG_HOME}/fuzzel/fuzzel.ini"
echo "Fuzzel configured"

# ============ bat ==============================
echo "Setting up Bat..."
mkdir -p "${XDG_CONFIG_HOME}/bat"
ln -sf "${DOTFILES}/bat/config" "${XDG_CONFIG_HOME}/bat/config"
echo "Bat configured"

# ============ btop ==============================
echo "Setting up Btop..."
mkdir -p "${XDG_CONFIG_HOME}/btop"
ln -sf "${DOTFILES}/btop/btop.conf" "${XDG_CONFIG_HOME}/btop/btop.conf"
echo "Btop configured"

# ============ starship ==============================
echo "Setting up Starship..."
ln -sf "${DOTFILES}/starship.toml" "${XDG_CONFIG_HOME}/starship.toml"
echo "Starship configured"

# ============ foot terminal ==============================
echo "🦶 Setting up foot terminal..."
mkdir -p "${XDG_CONFIG_HOME}/foot"
ln -sf "${DOTFILES}/foot/foot.ini" "${XDG_CONFIG_HOME}/foot/foot.ini"
echo "✅ foot configured"

# ============ git ==============================
echo "Setting up Git..."
mkdir -p "${XDG_CONFIG_HOME}/git"
ln -sf "${DOTFILES}/git/config" "${XDG_CONFIG_HOME}/git/config"
ln -sf "${DOTFILES}/git/ignore" "${XDG_CONFIG_HOME}/git/ignore"
if [[ ! -f "${XDG_CONFIG_HOME}/git/config.local" ]]; then
    cat > "${XDG_CONFIG_HOME}/git/config.local" << 'GITLOCAL'
[user]
    name = Your Name
    email = you@example.com
GITLOCAL
    echo "  Created config.local template -- fill in your name and email"
fi
echo "Git configured"

# ============ lazygit ======================================
echo "Setting up lazygit..."
mkdir -p "${XDG_CONFIG_HOME}/lazygit"
ln -sf "${DOTFILES}/lazygit/config.yml" "${XDG_CONFIG_HOME}/lazygit/config.yml"
echo "Lazygit configured"

# ============ zathura ==============================
echo "Setting up Zathura..."
mkdir -p "${XDG_CONFIG_HOME}/zathura"
ln -sf "${DOTFILES}/zathura/zathurarc" "${XDG_CONFIG_HOME}/zathura/zathurarc"
echo "Zathura configured"

# ============ sioyek ==============================
echo "Setting up Sioyek..."
mkdir -p "${XDG_CONFIG_HOME}/sioyek"
ln -sf "${DOTFILES}/sioyek/prefs_user.config" "${XDG_CONFIG_HOME}/sioyek/prefs_user.config"
ln -sf "${DOTFILES}/sioyek/keys_user.config"  "${XDG_CONFIG_HOME}/sioyek/keys_user.config"
echo "Sioyek configured"

# ============ pcmanfm-qt ==============================
echo "Setting up pcmanfm-qt..."
mkdir -p "${XDG_CONFIG_HOME}/pcmanfm-qt/default"
ln -sf "${DOTFILES}/pcmanfm-qt/settings.conf" "${XDG_CONFIG_HOME}/pcmanfm-qt/default/settings.conf"
ln -sf "${DOTFILES}/pcmanfm-qt/bookmarks.xml"  "${XDG_CONFIG_HOME}/pcmanfm-qt/default/bookmarks.xml"
echo "pcmanfm-qt configured"

# ============ foliate ==============================
echo "Setting up Foliate..."
mkdir -p "${XDG_CONFIG_HOME}/com.github.johnfactotum.Foliate/themes"
for file in "${DOTFILES}/foliate/themes/"*.json; do
    ln -sf "$file" "${XDG_CONFIG_HOME}/com.github.johnfactotum.Foliate/themes/"
done
dconf load /com/github/johnfactotum/Foliate/ < "${DOTFILES}/foliate/settings.dconf"
echo "Foliate configured"

# ============ vimb ==============================
echo "Setting up vimb..."
mkdir -p "${XDG_CONFIG_HOME}/vimb"
ln -sf "${DOTFILES}/vimb/config" "${XDG_CONFIG_HOME}/vimb/config"
echo "vimb configured"

# ============ clangd ==============================
echo "Setting up Clangd..."
mkdir -p "${XDG_CONFIG_HOME}/clangd"
ln -sf "${DOTFILES}/clangd/config.yaml" "${XDG_CONFIG_HOME}/clangd/config.yaml"
echo "Clangd configured"

# ============ spotify-player ==============================
echo "Setting up spotify-player..."
mkdir -p "${XDG_CONFIG_HOME}/spotify-player"
ln -sf "${DOTFILES}/spotify-player/theme.toml" "${XDG_CONFIG_HOME}/spotify-player/theme.toml"
if [[ ! -f "${XDG_CONFIG_HOME}/spotify-player/app.toml" ]]; then
    cp "${DOTFILES}/spotify-player/app.toml" "${XDG_CONFIG_HOME}/spotify-player/app.toml"
    echo "  Created app.toml template -- fill in your client_id"
fi
echo "spotify-player configured"

# ============ handlr ==============================
echo "Setting up Handlr..."
mkdir -p "${XDG_CONFIG_HOME}/handlr"
ln -sf "${DOTFILES}/handlr/handlr.toml" "${XDG_CONFIG_HOME}/handlr/handlr.toml"
echo "Handlr configured"

# ============ ccache ==============================
echo "Setting up Ccache..."
mkdir -p "${XDG_CONFIG_HOME}/ccache"
ln -sf "${DOTFILES}/ccache/ccache.conf" "${XDG_CONFIG_HOME}/ccache/ccache.conf"
echo "Ccache configured"

# GTK appearance is not configured here: the xdg-desktop-portal Settings
# interface overrides gtk-{3,4}.0/settings.ini for every key it serves
# (font-name, gtk-theme, icon-theme, cursor-theme). Use dconf instead.

# ============ wob ==============================
echo "Setting up wob..."
mkdir -p "${XDG_CONFIG_HOME}/wob"
ln -sf "${DOTFILES}/wob/wob.ini" "${XDG_CONFIG_HOME}/wob/wob.ini"
echo "wob configured"


# ============ latexmk ==============================
echo "Setting up latexmk..."
mkdir -p "${XDG_CONFIG_HOME}/latexmk"
ln -sf "${DOTFILES}/latexmk/latexmkrc" "${XDG_CONFIG_HOME}/latexmk/latexmkrc"
echo "latexmk configured"


# ============ xdg user dirs ==============================
echo "Setting up XDG user dirs..."
ln -sf "${DOTFILES}/xdg/user-dirs.dirs" "${XDG_CONFIG_HOME}/user-dirs.dirs"

# Create the folders ourselves instead of calling xdg-user-dirs-update: when a
# listed folder is missing it rewrites user-dirs.dirs via rename(), which
# replaces the symlink above with a plain file. Mask the login-time unit for
# the same reason — the file is ours, nothing else may write it.
(
  # shellcheck source=xdg/user-dirs.dirs
  . "${DOTFILES}/xdg/user-dirs.dirs"
  for var in $(compgen -A variable XDG_ | grep '_DIR$'); do
    mkdir -p "${!var}"
  done
)
systemctl --user mask xdg-user-dirs.service >/dev/null 2>&1
echo "XDG user dirs configured"


# ============ mimeapps ==============================
echo "Setting up MIME associations..."
ln -sf "${DOTFILES}/mimeapps.list" "${XDG_CONFIG_HOME}/mimeapps.list"
echo "MIME associations configured"

# ============ desktop files ==============================
echo "Setting up desktop files..."
mkdir -p "${HOME}/.local/share/applications"
for file in "${DOTFILES}/applications/"*.desktop; do
    ln -sf "$file" "${HOME}/.local/share/applications/"
done
update-desktop-database "${HOME}/.local/share/applications/"
echo "Desktop files configured"

# ============ firefox ==============================
echo "Setting up Firefox userChrome..."
FIREFOX_PROFILE=$(awk -F= '/^\[Install/{in_install=1} in_install && /^Default=/{print $2; in_install=0}' "${HOME}/.mozilla/firefox/profiles.ini" 2>/dev/null)
if [[ -n "$FIREFOX_PROFILE" ]]; then
    CHROME_DIR="${HOME}/.mozilla/firefox/${FIREFOX_PROFILE}/chrome"
    mkdir -p "$CHROME_DIR"
    ln -sf "${DOTFILES}/firefox/userChrome.css" "${CHROME_DIR}/userChrome.css"
    echo "Firefox userChrome configured (profile: ${FIREFOX_PROFILE})"
else
    echo "Firefox default profile not found, skipping (install Firefox and run install.sh again)"
fi

# =========== duckdb ===============
echo "Setting up DuckDB..."
ln -sf "${DOTFILES}/duckdb/.duckdbrc" "${HOME}/.duckdbrc"
echo "DuckDB configured"

# No font step: the fonts in use (FiraCode Nerd Font, JetBrains Mono) come from
# packages. This used to copy 15MB of unreferenced Inconsolata/MesloLGS without
# running fc-cache, so fontconfig never saw them anyway.

# ============ audio directory ==============================
mkdir -p "${HOME}/Audio/Recordings"

# ============ helper scripts ==============================
echo "🛠️  Installing helper scripts..."
mkdir -p "${HOME}/.local/bin"
for file in "${DOTFILES}/bash/"*; do
  ln -sf "$file" "${HOME}/.local/bin/"
done
echo "✅ Helper scripts installed"

# ============ papis ==============================
echo "Setting up papis..."
mkdir -p "${XDG_CONFIG_HOME}/papis"
ln -sf "${DOTFILES}/papis/config" "${XDG_CONFIG_HOME}/papis/config"
echo "papis configured"

# ============ podman (rootless containers) ========================
# Quadlet .container/.network files generate systemd user units at daemon-reload.
# No sudo anywhere: rootless podman is entirely user-scoped, which is the point.
echo "📦 Installing podman configs..."
mkdir -p "${XDG_CONFIG_HOME}/containers/systemd"
ln -sf "${DOTFILES}/containers/containers.conf" "${XDG_CONFIG_HOME}/containers/containers.conf"
for file in "${DOTFILES}/containers/"*.container "${DOTFILES}/containers/"*.network; do
  [ -e "$file" ] || continue
  ln -sf "$file" "${XDG_CONFIG_HOME}/containers/systemd/"
done

# ============ systemd user services ==============================
echo "⚙️  Installing systemd user services..."
mkdir -p "${HOME}/.config/systemd/user"
for file in "${DOTFILES}/systemd/user/"*.service "${DOTFILES}/systemd/user/"*.timer; do
  [ -e "$file" ] || continue
  ln -sf "$file" "${HOME}/.config/systemd/user/"
done
systemctl --user daemon-reload

# Enable explicitly rather than globbing (idempotent). A glob gets this wrong in
# three ways: `enable rclone@.service` fails because a template cannot be
# enabled, the instances we actually mount are never enabled, and
# study-library-sync.service would be pulled into graphical-session.target even
# though its timer is what should drive it.
for unit in battery-watch mic-notify net-notify power-notify swayidle; do
  systemctl --user enable "${unit}.service" 2>/dev/null || true
done
for remote in gdrive Dropbox; do
  systemctl --user enable "rclone@${remote}.service" 2>/dev/null || true
done
systemctl --user enable study-library-sync.timer 2>/dev/null || true

# The *user* podman socket, which docker-compose reaches via DOCKER_HOST (see
# environment.d/defaults.conf). Without this a fresh install has DOCKER_HOST pointing at a
# socket nothing ever creates, and compose fails with no obvious cause. Never enable the
# system-wide podman.socket instead — that one is root-owned.
systemctl --user enable podman.socket 2>/dev/null || true
echo "✅ Systemd user services installed and enabled"

echo ""
echo "🎉 Dotfiles installation complete!"
echo ""
echo "Next steps:"
echo "  1. Install zsh plugins: ~/.config/zsh/update-plugins.sh"
echo "  2. Restart your terminal or run: source ~/.zshrc"
echo "  3. Install Vim plugins: vim +PlugInstall +qall"
echo "  4. Install tmux plugins: Prefix + I (inside a tmux session)"
# pg.service cannot start without this secret, and the only symptom is a failed unit.
# Only prompt when it is actually missing, so a re-run of install.sh stays quiet.
if command -v podman >/dev/null 2>&1 && ! podman secret exists pg_password 2>/dev/null; then
  echo "  5. Create the Postgres password (pg.service will not start without it):"
  echo "       podman secret create pg_password -      # type it, then Ctrl-D"
fi
echo ""
echo "🔐 System (root) configs are installed separately:"
echo "  sudo bash install-root.sh   - e.g. /etc/pam.d/swaylock (lock-screen auth)"
