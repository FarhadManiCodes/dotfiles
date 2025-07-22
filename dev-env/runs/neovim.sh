#!/usr/bin/env bash

echo "Neovim Installation Script - Aggressive Optimizations + Bundled Dependencies"
set -e # Exit on error

# ===== Configuration =====
INSTALL_PREFIX="/usr/local"
INSTALL_FOLDER="${HOME}/install/neovim"
BUILD_TYPE="Release"

# CPU-specific optimizations
CPU_ARCH=$(uname -m)
if [[ "$CPU_ARCH" == "x86_64" ]] || [[ "$CPU_ARCH" == "aarch64" ]]; then
    # Force -O3 + CPU optimizations (override Neovim's conservative -O2)
    OPTIMIZATION_FLAGS="-O3 -march=native -mtune=native -DNDEBUG"
    echo "🚀 Installing Neovim with AGGRESSIVE CPU-optimized build ($CPU_ARCH)"
    echo "⚡ Forcing -O3 (overriding Neovim's conservative -O2 default)"
else
    OPTIMIZATION_FLAGS="-O3 -DNDEBUG"
    echo "🚀 Installing Neovim with aggressive optimizations"
fi

echo "🚀 Installing Neovim with bundled dependencies"
echo "📦 Install prefix: $INSTALL_PREFIX"
echo "🔧 Build type: $BUILD_TYPE (with aggressive optimizations)"
echo "⚡ Flags: $OPTIMIZATION_FLAGS"
echo ""

# ===== Install ONLY Essential Dependencies =====
echo "📋 Installing ONLY essential dependencies..."
sudo apt update

sudo apt install -y \
    build-essential \
    cmake \
    ninja-build \
    git \
    curl \
    gettext \
    pkg-config \
    unzip

echo "✅ Installed 8 essential packages only!"
echo ""

# ===== Download Neovim Source =====
echo "📥 Getting Neovim source..."
if [ -d "$INSTALL_FOLDER" ]; then
    echo "🔄 Updating existing repository..."
    cd "$INSTALL_FOLDER"
    git fetch --tags
else
    git clone https://github.com/neovim/neovim.git "$INSTALL_FOLDER"
    cd "$INSTALL_FOLDER"
fi

# Get latest stable release
echo "🏷️  Finding latest stable release..."
LATEST_STABLE=$(git tag -l 'v[0-9]*.[0-9]*.[0-9]*' | grep -v 'rc\|alpha\|beta' | sort -V | tail -n1)
echo "📌 Using version: $LATEST_STABLE"
git checkout "$LATEST_STABLE"

# ===== Build with Bundled Dependencies =====
echo "🔨 Building Neovim..."
echo "📦 Using bundled dependencies (Neovim will download everything)"
echo "⚡ Optimizations: $OPTIMIZATION_FLAGS"

# Clean any previous builds
make distclean 2>/dev/null || true

# Force our optimization flags (override Neovim's -O2 default)
export CFLAGS="$OPTIMIZATION_FLAGS"
export CXXFLAGS="$OPTIMIZATION_FLAGS"

# Use the official Neovim Makefile method for bundled builds
make CMAKE_BUILD_TYPE="$BUILD_TYPE" \
     CMAKE_INSTALL_PREFIX="$INSTALL_PREFIX" \
     -j$(nproc)

echo "✅ Build completed!"

# ===== Install =====
echo "📦 Installing Neovim..."
sudo make install

# Verify nvim is accessible
if ! command -v nvim &> /dev/null; then
    sudo ln -sf "$INSTALL_PREFIX/bin/nvim" /usr/local/bin/nvim
fi

# ===== Verify Installation =====
echo "✅ Verifying installation..."
nvim --version | head -n 3

# ===== Setup Configuration =====
echo "📁 Setting up Neovim configuration..."
NVIM_CONFIG="$HOME/.config/nvim"
mkdir -p "$NVIM_CONFIG"

if [ ! -f "$NVIM_CONFIG/init.lua" ]; then
    cat > "$NVIM_CONFIG/init.lua" << 'EOF'
-- Basic Neovim Configuration
vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.expandtab = true
vim.opt.tabstop = 4
vim.opt.shiftwidth = 4
vim.opt.smartindent = true
vim.opt.hlsearch = true
vim.opt.incsearch = true
vim.opt.termguicolors = true
vim.opt.clipboard = "unnamedplus"
vim.opt.splitright = true
vim.opt.splitbelow = true
vim.opt.undofile = true

vim.g.mapleader = " "

print("🎉 Neovim ready! Time to add your plugins!")
EOF
    echo "📝 Created basic init.lua"
fi

# ===== Install Plugin Manager =====
echo "🔌 Installing lazy.nvim plugin manager..."
LAZY_PATH="$HOME/.local/share/nvim/lazy/lazy.nvim"
if [ ! -d "$LAZY_PATH" ]; then
    git clone --filter=blob:none https://github.com/folke/lazy.nvim.git --branch=stable "$LAZY_PATH"
fi

echo ""
echo "🎉 INSTALLATION COMPLETE!"
echo ""
echo "📊 Summary:"
echo "├── Version: $(nvim --version | head -n1)"
echo "├── Location: $INSTALL_PREFIX/bin/nvim"
echo "├── Config: $NVIM_CONFIG/init.lua"
echo "├── Plugin manager: lazy.nvim"
echo "├── Dependencies: Bundled (self-contained)"
echo "├── Optimizations: $OPTIMIZATION_FLAGS"
echo "└── Architecture: $CPU_ARCH"
echo ""
echo "🚀 Next Steps:"
echo "1. Run: nvim"
echo "2. Migrate your Vim config to ~/.config/nvim/"
echo "3. Add plugins with lazy.nvim"
echo ""
echo "🛠️ Optional tools (install later if needed):"
echo "   sudo apt install python3-pip nodejs npm ripgrep fd-find wl-clipboard"
echo ""
echo "💡 Test: nvim --version"
