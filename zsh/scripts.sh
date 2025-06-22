#!/bin/zsh
# =============================================================================
# OPTIMIZED DOTFILES SCRIPTS - Fixed for compatibility
# =============================================================================

# Early exit for non-interactive shells
[[ $- != *i* ]] && return

# Initialize cargo env (early setup)
[[ -f "$HOME/.cargo/env" ]] && source "$HOME/.cargo/env"

# =============================================================================
# GLOBAL STATE & CONFIGURATION
# =============================================================================

# Loading state tracking
typeset -g _GIT_ENHANCEMENTS_LOADED=false
typeset -g _FZF_ENHANCEMENTS_LOADED=false
typeset -g _VIRTUALENV_LOADED=false

# Performance tracking
typeset -A _DIR_CACHE
typeset -g _LAST_PWD=""
typeset -g DOTFILES_DEBUG=${DOTFILES_DEBUG:-false}

# =============================================================================
# FZF CONFIGURATION (Early setup for performance)
# =============================================================================

# Only setup FZF if available
if command -v fzf >/dev/null 2>&1; then
  # Shell integration
  source <(fzf --zsh) 2>/dev/null || {
    echo "⚠️  FZF shell integration failed" >&2
  }
  
  # Enhanced FZF configuration
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
# UTILITY FUNCTIONS
# =============================================================================

# Debug logging
debug_log() {
  [[ "$DOTFILES_DEBUG" == "true" ]] && echo "[DEBUG $(date '+%H:%M:%S')] $*" >&2
}

# Safe file sourcing
safe_source() {
  local file="$1" description="${2:-script}"
  
  if [[ ! -f "$file" ]]; then
    debug_log "Missing $description: $file"
    return 1
  fi
  
  if [[ ! -r "$file" ]]; then
    debug_log "Unreadable $description: $file"
    return 1
  fi
  
  # Quick syntax check
  if ! (source "$file") >/dev/null 2>&1; then
    echo "❌ Syntax error in $description: $file" >&2
    return 1
  fi
  
  source "$file"
  debug_log "Loaded $description: $file"
}

# Fast directory context detection with caching
get_dir_context() {
  local dir="$PWD"
  local cache_key="context:$dir"
  
  # Return cached result
  if [[ -n "${_DIR_CACHE[$cache_key]:-}" ]]; then
    echo "${_DIR_CACHE[$cache_key]}"
    return
  fi
  
  local context=""
  
  # Fast file checks
  [[ -d ".git" ]] && context="${context}git,"
  [[ -f "requirements.txt" || -f "pyproject.toml" || -f "environment.yml" ]] && context="${context}python,"
  [[ -d "venv" || -d ".venv" ]] && context="${context}venv,"
  [[ "$dir" =~ (projects|work|dev|learning) ]] && context="${context}dev,"
  
  # Cache and return
  _DIR_CACHE[$cache_key]="${context%,}"
  echo "${context%,}"
}

# =============================================================================
# DYNAMIC LOADING FUNCTIONS
# =============================================================================

load_git_enhancements() {
  [[ "$_GIT_ENHANCEMENTS_LOADED" == "true" ]] && return
  
  local context=$(get_dir_context)
  if [[ "$context" == *"git"* ]] || [[ "$context" == *"dev"* ]]; then
    if safe_source "$DOTFILES/zsh/productivity/git-enhancements.sh" "git enhancements"; then
      _GIT_ENHANCEMENTS_LOADED=true
      debug_log "Git enhancements loaded"
    else
      # Fallback to basic git aliases
      alias gs='git status'
      alias ga='git add'
      alias gc='git commit --verbose'
      alias gp='git push'
      alias gpu='git pull'
      debug_log "Using git fallback aliases"
    fi
  fi
}

load_virtualenv() {
  [[ "$_VIRTUALENV_LOADED" == "true" ]] && return
  
  local context=$(get_dir_context)
  if [[ "$context" == *"python"* ]] || [[ "$context" == *"venv"* ]] || [[ -n "$VIRTUAL_ENV" ]]; then
    if safe_source "$DOTFILES/zsh/productivity/virtualenv.sh" "virtual environment management"; then
      _VIRTUALENV_LOADED=true
      debug_log "Virtual environment management loaded"
    fi
  fi
}

load_fzf_enhancements() {
  [[ "$_FZF_ENHANCEMENTS_LOADED" == "true" ]] && return
  
  if command -v fzf >/dev/null 2>&1; then
    if safe_source "$DOTFILES/zsh/productivity/fzf-enhancements.sh" "FZF enhancements"; then
      _FZF_ENHANCEMENTS_LOADED=true
      debug_log "FZF enhancements loaded"
    fi
  fi
}

# =============================================================================
# TMUX AUTO-START (Simplified)
# =============================================================================

should_start_tmux() {
  [[ -n "$TMUX" ]] && return 1
  [[ ! -t 0 ]] && return 1
  [[ "$PWD" =~ ^(/tmp|/var|/proc|/sys|/dev|/run) ]] && return 1
  [[ -n "$VSCODE_INJECTION" || -n "$INSIDE_EMACS" ]] && return 1
  return 0
}

smart_tmux_prompt() {
  command -v tmux >/dev/null 2>&1 || return
  
  if tmux list-sessions >/dev/null 2>&1; then
    echo "🔍 TMux sessions:"
    tmux list-sessions -F "  📋 #{session_name} (#{session_windows} windows)"
    echo "💡 Use: tmux attach -t <n> or tmux-new"
  else
    echo "🚀 Starting tmux with session restoration..."
    tmux-start 2>/dev/null || echo "❌ Failed to start tmux"
  fi
}

should_start_tmux && smart_tmux_prompt

# =============================================================================
# FZF LAZY LOADING (Bulletproof approach)
# =============================================================================

create_fzf_wrappers() {
  command -v fzf >/dev/null 2>&1 || return
  
  local fzf_functions=(fnb frg fdir fproc fhist fdata ff fgit)
  
  for func in "${fzf_functions[@]}"; do
    eval "
    $func() {
      if [[ \"\$_FZF_ENHANCEMENTS_LOADED\" != \"true\" ]]; then
        load_fzf_enhancements
      fi
      
      # Call the real function if it exists
      if declare -f \"$func\" >/dev/null 2>&1; then
        command $func \"\$@\"
      else
        echo \"❌ Function $func not available\" >&2
        return 1
      fi
    }"
  done
}

# =============================================================================
# SCRIPT LOADING SEQUENCE (FIXED ORDER)
# =============================================================================

# 1. CRITICAL: Load last working directory FIRST (it sets up its own chpwd)
safe_source "$DOTFILES/zsh/productivity/last-working-dir.sh" "last working directory"

# 2. Load based on initial directory context
load_git_enhancements
load_virtualenv

# 3. Setup FZF wrappers
create_fzf_wrappers

# 4. Load CLI enhancements (small script, always safe to load)
safe_source "$DOTFILES/zsh/productivity/cli-enhancements.sh" "CLI enhancements"

# 5. Initialize zoxide (fast operation)
command -v zoxide >/dev/null 2>&1 && eval "$(zoxide init zsh)"

# 6. Load completions last (after functions are available)
safe_source "$DOTFILES/zsh/productivity/completions.sh" "custom completions"

# =============================================================================
# ENHANCED CHPWD HOOK (COOPERATIVE WITH LAST-WORKING-DIR)
# =============================================================================

# Our enhanced chpwd that works WITH the last-working-dir chpwd
our_chpwd_hook() {
  local current_dir="$PWD"
  
  # Skip if same directory
  [[ "$current_dir" == "$_LAST_PWD" ]] && return
  
  # Get context efficiently
  local context=$(get_dir_context)
  local prev_context="${_DIR_CACHE[context:$_LAST_PWD]:-}"
  
  # Only do expensive operations if context changed
  if [[ "$context" != "$prev_context" ]]; then
    debug_log "Context changed: '$prev_context' -> '$context'"
    
    # Load modules based on new context
    [[ "$context" == *"git"* ]] && load_git_enhancements
    [[ "$context" == *"python"* ]] && load_virtualenv
  fi
  
  _LAST_PWD="$current_dir"
  
  # Periodic cache cleanup
  (( ${#_DIR_CACHE[@]} > 100 )) && {
    debug_log "Cleaning cache (${#_DIR_CACHE[@]} entries)"
    local -A new_cache
    for key in "${(@k)_DIR_CACHE}"; do
      [[ "$key" == "context:$PWD"* ]] && new_cache[$key]="${_DIR_CACHE[$key]}"
    done
    _DIR_CACHE=("${(@kv)new_cache}")
  }
}

# =============================================================================
# ZSH HOOKS SETUP (COOPERATIVE)
# =============================================================================

if [[ -n "$ZSH_VERSION" ]]; then
  autoload -U add-zsh-hook
  
  # Add our hook WITHOUT interfering with last-working-dir's chpwd
  add-zsh-hook chpwd our_chpwd_hook
  
  # Call our hook once for initial setup
  our_chpwd_hook
fi

# =============================================================================
# UTILITY COMMANDS
# =============================================================================

# Force reload everything
reload_enhancements() {
  echo "🔄 Reloading enhancements..."
  _GIT_ENHANCEMENTS_LOADED=false
  _VIRTUALENV_LOADED=false
  _FZF_ENHANCEMENTS_LOADED=false
  _DIR_CACHE=()
  
  load_git_enhancements
  load_virtualenv
  load_fzf_enhancements
  echo "✅ Reload complete"
}

# Show loading status
show_loading_status() {
  echo "📊 Dynamic Loading Status:"
  echo "  Git enhancements: $_GIT_ENHANCEMENTS_LOADED"
  echo "  Virtual environment: $_VIRTUALENV_LOADED"
  echo "  FZF enhancements: $_FZF_ENHANCEMENTS_LOADED"
  echo "  Directory cache: ${#_DIR_CACHE[@]} entries"
  echo "  Current context: $(get_dir_context)"
  echo "  Debug mode: $DOTFILES_DEBUG"
  echo ""
  echo "🔧 Functions available:"
  echo "  Last working dir: $(type smart_save_directory >/dev/null 2>&1 && echo "✅" || echo "❌")"
  echo "  Auto venv: $(type auto_activate_venv >/dev/null 2>&1 && echo "✅" || echo "❌")"
}

# Test last working directory
test_lwd() {
  echo "🧪 Testing last working directory..."
  
  # Check if functions exist
  if type smart_save_directory >/dev/null 2>&1; then
    echo "✅ smart_save_directory function found"
  else
    echo "❌ smart_save_directory function missing"
  fi
  
  if type lwd_status >/dev/null 2>&1; then
    echo "✅ lwd_status function found"
    lwd_status
  else
    echo "❌ lwd_status function missing"
  fi
  
  # Test manual save
  echo "📁 Testing manual save..."
  if type lwd_save >/dev/null 2>&1; then
    lwd_save
  else
    echo "❌ lwd_save function not available"
  fi
}

# Aliases
alias reload-enhancements='reload_enhancements'
alias loading-status='show_loading_status'
alias test-lwd='test_lwd'
alias debug-on='export DOTFILES_DEBUG=true; echo "🐛 Debug enabled"'
alias debug-off='export DOTFILES_DEBUG=false; echo "🐛 Debug disabled"'

debug_log "Scripts.sh loaded successfully"
