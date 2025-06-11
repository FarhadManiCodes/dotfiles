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

# Require explicit DOTFILES
[ -z "$DOTFILES" ] || [ ! -d "$DOTFILES" ] && error "DOTFILES must be set: DOTFILES=\"\$DOTFILES\" $0"
SHELL_RC="$DOTFILES/zsh/.zshenv"
SCRIPTS_RC="$DOTFILES/zsh/scripts.sh"

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

# Install fzf
install_fzf() {
    log "Installing fzf with optimizations..."
    
    [ -d "$FZF_DIR" ] && rm -rf "$FZF_DIR"
    
    git clone --depth 1 https://github.com/junegunn/fzf.git "$FZF_DIR" || error "Clone failed"
    
    cd "$FZF_DIR"
    local version=$(git describe --tags --always 2>/dev/null || echo "unknown")
    
    # Verify modern integration support
    export CGO_ENABLED=0
    go build -trimpath -ldflags="-s -w -X main.version=$version" -o bin/fzf || error "Build failed"
    
    "./bin/fzf" --help | grep -q "\-\-zsh" || error "fzf doesn't support modern integration"
    
    local size=$(stat -c%s "bin/fzf" 2>/dev/null || echo "unknown")
    local size_mb=$(echo "scale=1; $size / 1024 / 1024" | bc -l 2>/dev/null || echo "unknown")
    info "Built fzf $version (${size_mb}MB, static binary)"
}

# Setup shell integration
setup_shell_integration() {
    log "Setting up shell integration (split config)..."
    
    mkdir -p "$(dirname "$SHELL_RC")" "$(dirname "$SCRIPTS_RC")"
    touch "$SHELL_RC" "$SCRIPTS_RC"
    
    # Check/remove existing config
    if grep -q "# fzf\|FZF_" "$SHELL_RC" "$SCRIPTS_RC" 2>/dev/null; then
        warn "fzf config exists. Replace? (y/N): "
        read -n 1 -r; echo
        [[ ! $REPLY =~ ^[Yy]$ ]] && return 0
        sed -i '/# fzf/d;/FZF_/d;/source.*fzf/d' "$SHELL_RC" "$SCRIPTS_RC"
    fi
    
    # Add PATH and environment variables to .zshenv
    cat >> "$SHELL_RC" << EOF

# fzf PATH and environment
export PATH="\$PATH:$FZF_DIR/bin"
EOF
    
    # Add file discovery commands to .zshenv (environment variables)
    if command -v fd >/dev/null 2>&1; then
        cat >> "$SHELL_RC" << 'EOF'

# fzf file discovery with fd (prioritized types)
export FZF_DEFAULT_COMMAND='(fd -e py -e ipynb -e sql -e csv -e json -e yaml -e yml -e md -e sh -e toml -e env -e cfg -e log -e pkl -e pickle -e parquet -e xlsx -e xls -e h5 -e pt -e pth -e onnx --type f --hidden --follow --color=always --exclude .git --exclude .svn --exclude __pycache__ --exclude .pytest_cache --exclude .coverage --exclude .mypy_cache --exclude .tox --exclude dist --exclude build --exclude target --exclude .venv --exclude venv --exclude env --exclude .env.local --exclude .conda --exclude conda-env --exclude .ipynb_checkpoints --exclude .jupyter --exclude .dvc/cache --exclude mlruns --exclude wandb --exclude .tensorboard --exclude models/checkpoints --exclude .vscode --exclude .idea --exclude .DS_Store --exclude Thumbs.db --exclude .Trash --exclude .cache --exclude .tmp --exclude .temp --exclude node_modules --exclude .docker --exclude .torch --exclude data/raw --exclude data/cache --exclude data/processed; fd --type f --hidden --follow --color=always --exclude .git --exclude .svn --exclude __pycache__ --exclude .pytest_cache --exclude .coverage --exclude .mypy_cache --exclude .tox --exclude dist --exclude build --exclude target --exclude .venv --exclude venv --exclude env --exclude .env.local --exclude .conda --exclude conda-env --exclude .ipynb_checkpoints --exclude .jupyter --exclude .dvc/cache --exclude mlruns --exclude wandb --exclude .tensorboard --exclude models/checkpoints --exclude .vscode --exclude .idea --exclude .DS_Store --exclude Thumbs.db --exclude .Trash --exclude .cache --exclude .tmp --exclude .temp --exclude node_modules --exclude .docker --exclude .torch --exclude data/raw --exclude data/cache --exclude data/processed) 2>/dev/null | awk '"'"'!seen[$0]++'"'"
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --color=always --exclude .git --exclude .svn --exclude __pycache__ --exclude .pytest_cache --exclude .coverage --exclude .mypy_cache --exclude .tox --exclude dist --exclude build --exclude target --exclude .venv --exclude venv --exclude env --exclude .env.local --exclude .conda --exclude conda-env --exclude .ipynb_checkpoints --exclude .jupyter --exclude .dvc/cache --exclude mlruns --exclude wandb --exclude .tensorboard --exclude models/checkpoints --exclude .vscode --exclude .idea --exclude .DS_Store --exclude Thumbs.db --exclude .Trash --exclude .cache --exclude .tmp --exclude .temp --exclude node_modules --exclude .docker --exclude .torch --exclude data/raw --exclude data/cache --exclude data/processed'
EOF
        log "Configured with fd + file prioritization"
    elif command -v rg >/dev/null 2>&1; then
        cat >> "$SHELL_RC" << 'EOF'

# fzf file discovery with ripgrep (prioritized types)
export FZF_DEFAULT_COMMAND='(rg --files --color=always -g "*.{py,ipynb,sql,csv,json,yaml,yml,md,sh,toml,env,cfg,log,pkl,pickle,parquet,xlsx,xls,h5,pt,pth,onnx}" --hidden --follow --glob "!.git/*" --glob "!.svn/*" --glob "!__pycache__/*" --glob "!.pytest_cache/*" --glob "!.coverage/*" --glob "!.mypy_cache/*" --glob "!.tox/*" --glob "!dist/*" --glob "!build/*" --glob "!target/*" --glob "!.venv/*" --glob "!venv/*" --glob "!env/*" --glob "!.env.local/*" --glob "!.conda/*" --glob "!conda-env/*" --glob "!.ipynb_checkpoints/*" --glob "!.jupyter/*" --glob "!.dvc/cache/*" --glob "!mlruns/*" --glob "!wandb/*" --glob "!.tensorboard/*" --glob "!models/checkpoints/*" --glob "!.vscode/*" --glob "!.idea/*" --glob "!.DS_Store" --glob "!Thumbs.db" --glob "!.Trash/*" --glob "!.cache/*" --glob "!.tmp/*" --glob "!.temp/*" --glob "!node_modules/*" --glob "!.docker/*" --glob "!.torch/*" --glob "!data/raw/*" --glob "!data/cache/*" --glob "!data/processed/*"; rg --files --color=always --hidden --follow --glob "!.git/*" --glob "!.svn/*" --glob "!__pycache__/*" --glob "!.pytest_cache/*" --glob "!.coverage/*" --glob "!.mypy_cache/*" --glob "!.tox/*" --glob "!dist/*" --glob "!build/*" --glob "!target/*" --glob "!.venv/*" --glob "!venv/*" --glob "!env/*" --glob "!.env.local/*" --glob "!.conda/*" --glob "!conda-env/*" --glob "!.ipynb_checkpoints/*" --glob "!.jupyter/*" --glob "!.dvc/cache/*" --glob "!mlruns/*" --glob "!wandb/*" --glob "!.tensorboard/*" --glob "!models/checkpoints/*" --glob "!.vscode/*" --glob "!.idea/*" --glob "!.DS_Store" --glob "!Thumbs.db" --glob "!.Trash/*" --glob "!.cache/*" --glob "!.tmp/*" --glob "!.temp/*" --glob "!node_modules/*" --glob "!.docker/*" --glob "!.torch/*" --glob "!data/raw/*" --glob "!data/cache/*" --glob "!data/processed/*") 2>/dev/null | awk '"'"'!seen[$0]++'"'"
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
EOF
        log "Configured with ripgrep + file prioritization"
    else
        cat >> "$SHELL_RC" << 'EOF'

# fzf file discovery with find (basic prioritization)
export FZF_DEFAULT_COMMAND='(find . -type f \( -name "*.py" -o -name "*.ipynb" -o -name "*.sql" -o -name "*.csv" -o -name "*.json" -o -name "*.yaml" -o -name "*.yml" -o -name "*.md" -o -name "*.sh" \) -not -path "*/\.git/*" -not -path "*/__pycache__/*" -not -path "*/\.ipynb_checkpoints/*" -not -path "*/\.vscode/*" -not -path "*/node_modules/*" -not -path "*/\.venv/*" -not -path "*/venv/*" -not -path "*/data/raw/*" -not -path "*/data/cache/*" -not -path "*/data/processed/*" 2>/dev/null; find . -type f -not -path "*/\.git/*" -not -path "*/__pycache__/*" -not -path "*/\.ipynb_checkpoints/*" -not -path "*/\.vscode/*" -not -path "*/node_modules/*" -not -path "*/\.venv/*" -not -path "*/venv/*" -not -path "*/data/raw/*" -not -path "*/data/cache/*" -not -path "*/data/processed/*" 2>/dev/null) | awk '"'"'!seen[$0]++'"'"
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
EOF
        log "Configured with find + basic prioritization"
    fi
    
    # Add bat preview and tmux support to .zshenv (environment variables)
    if command -v bat >/dev/null 2>&1; then
        cat >> "$SHELL_RC" << 'EOF'

# fzf preview with bat
export FZF_CTRL_T_OPTS="--preview 'bat --color=always --style=numbers --line-range=:500 {}' --preview-window=right:50%:hidden --bind='ctrl-p:toggle-preview,alt-p:toggle-preview,?:toggle-preview'"
EOF
        log "Added bat preview support"
    fi
    
    # Add tmux support to .zshenv
    cat >> "$SHELL_RC" << 'EOF'

# fzf tmux integration
if [ -n "$TMUX" ]; then
  export FZF_TMUX=1
  export FZF_TMUX_OPTS='-p 80%,70%'
fi
EOF
    
    # Add interactive features to scripts.sh
    cat >> "$SCRIPTS_RC" << 'EOF'

# fzf shell integration (interactive features)
source <(fzf --zsh)

# fzf appearance settings (OneDark theme)
export FZF_DEFAULT_OPTS='
  --height 60%
  --layout=reverse
  --border=rounded
  --info=inline
  --prompt="❯ "
  --pointer="❯"
  --marker="❯"
  --preview-window=right:50%:hidden
  --bind="ctrl-p:toggle-preview"
  --bind="alt-p:toggle-preview"
  --bind="?:toggle-preview"
  --bind="ctrl-u:preview-page-up,ctrl-d:preview-page-down"
  --bind="ctrl-f:page-down,ctrl-b:page-up"
  --tiebreak=end
  --ansi
  --color=fg:#abb2bf,bg:#282c34,hl:#61afef
  --color=fg+:#ffffff,bg+:#3e4451,hl+:#61afef
  --color=info:#e5c07b,prompt:#61afef,pointer:#e06c75
  --color=marker:#98c379,spinner:#e5c07b,header:#c678dd'
EOF
    
    log "Shell integration configured:"
    log "  • Environment (.zshenv): PATH, commands, preview, tmux"
    log "  • Interactive (scripts.sh): shell integration, theme"
}

# Create management scripts
create_scripts() {
    mkdir -p "$INSTALL_DIR"
    
    # Installation log
    cat > "$INSTALL_DIR/fzf-install.log" << EOF
INSTALL_DIR=$INSTALL_DIR
FZF_DIR=$FZF_DIR
SHELL_RC=$SHELL_RC
SCRIPTS_RC=$SCRIPTS_RC
DOTFILES=$DOTFILES
INSTALL_DATE=$(date -Iseconds)
TOOLS=$(command -v fd >/dev/null && echo "fd " || echo "")$(command -v rg >/dev/null && echo "rg " || echo "")$(command -v bat >/dev/null && echo "bat" || echo "")
EOF
    
    # Update script
    cat > "$INSTALL_DIR/update-fzf.sh" << 'EOF'
#!/bin/bash
set -e

FZF_DIR="$HOME/install/fzf"
[ ! -d "$FZF_DIR" ] && { echo "fzf not found"; exit 1; }

cd "$FZF_DIR"
current=$(./bin/fzf --version 2>/dev/null | cut -d' ' -f1 || echo "unknown")
echo "Current: $current"

git pull origin master
latest=$(git describe --tags --always 2>/dev/null || echo "unknown")

[ "$current" = "$latest" ] && { echo "Already up to date"; exit 0; }

echo "Building $latest..."
export CGO_ENABLED=0
go build -trimpath -ldflags="-s -w -X main.version=$latest" -o bin/fzf
echo "Updated to $latest"
EOF
    
    # Uninstall script
    cat > "$INSTALL_DIR/uninstall-fzf.sh" << 'EOF'
#!/bin/bash
set -e

INSTALL_DIR="$HOME/install"
LOG_FILE="$INSTALL_DIR/fzf-install.log"

if [ -f "$LOG_FILE" ]; then
    FZF_DIR=$(grep "FZF_DIR=" "$LOG_FILE" | cut -d'=' -f2)
    SHELL_RC=$(grep "SHELL_RC=" "$LOG_FILE" | cut -d'=' -f2)
    SCRIPTS_RC=$(grep "SCRIPTS_RC=" "$LOG_FILE" | cut -d'=' -f2)
else
    FZF_DIR="$INSTALL_DIR/fzf"
    SHELL_RC="${DOTFILES:-$HOME/dotfiles}/zsh/.zshenv"
    SCRIPTS_RC="${DOTFILES:-$HOME/dotfiles}/zsh/scripts.sh"
fi

[ -d "$FZF_DIR" ] && rm -rf "$FZF_DIR" && echo "Removed fzf"

for file in "$SHELL_RC" "$SCRIPTS_RC"; do
    [ -f "$file" ] && sed -i '/# fzf/d;/FZF_/d;/source.*fzf/d' "$file"
done

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
    log "fzf installer (Dotfiles Mode) - $DOTFILES/zsh/"
    
    check_existing_fzf
    install_fzf
    setup_shell_integration
    create_scripts
    test_install
    
    echo ""
    log "✅ fzf installed successfully!"
    warn "Restart terminal or: source $SCRIPTS_RC"
    echo ""
    info "Configuration:"
    echo "  • Environment: $SHELL_RC"
    echo "  • Interactive: $SCRIPTS_RC"
    echo ""
    info "Commands:"
    echo "  • File search: Ctrl-T • History: Ctrl-R • Directories: Alt-C"
    echo "  • Preview: Ctrl-P, Alt-P, or ?"
    echo "  • Update: $INSTALL_DIR/update-fzf.sh"
    echo "  • Uninstall: $INSTALL_DIR/uninstall-fzf.sh"
}

main
