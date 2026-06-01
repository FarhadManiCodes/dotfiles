#!/bin/bash
# Updated install.sh for XDG-compliant zsh setup
# provide default values for environment variable if not defined
: "${XDG_CONFIG_HOME:=${HOME}/.config}"
: "${DOTFILES:=${HOME}/dotfiles}"
: "${XDG_DATA_HOME:=${HOME}/.config/local/share}"

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

# Symlink entire vim config directory
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
command -v docker  >/dev/null 2>&1 && docker completion zsh      > "${XDG_CONFIG_HOME}/zsh/completions/_docker"  2>/dev/null || true

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
ln -sf "${DOTFILES}/nvim" "${XDG_CONFIG_HOME}/nvim"
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

# ============ gh ==============================
echo "Setting up GitHub CLI..."
mkdir -p "${XDG_CONFIG_HOME}/gh"
ln -sf "${DOTFILES}/gh/config.yml" "${XDG_CONFIG_HOME}/gh/config.yml"
echo "GitHub CLI configured"

# ============ ripgrep-all ==============================
echo "Setting up ripgrep-all..."
mkdir -p "${XDG_CONFIG_HOME}/ripgrep-all"
ln -sf "${DOTFILES}/ripgrep-all/config.jsonc" "${XDG_CONFIG_HOME}/ripgrep-all/config.jsonc"
echo "ripgrep-all configured"

# ============ wireplumber ==============================
echo "Setting up wireplumber..."
mkdir -p "${XDG_CONFIG_HOME}/wireplumber/wireplumber.conf.d"
ln -sf "${DOTFILES}/wireplumber/wireplumber.conf.d/50-disable-acp.conf" "${XDG_CONFIG_HOME}/wireplumber/wireplumber.conf.d/50-disable-acp.conf"
ln -sf "${DOTFILES}/wireplumber/wireplumber.conf.d/99-alsa-channels.conf" "${XDG_CONFIG_HOME}/wireplumber/wireplumber.conf.d/99-alsa-channels.conf"
echo "wireplumber configured"

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
ln -sf "${DOTFILES}/applications/vifm.desktop" "${XDG_DATA_HOME}/applications/vifm.desktop"
ln -sf "${DOTFILES}/bash/vifm-open" "${HOME}/.local/bin/vifm-open"
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

# ============ gtk ==============================
echo "Setting up GTK..."
mkdir -p "${XDG_CONFIG_HOME}/gtk-3.0" "${XDG_CONFIG_HOME}/gtk-4.0"
ln -sf "${DOTFILES}/gtk-3.0/settings.ini" "${XDG_CONFIG_HOME}/gtk-3.0/settings.ini"
ln -sf "${DOTFILES}/gtk-4.0/settings.ini" "${XDG_CONFIG_HOME}/gtk-4.0/settings.ini"
echo "GTK configured"

# ============ wob ==============================
echo "Setting up wob..."
mkdir -p "${XDG_CONFIG_HOME}/wob"
ln -sf "${DOTFILES}/wob/wob.ini" "${XDG_CONFIG_HOME}/wob/wob.ini"
echo "wob configured"


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

#########
# Fonts #
#########
echo "🔤 Installing fonts..."
mkdir -p "${XDG_DATA_HOME}"
cp -rf "${DOTFILES}/fonts" "${XDG_DATA_HOME}"
echo "✅ Fonts installed"

# ============ audio directory ==============================
mkdir -p "${HOME}/Audio/Recordings"

# ============ helper scripts ==============================
echo "🛠️  Installing helper scripts..."
mkdir -p "${HOME}/.local/bin"
for file in "${DOTFILES}/bash/"*; do
  ln -sf "$file" "${HOME}/.local/bin/"
done
echo "✅ Helper scripts installed"

# ============ systemd user services ==============================
echo "⚙️  Installing systemd user services..."
mkdir -p "${HOME}/.config/systemd/user"
for file in "${DOTFILES}/systemd/user/"*.service; do
  ln -sf "$file" "${HOME}/.config/systemd/user/"
done
systemctl --user daemon-reload
# Enable each unit so it actually starts on graphical-session (idempotent).
for file in "${DOTFILES}/systemd/user/"*.service; do
  systemctl --user enable "$(basename "$file")" 2>/dev/null || true
done
echo "✅ Systemd user services installed and enabled"

echo ""
echo "🎉 Dotfiles installation complete!"
echo ""
echo "⚠️  Note: For the new zsh setup, you'll need to install themes and plugins:"
echo "    Run the migration script or manually install e.g.:"
echo "    • Powerlevel10k: git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ~/.config/zsh/themes/powerlevel10k"
echo "    • Fast syntax highlighting: git clone https://github.com/zdharma-continuum/fast-syntax-highlighting.git ~/.config/zsh/plugins/fast-syntax-highlighting"
echo ""
echo "Next steps:"
echo "  1. Install zsh themes/plugins (see above)"
echo "  2. Restart your terminal or run: source ~/.zshrc"
echo "  3. Install Vim plugins: vim +PlugInstall +qall"
echo "  4. Install tmux plugins: Prefix + I (if using tpm)"
echo ""
echo "💡 Useful commands:"
echo "  zsh-info        - Show loaded zsh features"
echo "  zsh-benchmark   - Test shell startup performance"
echo "  tmux-new        - Start new tmux session"
echo "  va              - Activate virtual environment"
echo ""
echo "🔐 System (root) configs are installed separately:"
echo "  sudo bash install-root.sh   - e.g. /etc/pam.d/swaylock (lock-screen auth)"
