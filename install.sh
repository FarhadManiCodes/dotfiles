#!/bin/bash
# vim
ln -sf "$HOME/dotfiles/vim/.vimrc" "$HOME/.vimrc"
# zsh
mkdir -p "$HOME/.config/zsh"
ln -sf "$HOME/dotfiles/zsh/.zshenv" "$HOME/.zshenv"
ln -sf "$HOME/dotfiles/zsh/.zshrc" "$HOME/.zshrc"
ln -sf "$HOME/dotfiles/zsh/aliases" "$HOME/.config/zsh/aliases"
# tmux
mkdir -p "$XDG_CONFIG_HOME/tmux"
ln -sf "$DOTFILES/tmux/tmux.conf" "$XDG_CONFIG_HOME/tmux/tmux.conf"

# ptpyhthon
mkdir -p "$HOME/.config/ptpython"
ln -sf "$HOME/dotfiles/ptpython/config.py" "$HOME/.config/ptpython/config.py"
