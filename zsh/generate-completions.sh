#!/usr/bin/env bash
# ============================================================================
# ZSH Completion Generator
# Auto-generates autoloadable completion files for installed tools.
#
# USAGE:
# 1. Save this file to ~/.config/zsh/generate-completions.sh
# 2. Make it executable: chmod +x ~/.config/zsh/generate-completions.sh
# 3. Run it periodically to update completions.
# ============================================================================

set -e

# Directory where completions will be stored
COMPLETION_DIR="$HOME/.config/zsh/completions"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

mkdir -p "$COMPLETION_DIR"

echo -e "${BLUE}🔍 ZSH Completion Generator${NC}"
echo "================================"

# ----------------------------------------------------------------------------
# Helper: Standard Generator
# Used for tools that output standard Zsh #compdef content
# ----------------------------------------------------------------------------
generate() {
    local tool=$1
    local cmd=$2
    local out="$COMPLETION_DIR/_$tool"

    if command -v "$tool" >/dev/null 2>&1; then
        # Check if file exists and is younger than 7 days
        if [[ -f "$out" ]] && [[ $(find "$out" -mtime -7 2>/dev/null) ]]; then
             echo -e "  ${GREEN}✓${NC} $tool (cached)"
        else
             # Run the command
             if eval "$cmd" > "$out" 2>/dev/null; then
                 echo -e "  ${GREEN}✓${NC} $tool (generated)"
             else
                 echo -e "  ${RED}✗${NC} $tool (generation failed)"
                 rm -f "$out"
             fi
        fi
    else
        echo -e "  ${YELLOW}⊘${NC} $tool (not installed)"
    fi
}

# ----------------------------------------------------------------------------
# Helper: Wrapper Generator
# Used for tools (npm, pip) that output raw scripts instead of #compdef files
# ----------------------------------------------------------------------------
generate_wrapper() {
    local tool=$1
    local cmd=$2
    local out="$COMPLETION_DIR/_$tool"

    if command -v "$tool" >/dev/null 2>&1; then
        if [[ -f "$out" ]] && [[ $(find "$out" -mtime -7 2>/dev/null) ]]; then
             echo -e "  ${GREEN}✓${NC} $tool (cached)"
        else
             # 1. Create the file with #compdef header so Zsh knows to autoload it
             echo "#compdef $tool" > "$out"
             
             # 2. Append the tool's output
             if eval "$cmd" >> "$out" 2>/dev/null; then
                 # 3. Special fix for pip:
                 # pip uses 'compctl' (legacy). We append a call to the function 
                 # so it registers immediately upon autoloading.
                 if [[ "$tool" == "pip" ]]; then
                     echo "" >> "$out"
                     echo "_pip_completion" >> "$out" 
                 fi
                 echo -e "  ${GREEN}✓${NC} $tool (generated wrapper)"
             else
                 echo -e "  ${RED}✗${NC} $tool (generation failed)"
                 rm -f "$out"
             fi
        fi
    else
        echo -e "  ${YELLOW}⊘${NC} $tool (not installed)"
    fi
}

# ============================================================================
# 1. RUST TOOLS
# ============================================================================
echo -e "\n${YELLOW}Rust Tools:${NC}"

# Check for rustup explicitly. 
# If you don't have rustup, you likely installed cargo via OS package manager,
# which usually installs completions to /usr/share/zsh/ automatically.
if command -v rustup >/dev/null 2>&1; then
    generate "rustup" "rustup completions zsh"
    generate "cargo"  "rustup completions zsh cargo"
else
    if command -v cargo >/dev/null 2>&1; then
        echo -e "  ${BLUE}i${NC} cargo (using system default)"
    else
        echo -e "  ${YELLOW}⊘${NC} cargo (not installed)"
    fi
fi

# ============================================================================
# 2. PYTHON TOOLS
# ============================================================================
echo -e "\n${YELLOW}Python Tools:${NC}"
generate "poetry" "poetry completions zsh"
generate "uv"     "uv generate-shell-completion zsh"

# ============================================================================
# 3. CONTAINER & CLOUD
# ============================================================================
echo -e "\n${YELLOW}Container & Cloud:${NC}"
generate "docker"   "docker completion zsh"
generate "kubectl"  "kubectl completion zsh"
generate "helm"     "helm completion zsh"
generate "gh"       "gh completion -s zsh"

# ============================================================================
# 4. NODE JS
# ============================================================================
echo -e "\n${YELLOW}Node.js:${NC}"
# NPM outputs raw shell script, needs wrapper
generate_wrapper "npm" "npm completion"

# ============================================================================
# 5. TERRAFORM (Manual Instruction)
# ============================================================================
if command -v terraform >/dev/null 2>&1; then
    echo -e "\n${YELLOW}Terraform:${NC}"
    echo -e "  ${YELLOW}!${NC} Terraform cannot generate a static file."
    echo -e "     Add this to .zshrc: complete -o nospace -C /usr/bin/terraform terraform"
fi

echo -e "\n${GREEN}✅ Done!${NC}"
