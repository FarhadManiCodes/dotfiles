#!/bin/bash
# provide default values for environment variable if not defined
: "${XDG_CONFIG_HOME:=${HOME}/.config}"
: "${DOTFILES:=${HOME}/dotfiles}"
: "${XDG_DATA_HOME:=${HOME}/.config/local/share}"
# =========== vim ===============
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

# ============ zsh ==============================
mkdir -p "${HOME}/.config/zsh"
ln -sf "${HOME}/dotfiles/zsh/.zshenv" "${HOME}/.zshenv"
ln -sf "${HOME}/dotfiles/zsh/.zshrc" "${HOME}/.zshrc"
ln -sf "${HOME}/dotfiles/zsh/aliases" "${HOME}/.config/zsh/aliases"
# tmux
mkdir -p "$XDG_CONFIG_HOME/tmux"
ln -sf "${HOME}/dotfiles/tmux/tmux.conf" "${XDG_CONFIG_HOME}/tmux/tmux.conf"
mkdir -p "$XDG_CONFIG_HOME/tmux/layouts"

for file in "${HOME}/dotfiles/tmux/layouts/"*.sh; do
  ln -sf "$file" "${XDG_CONFIG_HOME}/tmux/layouts/"
done

# ptpyhthon
mkdir -p "${HOME}/.config/ptpython"
ln -sf "${HOME}/dotfiles/ptpython/config.py" "${HOME}/.config/ptpython/config.py"

# foot terminal
mkdir -p "${XDG_CONFIG_HOME}/foot"
ln -sf "${HOME}/dotfiles/foot/foot.ini" "${XDG_CONFIG_HOME}/foot/foot.ini"
#########
# Fonts #
#########
mkdir -p "${XDG_DATA_HOME}"
cp -rf "${DOTFILES}/fonts" "${XDG_DATA_HOME}"

# other help functions
for file in "${HOME}/dotfiles/bash/"*; do
  ln -sf "$file" "${HOME}/.local/bin/"
done
