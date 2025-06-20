#!/bin/bash

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() { echo -e "${GREEN}[INFO]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
info() { echo -e "${BLUE}[PERF]${NC} $1"; }

# Configuration
INSTALL_DIR="$HOME/install"
FZF_DIR="$INSTALL_DIR/fzf"

# Check prerequisites
[ "$EUID" -eq 0 ] && error "Do not run as root. Run as regular user."
command -v go >/dev/null 2>&1 || error "Go not found. Install Go first."
command -v git >/dev/null 2>&1 || error "git not found: sudo apt install git"
command -v make >/dev/null 2>&1 || error "make not found: sudo apt install build-essential"

# Check existing fzf
check_existing_fzf() {
    if [ -d "$FZF_DIR" ] && [ -x "$FZF_DIR/bin/fzf" ]; then
        local current_version=$("$FZF_DIR/bin/fzf" --version 2>/dev/null | cut -d' ' -f1 || echo "unknown")
        log "Found existing fzf: $current_version"
        read -p "Reinstall? (y/N): " -n 1 -r
        echo; [[ ! $REPLY =~ ^[Yy]$ ]] && exit 0
    fi
}

# Function to get latest fzf tag
get_latest_fzf_tag() {
    # Try GitHub API first
    if command -v curl >/dev/null 2>&1; then
        tag=$(curl -s https://api.github.com/repos/junegunn/fzf/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        [ -n "$tag" ] && echo "$tag" && return
    fi
    
    # Fallback to git ls-remote
    tag=$(git ls-remote --tags --sort=-v:refname https://github.com/junegunn/fzf.git | grep -Eo 'refs/tags/[0-9.]+$' | sort -V | tail -1 | cut -d'/' -f3)
    [ -n "$tag" ] && echo "$tag" && return
    
    # Final fallback
    echo "0.48.1"  # Known recent stable version
}

# Install fzf with optimized build settings
install_fzf() {
    log "Installing fzf with aggressive optimizations..."
    
    [ -d "$FZF_DIR" ] && rm -rf "$FZF_DIR"
    
    # Get latest stable tag
    log "Finding latest stable release..."
    latest_tag=$(get_latest_fzf_tag)
    [ -z "$latest_tag" ] && latest_tag="0.48.1"
    log "Using version: $latest_tag"
    
    # Clone specific tag
    git clone --depth 1 --branch "$latest_tag" https://github.com/junegunn/fzf.git "$FZF_DIR" || error "Clone failed"
    
    cd "$FZF_DIR"
    
    # Verify modern integration support
    export CGO_ENABLED=0
    export GOGC=off      # Disable garbage collection during build
    export GODEBUG=gctrace=0
    
    # Aggressive optimization flags
    go build -trimpath \
        -ldflags="-s -w -X main.version=$latest_tag" \
        -gcflags="all=-dwarf=false -l=4 -B -wb=false" \
        -asmflags="all=-trimpath=$GOPATH" \
        -buildmode=exe \
        -o bin/fzf || error "Build failed"
    
    unset GOGC GODEBUG  # Reset environment variables
    
    "./bin/fzf" --help | grep -q "\-\-zsh" || error "fzf doesn't support modern integration"
    
    local size=$(stat -c%s "bin/fzf" 2>/dev/null || echo "unknown")
    local size_mb=$(echo "scale=1; $size / 1024 / 1024" | bc -l 2>/dev/null || echo "unknown")
    info "Built fzf $latest_tag (${size_mb}MB, static binary, optimized)"
}

# Create management scripts
create_scripts() {
    mkdir -p "$INSTALL_DIR"
    
    # Installation log
    cat > "$INSTALL_DIR/fzf-install.log" << EOF
INSTALL_DIR=$INSTALL_DIR
FZF_DIR=$FZF_DIR
INSTALL_DATE=$(date -Iseconds)
VERSION=$latest_tag
EOF
    
    # Update script
    cat > "$INSTALL_DIR/update-fzf.sh" << 'EOF'
#!/bin/bash
set -e

FZF_DIR="$HOME/install/fzf"
[ ! -d "$FZF_DIR" ] && { echo "fzf not found"; exit 1; }

# Function to get latest fzf tag
get_latest_fzf_tag() {
    # Try GitHub API first
    if command -v curl >/dev/null 2>&1; then
        tag=$(curl -s https://api.github.com/repos/junegunn/fzf/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
        [ -n "$tag" ] && echo "$tag" && return
    fi
    
    # Fallback to git ls-remote
    tag=$(git ls-remote --tags --sort=-v:refname https://github.com/junegunn/fzf.git | grep -Eo 'refs/tags/[0-9.]+$' | sort -V | tail -1 | cut -d'/' -f3)
    [ -n "$tag" ] && echo "$tag" && return
    
    # Final fallback
    echo "0.48.1"
}

cd "$FZF_DIR"
current=$(./bin/fzf --version 2>/dev/null | cut -d' ' -f1 || echo "unknown")
echo "Current: $current"

# Get latest tag
latest_tag=$(get_latest_fzf_tag)
[ -z "$latest_tag" ] && latest_tag="0.48.1"
echo "Latest: $latest_tag"

[ "$current" = "$latest_tag" ] && { echo "Already up to date"; exit 0; }

# Fetch and checkout new version
git fetch origin tag "$latest_tag" --depth=1 || { echo "Fetch failed"; exit 1; }
git checkout -f "$latest_tag" || { echo "Checkout failed"; exit 1; }

# Aggressive optimization flags
export CGO_ENABLED=0
export GOGC=off
export GODEBUG=gctrace=0

echo "Building $latest_tag..."
go build -trimpath \
    -ldflags="-s -w -X main.version=$latest_tag" \
    -gcflags="all=-dwarf=false -l=4 -B -wb=false" \
    -asmflags="all=-trimpath=$GOPATH" \
    -buildmode=exe \
    -o bin/fzf

unset GOGC GODEBUG
echo "Updated to $latest_tag"
EOF
    
    # Uninstall script
    cat > "$INSTALL_DIR/uninstall-fzf.sh" << 'EOF'
#!/bin/bash
set -e

INSTALL_DIR="$HOME/install"
LOG_FILE="$INSTALL_DIR/fzf-install.log"

if [ -f "$LOG_FILE" ]; then
    FZF_DIR=$(grep "FZF_DIR=" "$LOG_FILE" | cut -d'=' -f2)
else
    FZF_DIR="$INSTALL_DIR/fzf"
fi

[ -d "$FZF_DIR" ] && rm -rf "$FZF_DIR" && echo "Removed fzf"
rm -f "$INSTALL_DIR/fzf-install.log" "$INSTALL_DIR/update-fzf.sh" "$INSTALL_DIR/uninstall-fzf.sh"
echo "fzf uninstalled"
EOF
    
    chmod +x "$INSTALL_DIR/update-fzf.sh" "$INSTALL_DIR/uninstall-fzf.sh"
    log "Management scripts created"
}

# Test installation
test_install() {
    if "$FZF_DIR/bin/fzf" --version >/dev/null 2>&1; then
        local version=$("$FZF_DIR/bin/fzf" --version | cut -d' ' -f1)
        log "Verified: $version"
    else
        error "Installation verification failed"
    fi
}

# Main installation
main() {
    log "fzf installer (Optimized Build)"
    
    check_existing_fzf
    install_fzf
    create_scripts
    test_install
    
    echo ""
    log "✅ fzf installed successfully!"
    info "Location: $FZF_DIR/bin/fzf"
    echo ""
    info "Management commands:"
    echo "  • Update: $INSTALL_DIR/update-fzf.sh"
    echo "  • Uninstall: $INSTALL_DIR/uninstall-fzf.sh"
    echo ""
    warn "MANUAL CONFIGURATION REQUIRED:"
    warn "Add the configuration snippets below to your dotfiles"
}

main
