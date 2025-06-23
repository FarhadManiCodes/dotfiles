#!/bin/zsh
# =============================================================================
# HYBRID APPROACH - Simple loading + Smart virtual environment loading
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

# Check if we should load virtual environment management
should_load_virtualenv() {
  # Load if already in a virtual environment
  [[ -n "$VIRTUAL_ENV" ]] && return 0

  # Load if in a Python project directory
  [[ -f "requirements.txt" ]] && return 0
  [[ -f "pyproject.toml" ]] && return 0
  [[ -f "environment.yml" ]] && return 0
  [[ -f "setup.py" ]] && return 0
  [[ -f "Pipfile" ]] && return 0

  # Load if in common development directories
  [[ "$PWD" =~ (projects|work|dev|learning) ]] && return 0

  # Load if local venv exists
  [[ -d "venv" || -d ".venv" || -d "env" ]] && return 0

  # Don't load otherwise
  return 1
}

# Load virtual environment management with fallback
load_virtualenv() {
  if safe_source "$DOTFILES/zsh/productivity/virtualenv.sh" "virtual environment management"; then
    _VIRTUALENV_LOADED=true
    return 0
  else
    # Provide basic fallback functions
    va() {
      local env="${1:-}"
      if [[ -z "$env" ]]; then
        echo "Usage: va <environment_name>"
        return 1
      fi

      for path in "$HOME/virtualenv/$env/bin/activate" "./venv/bin/activate" "./.venv/bin/activate"; do
        if [[ -f "$path" ]]; then
          source "$path"
          echo "✅ Activated: $env"
          return 0
        fi
      done

      echo "❌ Environment not found: $env"
      return 1
    }

    vd() {
      if [[ -n "$VIRTUAL_ENV" ]]; then
        deactivate
        echo "✅ Deactivated virtual environment"
      else
        echo "ℹ️  No active virtual environment"
      fi
    }

    vl() {
      echo "🐍 Virtual Environments:"
      [[ -d "$HOME/virtualenv" ]] && ls -1 "$HOME/virtualenv" 2>/dev/null | sed 's/^/  /'
      [[ -d "./venv" ]] && echo "  venv (local)"
      [[ -d "./.venv" ]] && echo "  .venv (local)"
    }

    return 1
  fi
}

# =============================================================================
# BASIC SETUP
# =============================================================================

[[ -f "$HOME/.cargo/env" ]] && source "$HOME/.cargo/env"

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
# LOAD SCRIPTS (Hybrid Approach)
# =============================================================================

# State tracking for virtual environment
typeset -g _VIRTUALENV_LOADED=false

# 1. Last Working Directory (ALWAYS LOAD - simple and safe)
safe_source "$DOTFILES/zsh/productivity/last-working-dir.sh" "last working directory"

# Auto-restore if in HOME
if [[ "$PWD" == "$HOME" ]] && type lwd >/dev/null 2>&1; then
  lwd 2>/dev/null
fi

# 2. Git Enhancements (ALWAYS LOAD - used everywhere in development)
if safe_source "$DOTFILES/zsh/productivity/git-enhancements.sh" "git enhancements"; then
  :
else
  # Basic git aliases fallback
  alias gs='git status'
  alias ga='git add'
  alias gc='git commit --verbose'
  alias gp='git push'
  alias gpu='git pull'
  alias gd='git diff'
  alias gl='git log --oneline'
fi

# 3. Virtual Environment Management (CONDITIONAL LOAD - prevents cd errors)
if should_load_virtualenv; then
  load_virtualenv
fi

# 4. FZF Enhancements (ALWAYS LOAD if FZF available - safe and useful)
if command -v fzf >/dev/null 2>&1; then
  safe_source "$DOTFILES/zsh/productivity/fzf-enhancements.sh" "FZF enhancements"
fi

# 5. Zoxide (ALWAYS LOAD - safe and fast)
if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh)"
fi

# 6. Custom Completions (ALWAYS LOAD - safe)
safe_source "$DOTFILES/zsh/productivity/completions.sh" "custom completions"

# =============================================================================
# SMART CHPWD HOOK (for virtual environment lazy loading)
# =============================================================================

smart_chpwd_hook() {
  # Only try to load virtualenv if not already loaded
  if [[ "$_VIRTUALENV_LOADED" == "false" ]] && should_load_virtualenv; then
    echo "🐍 Python project detected, loading virtual environment management..."
    load_virtualenv
  fi

  # Call auto_activate_venv if it's available (after virtualenv is loaded)
  if [[ "$_VIRTUALENV_LOADED" == "true" ]] && type auto_activate_venv >/dev/null 2>&1; then
    auto_activate_venv
  fi
}

# Add our smart chpwd hook
if [[ -n "$ZSH_VERSION" ]]; then
  autoload -U add-zsh-hook
  add-zsh-hook chpwd smart_chpwd_hook

  # Run once for current directory
  smart_chpwd_hook
fi

# =============================================================================
# UTILITY COMMANDS
# =============================================================================

# Show loading status
loading_status() {
  echo "📊 Dotfiles Status:"
  echo "  DOTFILES: $DOTFILES"
  echo "  Git enhancements: $(type gst >/dev/null 2>&1 && echo "✅" || echo "❌")"
  echo "  Git (data science): $(type gstds >/dev/null 2>&1 && echo "✅" || echo "❌")"
  echo "  Virtual env loaded: $_VIRTUALENV_LOADED"
  echo "  Virtual env functions: $(type va >/dev/null 2>&1 && echo "✅" || echo "❌")"
  echo "  FZF functions: $(type fnb >/dev/null 2>&1 && echo "✅" || echo "❌")"
  echo "  Last working dir: $(type lwd >/dev/null 2>&1 && echo "✅" || echo "❌")"
  echo "  Zoxide: $(type z >/dev/null 2>&1 && echo "✅" || echo "❌")"

  # Context info
  echo ""
  echo "🔍 Current Context:"
  echo "  Directory: $PWD"
  echo "  Should load VE: $(should_load_virtualenv && echo "✅ YES" || echo "❌ NO")"

  if [[ -n "$VIRTUAL_ENV" ]]; then
    echo "  Active venv: $(basename "$VIRTUAL_ENV")"
  fi

  if git rev-parse --git-dir >/dev/null 2>&1; then
    echo "  Git repo: $(basename "$(git rev-parse --show-toplevel)" 2>/dev/null)"
  fi
}

# Test LWD functionality
lwd_test() {
  echo "🧪 Testing Last Working Directory:"

  if type lwd >/dev/null 2>&1; then
    echo "  ✅ lwd function exists"
  else
    echo "  ❌ lwd function missing"
  fi

  if type chpwd_last_working_dir >/dev/null 2>&1; then
    echo "  ✅ chpwd_last_working_dir function exists"
  else
    echo "  ❌ chpwd_last_working_dir function missing"
  fi

  local cache_file="${ZSH_CACHE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}}/last-working-dir${SSH_USER:+.$SSH_USER}"
  echo "  📁 Cache file: $cache_file"

  if [[ -f "$cache_file" ]]; then
    local saved_dir=$(cat "$cache_file" 2>/dev/null)
    echo "  📂 Saved: $saved_dir"
    echo "  ✅ Directory exists: $([ -d "$saved_dir" ] && echo "YES" || echo "NO")"
  else
    echo "  ⚠️  No cache file found"
  fi
}

# Force load virtual environment
load_virtualenv_now() {
  echo "🐍 Force loading virtual environment management..."
  if load_virtualenv; then
    echo "✅ Virtual environment management loaded"
  else
    echo "❌ Failed to load virtual environment management"
  fi
}

# Reload everything
reload_scripts() {
  echo "🔄 Reloading scripts..."
  _VIRTUALENV_LOADED=false
  source "$DOTFILES/zsh/scripts.sh"
  echo "✅ Reload complete"
}

# Aliases
alias loading_status='loading_status'
alias load_ve='load_virtualenv_now'
