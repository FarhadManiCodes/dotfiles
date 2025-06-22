#!/bin/bash
# Updated install.sh for XDG-compliant zsh setup
# provide default values for environment variable if not defined
: "${XDG_CONFIG_HOME:=${HOME}/.config}"
: "${DOTFILES:=${HOME}/dotfiles}"
: "${XDG_DATA_HOME:=${HOME}/.config/local/share}"

echo "🚀 Installing dotfiles..."

# =========== vim ===============
echo "🔧 Setting up Vim..."
ln -sf "${HOME}/dotfiles/vim/.vimrc" "${HOME}/.vimrc"
ln -sf "${HOME}/dotfiles/vim/vimrc" "${HOME}/.vim/vimrc"

mkdir -p "${HOME}/.vim/config"
ln -sf "${HOME}/dotfiles/vim/config/basic.vim" "${HOME}/.vim/config/basic.vim"
ln -sf "${HOME}/dotfiles/vim/config/plugins.vim" "${HOME}/.vim/config/plugins.vim"
ln -sf "${HOME}/dotfiles/vim/config/plugins_config.vim" "${HOME}/.vim/config/plugins_config.vim"
ln -sf "${HOME}/dotfiles/vim/config/mappings.vim" "${HOME}/.vim/config/mappings.vim"
ln -sf "${HOME}/dotfiles/vim/config/autocmds.vim" "${HOME}/.vim/config/autocmds.vim"
ln -sf "${HOME}/dotfiles/vim/config/autopairs.vim" "${HOME}/.vim/config/autopairs.vim"

# Language-specific configurations
ln -sf "${HOME}/dotfiles/vim/config/python.vim" "${HOME}/.vim/config/python.vim"
ln -sf "${HOME}/dotfiles/vim/config/sql.vim" "${HOME}/.vim/config/sql.vim"
ln -sf "${HOME}/dotfiles/vim/config/json.vim" "${HOME}/.vim/config/json.vim"
ln -sf "${HOME}/dotfiles/vim/config/yaml.vim" "${HOME}/.vim/config/yaml.vim"
ln -sf "${HOME}/dotfiles/vim/config/vimscript.vim" "${HOME}/.vim/config/vimscript.vim"
echo "✅ Vim configured"

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
  gh completion -s zsh > "${HOME}/.config/zsh/completions/_gh" 2>/dev/null || true
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

# ============ ptpython ==============================
echo "🐍 Setting up ptpython..."
mkdir -p "${HOME}/.config/ptpython"
ln -sf "${HOME}/dotfiles/ptpython/config.py" "${HOME}/.config/ptpython/config.py"
echo "✅ ptpython configured"

# ============ foot terminal ==============================
echo "🦶 Setting up foot terminal..."
mkdir -p "${XDG_CONFIG_HOME}/foot"
ln -sf "${HOME}/dotfiles/foot/foot.ini" "${XDG_CONFIG_HOME}/foot/foot.ini"
echo "✅ foot configured"

# ============ git ==============================
echo "🌿 Setting up Git..."
ln -sf "${HOME}/dotfiles/git/.gitconfig" "${HOME}/.gitconfig"
echo "✅ Git configured"

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
