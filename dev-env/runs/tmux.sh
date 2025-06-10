#!/usr/bin/env bash
set -euo pipefail

# Variables - change tmux version/branch if needed
TMUX_VERSION="3.5a" # Updated to latest stable
TMUX_BRANCH="3.5a"  # Git tag/branch to checkout
PREFIX="$HOME/.local"
INSTALL_DIR="$HOME/install"
SOURCE_DIR="$INSTALL_DIR/tmux"
JOBS=$(nproc)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
  echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
  echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running on supported system
if ! command -v apt &>/dev/null; then
  error "This script requires apt package manager (Debian/Ubuntu)"
  exit 1
fi

log "Installing tmux ${TMUX_VERSION} to ${PREFIX}"

# Update package list and install dependencies
log "Installing dependencies..."
sudo apt update
sudo apt install -y \
  libevent-dev \
  libncurses-dev \
  libutempter-dev \
  libsystemd-dev \
  libsixel-dev \
  libutf8proc-dev \
  build-essential \
  pkg-config \
  bison \
  autotools-dev \
  automake \
  git \
  wget \
  tar

# Create install directory and clone/update tmux repository
log "Setting up tmux source in ${SOURCE_DIR}..."
mkdir -p "$INSTALL_DIR"

if [[ -d "$SOURCE_DIR" ]]; then
  log "Existing tmux repository found, updating..."
  cd "$SOURCE_DIR"
  git fetch --all --tags
  git checkout "$TMUX_BRANCH"
  git pull origin "$TMUX_BRANCH" 2>/dev/null || true # May fail if it's a tag
else
  log "Cloning tmux repository..."
  cd "$INSTALL_DIR"
  git clone https://github.com/tmux/tmux.git
  cd "$SOURCE_DIR"
  git checkout "$TMUX_BRANCH"
fi

# Clean any previous build artifacts
log "Cleaning previous build artifacts..."
make clean 2>/dev/null || true
git clean -fdx 2>/dev/null || true

# Generate configure script if needed (for git builds)
if [[ ! -f configure ]]; then
  log "Generating configure script..."
  sh autogen.sh
fi

# Check if we can enable additional optimizations
log "Configuring build with optimizations..."

# Detect CPU architecture for optimization flags
ARCH=$(uname -m)
case $ARCH in
  x86_64)
    CFLAGS="-O3 -march=native -mtune=native -flto -fuse-linker-plugin"
    LDFLAGS="-flto -fuse-linker-plugin"
    ;;
  aarch64 | arm64)
    CFLAGS="-O3 -mcpu=native -flto -fuse-linker-plugin"
    LDFLAGS="-flto -fuse-linker-plugin"
    ;;
  *)
    CFLAGS="-O3 -flto"
    LDFLAGS="-flto"
    ;;
esac

# Configure with optimized flags
CFLAGS="$CFLAGS" LDFLAGS="$LDFLAGS" ./configure \
  --prefix="${PREFIX}" \
  --enable-sixel \
  --enable-utf8proc \
  --enable-systemd \
  --enable-utempter \
  --enable-static=no \
  --enable-shared=yes

log "Building tmux with ${JOBS} parallel jobs..."
make -j${JOBS}

log "Installing tmux..."
make install

# Clean up any existing tmux server/sockets to prevent conflicts
log "Cleaning up existing tmux sessions and sockets..."
tmux kill-server 2>/dev/null || true
rm -rf /tmp/tmux-* 2>/dev/null || true

log "Build completed successfully!"
log "Source code preserved in: ${SOURCE_DIR}"

# Update PATH if needed - detect shell and update appropriate config
SHELL_CONFIG=""
if [[ -n "${ZSH_VERSION:-}" ]] || [[ "$SHELL" == */zsh ]]; then
  SHELL_CONFIG="$HOME/.zshrc"
elif [[ -n "${BASH_VERSION:-}" ]] || [[ "$SHELL" == */bash ]]; then
  SHELL_CONFIG="$HOME/.bashrc"
else
  # Fallback - try to detect from $SHELL
  case "$SHELL" in
    */zsh) SHELL_CONFIG="$HOME/.zshrc" ;;
    */bash) SHELL_CONFIG="$HOME/.bashrc" ;;
    *) SHELL_CONFIG="$HOME/.profile" ;; # Universal fallback
  esac
fi

if [[ -n "$SHELL_CONFIG" ]] && ! grep -q 'export PATH="$HOME/.local/bin:$PATH"' "$SHELL_CONFIG" 2>/dev/null; then
  echo 'export PATH="$HOME/.local/bin:$PATH"' >>"$SHELL_CONFIG"
  warn "Added ~/.local/bin to PATH in $SHELL_CONFIG"
  warn "Please reload your shell or run 'source $SHELL_CONFIG'"
fi

# Verify installation
if "${PREFIX}/bin/tmux" -V &>/dev/null; then
  INSTALLED_VERSION=$("${PREFIX}/bin/tmux" -V)
  log "Successfully installed: ${INSTALLED_VERSION}"
  log "Location: ${PREFIX}/bin/tmux"

  # Test if tmux can actually start
  log "Testing tmux startup..."
  if "${PREFIX}/bin/tmux" new-session -d -s test-session 'echo "test"' 2>/dev/null; then
    "${PREFIX}/bin/tmux" kill-session -t test-session 2>/dev/null
    log "tmux startup test: PASSED"
  else
    error "tmux startup test: FAILED"
    warn "Run the following command to debug:"
    warn "  ${PREFIX}/bin/tmux -v new-session"
  fi
else
  error "Installation verification failed"
  exit 1
fi

log "Installation complete! Run 'tmux -V' to verify."
log ""
log "To uninstall tmux later, run:"
log "  cd ${SOURCE_DIR} && make uninstall"
log ""
log "To rebuild with different options:"
log "  cd ${SOURCE_DIR} && git checkout <branch/tag> && ./build.sh"
