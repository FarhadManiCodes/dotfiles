#!/bin/zsh
# =============================================================================
# SIMPLE SCRIPTS.SH - Always load everything with direnv support
# =============================================================================

# Early exit for non-interactive shells
[[ $- != *i* ]] && return

# =============================================================================
# ENVIRONMENT CHECK
# =============================================================================

if [[ -z "$DOTFILES" ]]; then
  if [[ -d "$HOME/dotfiles" ]]; then
    export DOTFILES="$HOME/dotfiles"
  else
    echo "❌ Cannot find dotfiles directory!" >&2
    return 1
  fi
fi

if [[ ! -d "$DOTFILES" ]]; then
  echo "❌ DOTFILES directory doesn't exist: $DOTFILES" >&2
  return 1
fi

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

# Safe sourcing function
safe_source() {
  local file="$1"
  local description="${2:-script}"

  [[ ! -f "$file" ]] && return 1
  [[ ! -r "$file" ]] && return 1

  if ! (source "$file") >/dev/null 2>&1; then
    echo "❌ Syntax error in $file" >&2
    return 1
  fi

  if source "$file"; then
    return 0
  else
    echo "❌ Failed to source: $description" >&2
    return 1
  fi
}

# =============================================================================
# BASIC SETUP
# =============================================================================

[[ -f "$HOME/.cargo/env" ]] && source "$HOME/.cargo/env"

# =============================================================================
# DIRENV SETUP (before virtualenv loading)
# =============================================================================

if command -v direnv >/dev/null 2>&1; then
  eval "$(direnv hook zsh)"

  # Centralized venv helper
  use_venv() {
    local venv_name=${1:-$(basename $PWD)}
    local venv_path="$HOME/.central_venvs/$venv_name"

    if [ ! -d "$venv_path" ]; then
      echo "Creating new venv: $venv_name"
      python -m venv "$venv_path"
    fi

    echo "source $venv_path/bin/activate" >.envrc
    direnv allow
  }
fi

# =============================================================================
# FZF CONFIGURATION
# =============================================================================

if command -v fzf >/dev/null 2>&1; then
  source <(fzf --zsh) 2>/dev/null

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
fi

# =============================================================================
# LOAD ALL SCRIPTS
# =============================================================================

# 0. get project info
safe_source "$DOTFILES/zsh/productivity/project-detection.sh" "project detection" || echo "❌ Project detection failed"

# 1. Last Working Directory
safe_source "$DOTFILES/zsh/productivity/last-working-dir.sh" "last working directory" || echo "❌ Last working directory failed"
# Auto-restore if in HOME
if [[ "$PWD" == "$HOME" ]] && type lwd >/dev/null 2>&1; then
  lwd 2>/dev/null
fi

# 2. Git Enhancements
safe_source "$DOTFILES/zsh/productivity/git-enhancements.sh" "git enhancements" || echo "❌ Git enhancements failed"

# 3. Virtual Environment Management
safe_source "$DOTFILES/zsh/productivity/virtualenv.sh" "virtual environment management" || echo "❌ Virtual environment management failed"

# 4. FZF Enhancements
if command -v fzf >/dev/null 2>&1; then
  safe_source "$DOTFILES/zsh/productivity/fzf-enhancements.sh" "FZF enhancements" || echo "❌ FZF enhancements failed"
fi

# 5. Zoxide
if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh)"
fi

# 6. Custom Completions
safe_source "$DOTFILES/zsh/productivity/completions.sh" "custom completions" || echo "❌ Custom completions failed"
# 7. tmux smart start
safe_source "$DOTFILES/zsh/productivity/tmux_smart_start.sh" "tmux smart start" || echo "❌ Tmux smart start faild"
# =============================================================================
# UTILITY COMMANDS
# =============================================================================

# Show what's loaded and working
loading_status() {
  echo "📊 Dotfiles Status:"
  echo "  DOTFILES: $DOTFILES"
  echo "  Direnv: $(command -v direnv >/dev/null 2>&1 && echo "✅" || echo "❌")"
  echo "  Git enhancements: $(type gst >/dev/null 2>&1 && echo "✅" || echo "❌")"
  echo "  Git (data science): $(type gstds >/dev/null 2>&1 && echo "✅" || echo "❌")"
  echo "  Virtual env: $(type va >/dev/null 2>&1 && echo "✅" || echo "❌")"
  echo "  use_venv helper: $(type use_venv >/dev/null 2>&1 && echo "✅" || echo "❌")"
  echo "  FZF functions: $(type fnb >/dev/null 2>&1 && echo "✅" || echo "❌")"
  echo "  Last working dir: $(type lwd >/dev/null 2>&1 && echo "✅" || echo "❌")"
  echo "  Zoxide: $(type z >/dev/null 2>&1 && echo "✅" || echo "❌")"

  # Environment info
  if [[ -n "$VIRTUAL_ENV" ]]; then
    echo "  Active venv: $(basename "$VIRTUAL_ENV")"
  fi

  if [[ -n "$DIRENV_DIR" ]]; then
    echo "  Direnv active: $(basename "$DIRENV_DIR")"
  fi

  if git rev-parse --git-dir >/dev/null 2>&1; then
    echo "  Git repo: $(basename "$(git rev-parse --show-toplevel)" 2>/dev/null)"
  fi

  # Show central venvs
  if [[ -d "$HOME/.central_venvs" ]]; then
    local venv_count=$(ls -1 "$HOME/.central_venvs" 2>/dev/null | wc -l)
    echo "  Central venvs: $venv_count environments"
  fi
}

# Aliases
alias status='loading_status'
