#!/bin/bash
# vim
ln -sf "$HOME/dotfiles/vim/.vimrc" "$HOME/.vimrc"
# zsh
ln -sf "$HOME/dotfiles/zsh/.zshenv" "$HOME"
ln -sf "$HOME/dotfiles/zsh/.zshrc" "$HOME/.zshrc"
mkdir -p "$HOME/.config/ptpython"
ln -sf "$HOME/dotfiles/ptpython/config.py" "$HOME/.config/ptpython/config.py"
