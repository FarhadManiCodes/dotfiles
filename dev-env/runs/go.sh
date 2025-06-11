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
GO_VERSION="1.23.4"
GO_INSTALL_DIR="/usr/local"

# Require dotfiles - no fallback
if [ -z "$DOTFILES" ] || [ ! -d "$DOTFILES" ]; then
    error "DOTFILES environment variable must be set and directory must exist.
Current DOTFILES: ${DOTFILES:-"not set"}
Directory exists: $([ -d "$DOTFILES" ] && echo "yes" || echo "no")"
fi

log "Using dotfiles: $DOTFILES"
SHELL_RC="$DOTFILES/zsh/.zshenv"

# Check prerequisites
[ "$EUID" -ne 0 ] && error "Run with sudo: sudo $0"

# Detect architecture
get_arch() {
    case "$(uname -m)" in
        x86_64) echo "amd64" ;;
        aarch64|arm64) echo "arm64" ;;
        armv7l) echo "armv6l" ;;
        *) error "Unsupported architecture: $(uname -m)" ;;
    esac
}

# Check existing Go installation
check_existing_go() {
    if command -v go >/dev/null 2>&1; then
        local current_version=$(go version | cut -d' ' -f3 | sed 's/go//')
        if [ "$current_version" = "$GO_VERSION" ]; then
            log "Go ${GO_VERSION} already installed"
            read -p "Reinstall? (y/N): " -n 1 -r
            echo; [[ ! $REPLY =~ ^[Yy]$ ]] && exit 0
        else
            log "Upgrading Go $current_version → $GO_VERSION"
        fi
    fi
}

# Install Go
install_go() {
    local arch=$(get_arch)
    local tarball="go${GO_VERSION}.linux-${arch}.tar.gz"
    local url="https://golang.org/dl/${tarball}"
    
    log "Installing Go ${GO_VERSION} for ${arch}..."
    
    [ -d "${GO_INSTALL_DIR}/go" ] && rm -rf "${GO_INSTALL_DIR}/go"
    
    cd /tmp
    wget -q --show-progress --timeout=30 --tries=3 "${url}" || error "Download failed"
    
    local size=$(stat -c%s "${tarball}" 2>/dev/null || echo "0")
    [ "$size" -lt 50000000 ] && error "Download incomplete"
    
    tar -C "${GO_INSTALL_DIR}" -xzf "${tarball}" || error "Extraction failed"
    chmod -R 755 "${GO_INSTALL_DIR}/go"
    rm -f "${tarball}"
    
    info "Go ${GO_VERSION} installed ($(du -sh ${GO_INSTALL_DIR}/go | cut -f1))"
}

# Setup environment
setup_go_env() {
    local regular_user="${SUDO_USER:-$USER}"
    local user_home=$(eval echo ~$regular_user)
    local user_dotfiles=$(sudo -u "$regular_user" bash -c 'echo $DOTFILES')
    
    # Use explicit DOTFILES from sudo context
    SHELL_RC="$DOTFILES/zsh/.zshenv"
    SCRIPTS_RC="$DOTFILES/zsh/scripts.sh"
    
    sudo -u "$regular_user" mkdir -p "$(dirname "$SHELL_RC")"
    sudo -u "$regular_user" mkdir -p "$(dirname "$SCRIPTS_RC")"
    sudo -u "$regular_user" touch "$SHELL_RC" "$SCRIPTS_RC"
    
    # Check/remove existing config from both files
    if grep -q "# Go PATH\|GOPATH" "$SHELL_RC" "$SCRIPTS_RC" 2>/dev/null; then
        warn "Go config exists. Replace? (y/N): "
        read -n 1 -r; echo
        [[ ! $REPLY =~ ^[Yy]$ ]] && return 0
        sed -i '/# Go PATH/d;/go\/bin/d;/GOPROXY/d;/GOSUMDB/d;/GOPATH/d;/CGO_ENABLED/d' "$SHELL_RC"
        sed -i '/# Go/d;/cargo/d' "$SCRIPTS_RC"
    fi
    
    # Add Go environment variables to .zshenv (available to all shells)
    cat >> "$SHELL_RC" << EOF

# Go PATH and environment
export PATH=\$PATH:${GO_INSTALL_DIR}/go/bin
export GOPROXY=https://proxy.golang.org,direct
export GOSUMDB=sum.golang.org
export GOPATH=\$HOME/go
export CGO_ENABLED=0
EOF
    
    # Add Go interactive features to scripts.sh
    cat >> "$SCRIPTS_RC" << 'EOF'

# Go interactive features
# Add any Go-specific shell functions or aliases here
# Example: alias gob='go build'
EOF
    
    sudo -u "$regular_user" mkdir -p "$user_home/go"/{bin,src,pkg}
    log "Go environment configured:"
    log "  • Variables: $SHELL_RC"
    log "  • Interactive: $SCRIPTS_RC"
}

# Create management scripts
create_scripts() {
    local regular_user="${SUDO_USER:-$USER}"
    local user_home=$(eval echo ~$regular_user)
    local install_dir="$user_home/install"
    
    sudo -u "$regular_user" mkdir -p "$install_dir"
    
    # Installation log
    cat > "$install_dir/go-install.log" << EOF
GO_VERSION=$GO_VERSION
GO_INSTALL_DIR=$GO_INSTALL_DIR
SHELL_RC=$SHELL_RC
DOTFILES=$DOTFILES
INSTALL_DATE=$(date -Iseconds)
EOF
    
    # Update script
    cat > "$install_dir/update-go.sh" << 'EOF'
#!/bin/bash
set -e
[ "$EUID" -ne 0 ] && { echo "Run with sudo"; exit 1; }

LOG_FILE="$HOME/install/go-install.log"
[ ! -f "$LOG_FILE" ] && { echo "Go install log not found"; exit 1; }

GO_INSTALL_DIR=$(grep "GO_INSTALL_DIR=" "$LOG_FILE" | cut -d'=' -f2)
CURRENT=$(grep "GO_VERSION=" "$LOG_FILE" | cut -d'=' -f2)
LATEST=$(curl -s https://api.github.com/repos/golang/go/tags | grep '"name":' | head -1 | cut -d'"' -f4 | sed 's/go//')

[ "$CURRENT" = "$LATEST" ] && { echo "Already up to date: $CURRENT"; exit 0; }

echo "Updating Go $CURRENT → $LATEST"

case "$(uname -m)" in x86_64) ARCH="amd64";; aarch64|arm64) ARCH="arm64";; *) echo "Unsupported arch"; exit 1;; esac

cd /tmp
wget -q --show-progress "https://golang.org/dl/go${LATEST}.linux-${ARCH}.tar.gz"
rm -rf "${GO_INSTALL_DIR}/go"
tar -C "${GO_INSTALL_DIR}" -xzf "go${LATEST}.linux-${ARCH}.tar.gz"
chmod -R 755 "${GO_INSTALL_DIR}/go"
sed -i "s/GO_VERSION=.*/GO_VERSION=$LATEST/" "$LOG_FILE"
rm -f "go${LATEST}.linux-${ARCH}.tar.gz"

echo "Updated to Go $LATEST"
EOF
    
    # Uninstall script
    cat > "$install_dir/uninstall-go.sh" << 'EOF'
#!/bin/bash
set -e
[ "$EUID" -ne 0 ] && { echo "Run with sudo"; exit 1; }

USER_HOME=$(eval echo ~${SUDO_USER:-$USER})
LOG_FILE="$USER_HOME/install/go-install.log"

if [ -f "$LOG_FILE" ]; then
    GO_INSTALL_DIR=$(grep "GO_INSTALL_DIR=" "$LOG_FILE" | cut -d'=' -f2)
    SHELL_RC=$(grep "SHELL_RC=" "$LOG_FILE" | cut -d'=' -f2)
else
    GO_INSTALL_DIR="/usr/local"
    SHELL_RC="${DOTFILES:-$USER_HOME/.dotfiles}/zsh/.zshenv"
fi

[ -d "$GO_INSTALL_DIR/go" ] && rm -rf "$GO_INSTALL_DIR/go" && echo "Removed Go installation"

if [ -f "$SHELL_RC" ]; then
    sed -i '/# Go PATH/d;/go\/bin/d;/GOPROXY/d;/GOSUMDB/d;/GOPATH/d;/CGO_ENABLED/d' "$SHELL_RC"
    echo "Removed Go config from $SHELL_RC"
fi

read -p "Remove ~/go directory? (y/N): " -n 1 -r; echo
[[ $REPLY =~ ^[Yy]$ ]] && rm -rf "$USER_HOME/go" && echo "Removed GOPATH"

rm -f "$USER_HOME/install/go-install.log" "$USER_HOME/install/update-go.sh" "$USER_HOME/install/uninstall-go.sh"
echo "Go uninstalled"
EOF
    
    chmod +x "$install_dir/update-go.sh" "$install_dir/uninstall-go.sh"
    chown "$regular_user:$(id -gn $regular_user)" "$install_dir/"*
    log "Management scripts created in $install_dir/"
}

# Test installation
test_install() {
    if "${GO_INSTALL_DIR}/go/bin/go" version >/dev/null 2>&1; then
        local version=$("${GO_INSTALL_DIR}/go/bin/go" version | cut -d' ' -f3)
        log "Verified: $version"
    else
        error "Installation verification failed"
    fi
}

# Main installation
main() {
    log "Go installer (Dotfiles Mode) - $DOTFILES/zsh/"
    
    apt-get update -qq
    apt-get install -y --no-install-recommends wget ca-certificates bc
    
    check_existing_go
    install_go
    setup_go_env
    create_scripts
    test_install
    
    echo ""
    log "✅ Go ${GO_VERSION} installed successfully!"
    warn "Restart terminal or: source $SCRIPTS_RC"
    echo ""
    info "Configuration:"
    echo "  • Environment: $SHELL_RC"
    echo "  • Interactive: $SCRIPTS_RC" 
    echo ""
    info "Commands:"
    echo "  • Test: go version"
    echo "  • Update: sudo DOTFILES=\"\$DOTFILES\" ~/install/update-go.sh"
    echo "  • Uninstall: sudo DOTFILES=\"\$DOTFILES\" ~/install/uninstall-go.sh"
}

main
