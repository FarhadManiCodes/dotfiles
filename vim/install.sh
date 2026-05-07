#!/usr/bin/env bash
#
# Vim Installation Script
# Installs vim configuration to XDG-compliant location (~/.config/vim/)
#

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Target locations
VIM_CONFIG_DIR="$HOME/.config/vim"
VIMRC="$HOME/.vimrc"

echo -e "${BLUE}=== Vim Configuration Installer ===${NC}"
echo -e "${BLUE}XDG-compliant installation using directory symlink${NC}\n"

# Function to backup existing files/directories
backup_if_exists() {
    local path="$1"
    local name=$(basename "$path")

    if [ -L "$path" ]; then
        echo -e "${YELLOW}⚠  Removing existing symlink: $path${NC}"
        rm "$path"
        return 0
    elif [ -e "$path" ]; then
        local backup="$path.backup.$(date +%Y%m%d_%H%M%S)"
        echo -e "${YELLOW}⚠  Backing up existing $name: $backup${NC}"
        mv "$path" "$backup"
        return 0
    fi
    return 1
}

# Backup existing vim config if needed
echo -e "${BLUE}Checking for existing vim configuration...${NC}"
backup_if_exists "$VIM_CONFIG_DIR" || true
backup_if_exists "$VIMRC" || true
echo ""

# Create directory symlink
echo -e "${BLUE}Creating XDG config directory symlink...${NC}"
ln -s "$SCRIPT_DIR" "$VIM_CONFIG_DIR"
echo -e "${GREEN}✓  Created symlink: ~/.config/vim → $SCRIPT_DIR${NC}\n"

# Create ~/.vimrc loader
echo -e "${BLUE}Creating ~/.vimrc loader...${NC}"
cat > "$VIMRC" << 'EOF'
" XDG Base Directory Specification compliance
" This file sources the actual vimrc from ~/.config/vim/vimrc

" Set vim config directory
let $MYVIMRC = expand('~/.config/vim/vimrc')

" Source the actual vimrc
if filereadable($MYVIMRC)
    source $MYVIMRC
else
    echoerr "Could not find vimrc at ~/.config/vim/vimrc"
endif
EOF
echo -e "${GREEN}✓  Created ~/.vimrc (sources ~/.config/vim/vimrc)${NC}\n"

# Create undo directory
echo -e "${BLUE}Creating undo directory...${NC}"
mkdir -p "$HOME/.vim/undodir"
echo -e "${GREEN}✓  Created ~/.vim/undodir${NC}\n"

# Check if vim-plug is installed
echo -e "${BLUE}Checking vim-plug installation...${NC}"
VIM_PLUG_PATH="$HOME/.vim/autoload/plug.vim"
if [ ! -f "$VIM_PLUG_PATH" ]; then
    echo -e "${YELLOW}⚠  vim-plug not found, installing...${NC}"
    curl -fLo "$VIM_PLUG_PATH" --create-dirs \
        https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
    echo -e "${GREEN}✓  Installed vim-plug${NC}\n"
else
    echo -e "${GREEN}✓  vim-plug already installed${NC}\n"
fi

# Summary
echo -e "${GREEN}=== Installation Complete! ===${NC}\n"
echo -e "${BLUE}Configuration structure:${NC}"
echo -e "  ~/.vimrc                 → Loader (sources XDG config)"
echo -e "  ~/.config/vim/           → ${YELLOW}Symlink to $SCRIPT_DIR${NC}"
echo -e "  ~/.vim/undodir/          → Undo history storage"
echo -e "  ~/.vim/autoload/plug.vim → vim-plug plugin manager\n"

echo -e "${BLUE}Benefits:${NC}"
echo -e "  ✓ XDG-compliant (config in ~/.config/vim)"
echo -e "  ✓ All edits in $SCRIPT_DIR"
echo -e "  ✓ Changes automatically tracked in git\n"

echo -e "${BLUE}Next steps:${NC}"
echo -e "  1. Install plugins:     ${YELLOW}vim +PlugInstall +qall${NC}"
echo -e "  2. Test vim:            ${YELLOW}vim test.md${NC}"
echo -e "  3. Clean old plugins:   ${YELLOW}vim +PlugClean +qall${NC}\n"

echo -e "${BLUE}Active plugins (12):${NC}"
echo -e "  • Editing:      auto-pairs, vim-surround, tcomment, vim-repeat, vim-unimpaired"
echo -e "  • UI:           lightline, onedark, PaperColor"
echo -e "  • Writing:      vim-markdown, Goyo, Limelight"
echo -e "  • Integration:  vim-tmux-navigator, rainbow_csv, vim-envx\n"

echo -e "${GREEN}Happy editing! 🚀${NC}"
