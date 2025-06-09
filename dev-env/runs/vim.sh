#!/usr/bin/env bash

echo "script to install vim"
set -e # Exit on error

# ===== Configuration =====
# INSTALL_PREFIX="/usr/local"
# VIM_VERSION="9.1" # Check latest at https://github.com/vim/vim/tags
PYTHON_CONFIG="$(command -v python3-config)"
# COMPILED_BY="Farhad Mani" # Your name here
INSTALL_FORLDER="${HOME}/install/vim"
# Install required dependencies
sudo apt update
sudo apt install -y \
  build-essential ncurses-dev python3-dev python3-venv git curl libtool libtool-bin autoconf automake cmake g++ pkg-config unzip \
  libx11-dev libxt-dev wl-clipboard libncursesw5-dev llvm shellcheck shfmt

# Clone Vim source code
git clone --depth 1 https://github.com/vim/vim.git "${INSTALL_FORLDER}"
cd "${INSTALL_FORLDER}/src"
# Configure with optimal flags
./configure --prefix="/usr/local/" \
  --with-features=normal \
  --enable-terminal \
  --enable-python3interp=dynamic \
  --enable-cscope \
  --with-tlib=ncursesw \
  --enable-multibyte \
  --with-x \
  --disable-gui \
  --enable-fail-if-missing \
  --with-compiledby="Farhad" \
  PYTHON3_CONFIG="${PYTHON_CONFIG}" \
  CFLAGS="-O2 -march=native" \
  LDFLAGS="-Wl,-s"

# Build and install
make "-j$(nproc)" || true
sudo make install

# Verify key features
echo "verify the installation"
vim --version | grep -E '\+(clipboard|xterm_clipboard|python3|terminal)' || true

echo "Install plugin manager"
curl -fLo ~/.vim/autoload/plug.vim --create-dirs \
  https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim
vim -E -u ~/.vimrc +PlugInstall +qa

# colorscheme installation

echo "Add one dark as the colorsheme"
# Define target paths
VIM_COLORS="${HOME}/.vim/colors"
VIM_AUTOLOAD="${HOME}/.vim/autoload"
LIGHTLINE_SCHEME="${HOME}/.vim/autoload/lightline/colorscheme"

# Create required directories
mkdir -p "${VIM_COLORS}"
mkdir -p "${VIM_AUTOLOAD}"
mkdir -p "${LIGHTLINE_SCHEME}"

# Download the main onedark colorscheme
echo "Downloading onedark.vim color scheme..."
curl -fsSL -o "${VIM_COLORS}/onedark.vim" \
  https://raw.githubusercontent.com/joshdick/onedark.vim/main/colors/onedark.vim

# Download the autoload support file
echo "Downloading autoload/onedark.vim..."
curl -fsSL -o "${VIM_AUTOLOAD}/onedark.vim" \
  https://raw.githubusercontent.com/joshdick/onedark.vim/main/autoload/onedark.vim

# Download the lightline colorscheme
echo "Downloading Lightline onedark theme..."
curl -fsSL -o "${LIGHTLINE_SCHEME}/onedark.vim" \
  https://raw.githubusercontent.com/joshdick/onedark.vim/main/autoload/lightline/colorscheme/onedark.vim

echo "Installation complete."
echo "Remember to set the colorscheme and Lightline theme manually in your .vimrc:"
echo ""
echo "    colorscheme onedark"
echo "    let g:lightline = { 'colorscheme': 'onedark' }"
echo ""
