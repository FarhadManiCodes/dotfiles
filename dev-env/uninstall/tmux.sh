#!/usr/bin/env bash
set -euo pipefail

# Variables
PREFIX="$HOME/.local"
SOURCE_DIR="$HOME/install/tmux"

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

# Check if tmux source directory exists
if [[ ! -d "$SOURCE_DIR" ]]; then
  error "tmux source directory not found at: $SOURCE_DIR"
  error "Cannot perform clean uninstall"
  exit 1
fi

# Check if tmux is currently running
if pgrep -x tmux >/dev/null; then
  warn "tmux is currently running. You may want to kill all sessions first:"
  warn "  tmux kill-server"
  echo
  read -p "Continue with uninstall anyway? [y/N]: " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log "Uninstall cancelled"
    exit 0
  fi
fi

log "Uninstalling tmux from ${PREFIX}..."

# Change to source directory and run make uninstall
cd "$SOURCE_DIR"
if make uninstall; then
  log "tmux uninstalled successfully"
else
  error "make uninstall failed, trying manual cleanup..."

  # Manual cleanup
  rm -f "${PREFIX}/bin/tmux"
  rm -f "${PREFIX}/share/man/man1/tmux.1"
  log "Manual cleanup completed"
fi

# Ask if user wants to remove source directory
echo
read -p "Remove source directory ${SOURCE_DIR}? [y/N]: " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
  rm -rf "$SOURCE_DIR"
  log "Source directory removed"
else
  log "Source directory preserved at: $SOURCE_DIR"
fi

# Check if ~/.local/bin should be removed from PATH - detect shell config
SHELL_CONFIG=""
if [[ -n "${ZSH_VERSION:-}" ]] || [[ "$SHELL" == */zsh ]]; then
  SHELL_CONFIG="$HOME/.zshrc"
elif [[ -n "${BASH_VERSION:-}" ]] || [[ "$SHELL" == */bash ]]; then
  SHELL_CONFIG="$HOME/.bashrc"
else
  # Try to detect from $SHELL
  case "$SHELL" in
    */zsh) SHELL_CONFIG="$HOME/.zshrc" ;;
    */bash) SHELL_CONFIG="$HOME/.bashrc" ;;
    *) SHELL_CONFIG="$HOME/.profile" ;;
  esac
fi

if [[ -n "$SHELL_CONFIG" ]] && [[ -f "$SHELL_CONFIG" ]] && grep -q 'export PATH="$HOME/.local/bin:$PATH"' "$SHELL_CONFIG"; then
  echo
  read -p "Remove ~/.local/bin from PATH in $SHELL_CONFIG? [y/N]: " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    sed -i '/export PATH="\$HOME\/\.local\/bin:\$PATH"/d' "$SHELL_CONFIG"
    log "Removed ~/.local/bin from PATH in $SHELL_CONFIG"
    warn "Please reload your shell or run 'source $SHELL_CONFIG'"
  fi
fi

log "tmux uninstall completed!"
