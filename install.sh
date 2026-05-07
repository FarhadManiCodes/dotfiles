#!/bin/bash
# Updated install.sh for XDG-compliant zsh setup
# provide default values for environment variable if not defined
: "${XDG_CONFIG_HOME:=${HOME}/.config}"
: "${DOTFILES:=${HOME}/dotfiles}"
: "${XDG_DATA_HOME:=${HOME}/.config/local/share}"

echo "🚀 Installing dotfiles..."

# =========== vim ===============
echo "Setting up Vim..."
mkdir -p "${XDG_CONFIG_HOME}/vim/config"

# Bootstrap ~/.vimrc to redirect vim to the XDG config location
cat > "${HOME}/.vimrc" << 'VIMRC'
" XDG compliance: delegate to ~/.config/vim/vimrc
let $MYVIMRC = expand('~/.config/vim/vimrc')
source ~/.config/vim/vimrc
VIMRC

# Symlink the main vimrc and all config modules
ln -sf "${DOTFILES}/vim/vimrc" "${XDG_CONFIG_HOME}/vim/vimrc"
for file in "${DOTFILES}/vim/config/"*.vim; do
    ln -sf "$file" "${XDG_CONFIG_HOME}/vim/config/"
done
echo "Vim configured"

# ============ zsh ==============================
echo "🐚 Setting up Zsh..."
mkdir -p "${HOME}/.config/zsh"
ln -sf "${HOME}/dotfiles/zsh/.zshenv" "${HOME}/.zshenv"
ln -sf "${HOME}/dotfiles/zsh/.zshrc" "${HOME}/.zshrc"
ln -sf "${HOME}/dotfiles/zsh/aliases" "${HOME}/.config/zsh/aliases"

# Create completions directory for custom completions
mkdir -p "${HOME}/.config/zsh/completions"

# Generate GitHub CLI completions if available
if command -v gh >/dev/null 2>&1; then
  echo "📝 Generating GitHub CLI completions..."
  gh completion -s zsh >"${HOME}/.config/zsh/completions/_gh" 2>/dev/null || true
fi

echo "✅ Zsh configured"

# ============ tmux ==============================
echo "🖥️  Setting up Tmux..."
mkdir -p "$XDG_CONFIG_HOME/tmux"
ln -sf "${HOME}/dotfiles/tmux/tmux.conf" "${XDG_CONFIG_HOME}/tmux/tmux.conf"
mkdir -p "$XDG_CONFIG_HOME/tmux/layouts"

for file in "${HOME}/dotfiles/tmux/layouts/"*.sh; do
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
ln -sf "${HOME}/dotfiles/ptpython/config.py" "${HOME}/.config/ptpython/config.py"
echo "✅ ptpython configured"

# ============ niri ==============================
echo "Setting up Niri..."
mkdir -p "${XDG_CONFIG_HOME}/niri"
ln -sf "${DOTFILES}/niri/config.kdl" "${XDG_CONFIG_HOME}/niri/config.kdl"
echo "Niri configured"

# ============ waybar ==============================
echo "Setting up Waybar..."
mkdir -p "${XDG_CONFIG_HOME}/waybar"
ln -sf "${DOTFILES}/waybar/config" "${XDG_CONFIG_HOME}/waybar/config"
ln -sf "${DOTFILES}/waybar/style.css" "${XDG_CONFIG_HOME}/waybar/style.css"
echo "Waybar configured"

# ============ mako ==============================
echo "Setting up Mako..."
mkdir -p "${XDG_CONFIG_HOME}/mako"
ln -sf "${DOTFILES}/mako/config" "${XDG_CONFIG_HOME}/mako/config"
echo "Mako configured"

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
ln -sf "${HOME}/dotfiles/foot/foot.ini" "${XDG_CONFIG_HOME}/foot/foot.ini"
echo "✅ foot configured"

# ============ git ==============================
echo " Setting up Git..."
ln -sf "${HOME}/dotfiles/git/.gitconfig" "${HOME}/.gitconfig"
echo "✅ Git configured"

# ============ lazygit ======================================
echo "Setting up lazygit..."
mkdir -p "${XDG_CONFIG_HOME}/lazygit"
ln -sf "${HOME}/dotfiles/lazygit/config.yml" "${XDG_CONFIG_HOME}/lazygit/config.yml"
echo "Lazygit configured"

# =========== duckdb ===============
echo "Setting up DuckDB""
ln -sf "${HOME}/dotfiles/duckdb/.duckdbrc" "${HOME}/.duckdbrc"

#########
# Fonts #
#########
echo "🔤 Installing fonts..."
mkdir -p "${XDG_DATA_HOME}"
cp -rf "${DOTFILES}/fonts" "${XDG_DATA_HOME}"
echo "✅ Fonts installed"

# ============ helper scripts ==============================
echo "🛠️  Installing helper scripts..."
mkdir -p "${HOME}/.local/bin"
for file in "${HOME}/dotfiles/bash/"*; do
  ln -sf "$file" "${HOME}/.local/bin/"
done
echo "✅ Helper scripts installed"

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
