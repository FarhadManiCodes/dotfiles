#!/bin/bash

# Simple Foot Terminal Installation Script
# Based on working PGO configuration

set -e # Exit on error

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Simple logging
log() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() {
  echo -e "${RED}[ERROR]${NC} $1"
  exit 1
}

# Default configuration
INSTALL_DIR="${INSTALL_DIR:-$HOME/install}"
PREFIX="${PREFIX:-/usr/local}"
USE_PGO="${USE_PGO:-yes}"
#BRANCH="${BRANCH:-1.22.3}" # Default to stable version
BRANCH=1.22.3
# Detect distribution
detect_distro() {
  if [ -f /etc/os-release ]; then
    . /etc/os-release
    DISTRO="$ID"
  elif [ -f /etc/lsb-release ]; then
    . /etc/lsb-release
    DISTRO="${DISTRIB_ID,,}"
  else
    DISTRO="unknown"
  fi
}

# Install dependencies
install_dependencies() {
  log "Installing dependencies..."

  case "$DISTRO" in
    ubuntu | debian)
      sudo apt update
      sudo apt install -y \
        git meson ninja-build pkg-config cmake \
        libwayland-dev libwayland-cursor0 wayland-protocols \
        libxkbcommon-dev libfontconfig1-dev libfreetype6-dev \
        libpixman-1-dev libfcft-dev libutf8proc-dev \
        ncurses-term ncurses-bin \
        scdoc gzip \
        libsystemd-dev \
        gcc g++ \
        libharfbuzz-dev \
        libxml2-dev \
        libpng-dev \
        libtllist-dev || true
      ;;

    fedora | rhel | centos)
      sudo dnf install -y \
        git meson ninja-build pkg-config cmake \
        wayland-devel wayland-protocols-devel \
        libxkbcommon-devel fontconfig-devel freetype-devel \
        pixman-devel fcft-devel utf8proc-devel \
        ncurses ncurses-term \
        scdoc gzip \
        systemd-devel \
        gcc gcc-c++ \
        harfbuzz-devel \
        libxml2-devel \
        libpng-devel \
        tllist-devel || true
      ;;

    arch | manjaro)
      sudo pacman -Syu --noconfirm
      sudo pacman -S --noconfirm \
        git meson ninja pkg-config cmake \
        wayland wayland-protocols \
        libxkbcommon fontconfig freetype2 \
        pixman fcft libutf8proc \
        ncurses \
        scdoc gzip \
        systemd \
        gcc \
        harfbuzz \
        libxml2 \
        libpng \
        tllist || true
      ;;

    *)
      warn "Unknown distribution: $DISTRO"
      warn "Please install dependencies manually:"
      warn "- Build tools: git, meson, ninja, pkg-config, cmake, gcc"
      warn "- Wayland: wayland-dev, wayland-protocols"
      warn "- Libraries: xkbcommon, fontconfig, freetype, pixman, fcft, utf8proc"
      warn "- Terminal: ncurses, ncurses-term"
      warn "- Documentation: scdoc"
      read -p "Continue anyway? (y/N): " -n 1 -r
      echo
      if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
      fi
      ;;
  esac
}

# Show configuration
log "Foot Terminal Installation"
log "=========================="
log "Install directory: $INSTALL_DIR"
log "Prefix: $PREFIX"
log "PGO: $USE_PGO"
log "Version: $BRANCH"
echo

# Detect distribution and install dependencies
detect_distro
log "Detected distribution: $DISTRO"
read -p "Install dependencies? (Y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Nn]$ ]]; then
  install_dependencies
fi

# Create install directory
mkdir -p "$INSTALL_DIR"
cd "$INSTALL_DIR"

# Clone or update repository
if [ -d "foot" ]; then
  log "Updating existing repository..."
  cd foot
  git fetch --all --tags
else
  log "Cloning foot repository..."
  git clone --recursive https://codeberg.org/dnkl/foot.git
  cd foot
fi

# Checkout to specific version
if [ "$BRANCH" != "master" ]; then
  log "Checking out version $BRANCH..."
  git checkout "$BRANCH" || {
    warn "Could not checkout $BRANCH, trying with tags/"
    git checkout "tags/$BRANCH" || {
      warn "Version $BRANCHnot found, using master"
      git checkout master
      git pull origin master
    }
  }
else
  log "Using master branch..."
  git checkout master
  git pull origin master
fi

# Update submodules
git submodule update --init --recursive

# Clean previous builds
log "Cleaning previous builds..."
rm -rf build pgo-data

# Build
if [ "$USE_PGO" = "yes" ] && [ -f "./pgo/pgo.sh" ]; then
  log "Building with PGO..."
  ./pgo/pgo.sh auto . build \
    --prefix="$PREFIX" \
    -Db_lto=true \
    -Dime=true \
    -Dc_args="-O3 -march=native -mtune=native -flto=auto -pipe -fno-plt -fomit-frame-pointer" \
    -Dcpp_args="-O3 -march=native -mtune=native -flto=auto -pipe -fno-plt -fomit-frame-pointer"
else
  log "Building without PGO..."
  meson setup build \
    --prefix="$PREFIX" \
    -Dbuildtype=release \
    -Db_lto=true \
    -Dime=true \
    -Dc_args="-O3 -march=native -mtune=native -flto=auto -pipe -fno-plt -fomit-frame-pointer" \
    -Dcpp_args="-O3 -march=native -mtune=native -flto=auto -pipe -fno-plt -fomit-frame-pointer"

  ninja -C build
fi

# Install
log "Installing..."
if [ -w "$PREFIX" ]; then
  ninja -C build install
else
  sudo ninja -C build install
fi

# Update terminfo
log "Updating terminfo..."
if command -v tic &>/dev/null; then
  if [ -f "build/terminfo/foot.info" ]; then
    sudo tic -xe foot,foot-direct "build/terminfo/foot.info" || warn "Failed to update terminfo"
  elif [ -f "terminfo/foot.info" ]; then
    sudo tic -xe foot,foot-direct "terminfo/foot.info" || warn "Failed to update terminfo"
  else
    warn "Could not find terminfo file"
  fi
fi

# Install desktop files
if [ -d "$HOME/.local/share/applications" ]; then
  log "Installing desktop files..."
  for file in foot.desktop foot-server.desktop; do
    [ -f "$file" ] && cp "$file" "$HOME/.local/share/applications/"
    [ -f "build/$file" ] && cp "build/$file" "$HOME/.local/share/applications/"
  done
fi

# Install shell completions
install_completions() {
  # Bash
  if [ -n "$BASH_VERSION" ] && [ -d "$HOME/.local/share/bash-completion/completions" ]; then
    mkdir -p "$HOME/.local/share/bash-completion/completions"
    [ -f "completions/bash/foot" ] && cp "completions/bash/foot" "$HOME/.local/share/bash-completion/completions/"
    [ -f "completions/bash/footclient" ] && cp "completions/bash/footclient" "$HOME/.local/share/bash-completion/completions/"
  fi

  # Zsh
  if command -v zsh &>/dev/null && [ -d "$HOME/.local/share/zsh/site-functions" ]; then
    mkdir -p "$HOME/.local/share/zsh/site-functions"
    [ -f "completions/zsh/_foot" ] && cp "completions/zsh/_foot" "$HOME/.local/share/zsh/site-functions/"
    [ -f "completions/zsh/_footclient" ] && cp "completions/zsh/_footclient" "$HOME/.local/share/zsh/site-functions/"
  fi

  # Fish
  if command -v fish &>/dev/null; then
    mkdir -p "$HOME/.config/fish/completions"
    [ -f "completions/fish/foot.fish" ] && cp "completions/fish/foot.fish" "$HOME/.config/fish/completions/"
    [ -f "completions/fish/footclient.fish" ] && cp "completions/fish/footclient.fish" "$HOME/.config/fish/completions/"
  fi
}

log "Installing shell completions..."
install_completions

# Setup config
if [ ! -f "$HOME/.config/foot/foot.ini" ]; then
  log "Setting up configuration..."
  mkdir -p "$HOME/.config/foot"
  if [ -f "foot.ini" ]; then
    cp foot.ini "$HOME/.config/foot/foot.ini"
  elif [ -f "docs/foot.ini" ]; then
    cp docs/foot.ini "$HOME/.config/foot/foot.ini"
  fi
fi

# Install themes
if [ -d "themes" ]; then
  log "Installing themes..."
  mkdir -p "$HOME/.config/foot/themes"
  cp -r themes/* "$HOME/.config/foot/themes/" 2>/dev/null || true
fi

# Verify installation
if command -v foot &>/dev/null; then
  log "Installation successful!"
  foot --version
else
  warn "foot not found in PATH. You may need to add $PREFIX/bin to your PATH"
fi

log "Done!"
log ""
log "Tips:"
log "- Configuration: ~/.config/foot/foot.ini"
log "- Themes: ~/.config/foot/themes/"
log "- Server mode: foot --server"
log "- Client: footclient"

# Ask to clean build directory
read -p "Remove build directory? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  cd "$INSTALL_DIR"
  rm -rf foot
  log "Build directory removed."
fi
