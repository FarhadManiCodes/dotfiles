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
ZLUA_DIR="$INSTALL_DIR/z.lua"

# Require explicit DOTFILES
[ -z "$DOTFILES" ] || [ ! -d "$DOTFILES" ] && error "DOTFILES must be set: DOTFILES=\"\$DOTFILES\" $0"
SHELL_RC="$DOTFILES/zsh/.zshenv"
SCRIPTS_RC="$DOTFILES/zsh/scripts.sh"
ALIASES_RC="$DOTFILES/zsh/aliases"

# Check prerequisites
[ "$EUID" -eq 0 ] && error "Do not run as root. Run as regular user."
command -v git >/dev/null 2>&1 || error "git not found: sudo apt install git"

# Check for Lua (z.lua works with multiple Lua implementations)
check_lua() {
    local lua_found=false
    local lua_version=""
    
    for lua_cmd in lua lua5.4 lua5.3 lua5.2 lua5.1 luajit; do
        if command -v "$lua_cmd" >/dev/null 2>&1; then
            lua_version=$("$lua_cmd" -v 2>&1 | head -1 || echo "unknown")
            log "Found Lua: $lua_version"
            lua_found=true
            break
        fi
    done
    
    if [ "$lua_found" = false ]; then
        warn "No Lua interpreter found. Installing lua5.4..."
        read -p "Install Lua? (Y/n): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            sudo apt-get update -qq
            sudo apt-get install -y lua5.4
            log "Lua5.4 installed successfully"
        else
            error "Lua is required for z.lua"
        fi
    fi
}

# Check existing z.lua
check_existing_zlua() {
    if [ -d "$ZLUA_DIR" ] && [ -f "$ZLUA_DIR/z.lua" ]; then
        log "Found existing z.lua installation"
        read -p "Reinstall? (y/N): " -n 1 -r
        echo; [[ ! $REPLY =~ ^[Yy]$ ]] && exit 0
    fi
}

# Install z.lua
install_zlua() {
    log "Installing z.lua with optimizations..."
    
    [ -d "$ZLUA_DIR" ] && rm -rf "$ZLUA_DIR"
    
    git clone --depth 1 https://github.com/skywind3000/z.lua.git "$ZLUA_DIR" || error "Clone failed"
    
    cd "$ZLUA_DIR"
    local commit=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
    
    # Test z.lua works
    if lua z.lua --help >/dev/null 2>&1; then
        info "z.lua installed successfully (commit: $commit)"
    else
        error "z.lua installation test failed"
    fi
}

# Setup shell integration
setup_shell_integration() {
    log "Setting up z.lua integration (split config)..."
    
    mkdir -p "$(dirname "$SHELL_RC")" "$(dirname "$SCRIPTS_RC")" "$(dirname "$ALIASES_RC")"
    touch "$SHELL_RC" "$SCRIPTS_RC" "$ALIASES_RC"
    
    # Check/remove existing config
    if grep -q "# z.lua\|_ZL_" "$SHELL_RC" "$SCRIPTS_RC" "$ALIASES_RC" 2>/dev/null; then
        warn "z.lua config exists. Replace? (y/N): "
        read -n 1 -r; echo
        [[ ! $REPLY =~ ^[Yy]$ ]] && return 0
        sed -i '/# z\.lua/d;/_ZL_/d;/z\.lua/d;/alias z/d' "$SHELL_RC" "$SCRIPTS_RC" "$ALIASES_RC"
    fi
    
    # Add z.lua environment variables to .zshenv
    cat >> "$SHELL_RC" << EOF

# z.lua configuration (environment variables)
export _ZL_CMD=z
export _ZL_DATA="\$HOME/.zlua"
export _ZL_NO_PROMPT_COMMAND=1
export _ZL_EXCLUDE_DIRS="\$HOME/.cache,/tmp,/var/tmp,/usr/share"
export _ZL_ADD_ONCE=1
export _ZL_MAXAGE=5000
export _ZL_CD=cd
EOF
    
    # Add z.lua shell integration to scripts.sh
    cat >> "$SCRIPTS_RC" << EOF

# z.lua shell integration (interactive features)
eval "\$(lua $ZLUA_DIR/z.lua --init zsh enhanced once echo fzf)"
EOF
    
    # Add z.lua aliases to aliases file
    cat >> "$ALIASES_RC" << EOF

# z.lua aliases
alias zz='z -c'      # restrict matches to subdirs of \$PWD
alias zi='z -i'      # cd with interactive selection
alias zf='z -I'      # use fzf to select in multiple matches
alias zb='z -b'      # quickly cd to the parent directory
alias zh='z -I -t .' # fzf + time sort
alias zd='z -d'      # match only directories
alias zr='z -r'      # match by rank only
EOF
    
    log "z.lua integration configured:"
    log "  • Environment (.zshenv): configuration variables"
    log "  • Interactive (scripts.sh): shell integration"
    log "  • Aliases (aliases): z.lua command shortcuts"
    log "  • Enhanced mode: better matching algorithm"
    log "  • fzf integration: interactive selection with fzf"
}

# Create management scripts
create_scripts() {
    mkdir -p "$INSTALL_DIR"
    
    # Installation log
    cat > "$INSTALL_DIR/zlua-install.log" << EOF
INSTALL_DIR=$INSTALL_DIR
ZLUA_DIR=$ZLUA_DIR
SHELL_RC=$SHELL_RC
SCRIPTS_RC=$SCRIPTS_RC
ALIASES_RC=$ALIASES_RC
DOTFILES=$DOTFILES
INSTALL_DATE=$(date -Iseconds)
LUA_VERSION=$(lua -v 2>&1 | head -1 || echo "unknown")
EOF
    
    # Update script
    cat > "$INSTALL_DIR/update-z.lua.sh" << 'EOF'
#!/bin/bash
set -e

ZLUA_DIR="$HOME/install/z.lua"
[ ! -d "$ZLUA_DIR" ] && { echo "z.lua not found"; exit 1; }

cd "$ZLUA_DIR"
current=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
echo "Current commit: $current"

git pull origin master
latest=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")

[ "$current" = "$latest" ] && { echo "Already up to date"; exit 0; }

echo "Updated to commit: $latest"
lua z.lua --help >/dev/null 2>&1 && echo "z.lua verified" || echo "Verification failed"
EOF
    
    # Uninstall script
    cat > "$INSTALL_DIR/uninstall-z.lua.sh" << 'EOF'
#!/bin/bash
set -e

INSTALL_DIR="$HOME/install"
LOG_FILE="$INSTALL_DIR/zlua-install.log"

if [ -f "$LOG_FILE" ]; then
    ZLUA_DIR=$(grep "ZLUA_DIR=" "$LOG_FILE" | cut -d'=' -f2)
    SHELL_RC=$(grep "SHELL_RC=" "$LOG_FILE" | cut -d'=' -f2)
    SCRIPTS_RC=$(grep "SCRIPTS_RC=" "$LOG_FILE" | cut -d'=' -f2)
    ALIASES_RC=$(grep "ALIASES_RC=" "$LOG_FILE" | cut -d'=' -f2)
else
    ZLUA_DIR="$INSTALL_DIR/z.lua"
    SHELL_RC="${DOTFILES:-$HOME/dotfiles}/zsh/.zshenv"
    SCRIPTS_RC="${DOTFILES:-$HOME/dotfiles}/zsh/scripts.sh"
    ALIASES_RC="${DOTFILES:-$HOME/dotfiles}/zsh/aliases"
fi

[ -d "$ZLUA_DIR" ] && rm -rf "$ZLUA_DIR" && echo "Removed z.lua installation"

# Remove z.lua config from all files
for file in "$SHELL_RC" "$SCRIPTS_RC" "$ALIASES_RC"; do
    [ -f "$file" ] && sed -i '/# z\.lua/d;/_ZL_/d;/z\.lua/d;/alias z/d' "$file"
done

read -p "Remove z.lua data file (~/.zlua)? (y/N): " -n 1 -r; echo
[[ $REPLY =~ ^[Yy]$ ]] && rm -f "$HOME/.zlua" && echo "Removed z.lua data"

rm -f "$INSTALL_DIR/zlua-install.log" "$INSTALL_DIR/update-z.lua.sh" "$INSTALL_DIR/uninstall-z.lua.sh"
echo "z.lua uninstalled"
EOF
    
    chmod +x "$INSTALL_DIR/update-z.lua.sh" "$INSTALL_DIR/uninstall-z.lua.sh"
    log "Management scripts created"
}

# Test installation
test_install() {
    if [ -f "$ZLUA_DIR/z.lua" ] && lua "$ZLUA_DIR/z.lua" --help >/dev/null 2>&1; then
        log "Installation verified: z.lua working correctly"
    else
        error "Installation verification failed"
    fi
}

# Main installation
main() {
    log "z.lua installer (Dotfiles Mode) - $DOTFILES/zsh/"
    
    check_lua
    check_existing_zlua
    install_zlua
    setup_shell_integration
    create_scripts
    test_install
    
    echo ""
    log "✅ z.lua installed successfully!"
    warn "Restart terminal or: source $SCRIPTS_RC"
    echo ""
    info "Configuration:"
    echo "  • Environment: $SHELL_RC"
    echo "  • Interactive: $SCRIPTS_RC"
    echo "  • Aliases: $ALIASES_RC"
    echo ""
    info "Usage:"
    echo "  • Jump to directory: z <partial_name>"
    echo "  • Interactive mode: zi <partial_name>"
    echo "  • With fzf: zf <partial_name>"
    echo "  • Recent dirs: zh"
    echo "  • Subdirs only: zz <partial_name>"
    echo ""
    info "Commands:"
    echo "  • Update: $INSTALL_DIR/update-z.lua.sh"
    echo "  • Uninstall: $INSTALL_DIR/uninstall-z.lua.sh"
    echo ""
    info "Tips:"
    echo "  • Start using 'cd' normally - z.lua learns your patterns"
    echo "  • After visiting some dirs, try: z proj, z doc, z down, etc."
    echo "  • Use 'zi' for interactive selection when multiple matches"
}

main
