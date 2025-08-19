#!/usr/bin/env zsh
# ============================================================================
# ZSH Configuration (No Oh My Zsh) - Data Engineering/MLOps Optimized
# ============================================================================

# Performance profiling (matching your current setup)
ZSH_PROFILE=true
zmodload zsh/zprof

# ============================================================================
# POWERLEVEL10K INSTANT PROMPT
# ============================================================================
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Disable slow SSH detection (matching your current setup)
typeset -g POWERLEVEL9K_SSH=false

# ============================================================================
# ZSH OPTIONS & SETTINGS
# ============================================================================

# History configuration
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt SHARE_HISTORY
setopt HIST_EXPIRE_DUPS_FIRST
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_FIND_NO_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_SAVE_NO_DUPS
setopt HIST_REDUCE_BLANKS
setopt INC_APPEND_HISTORY

# Zsh Directory Stack (matching your current settings)
setopt AUTO_PUSHD
setopt PUSHD_IGNORE_DUPS
setopt PUSHD_SILENT

# Completion
setopt COMPLETE_IN_WORD
setopt ALWAYS_TO_END
setopt AUTO_MENU
setopt AUTO_LIST
setopt AUTO_PARAM_SLASH
setopt FLOW_CONTROL

# Globbing
setopt EXTENDED_GLOB
setopt NO_CASE_GLOB
setopt NUMERIC_GLOB_SORT

# Other useful options
setopt CORRECT
setopt INTERACTIVE_COMMENTS
setopt NO_BEEP

# ============================================================================
# VI MODE (Enhanced Native Implementation)
# ============================================================================
set -o vi
bindkey -v
export KEYTIMEOUT=1

# VI Mode cursor settings (matching your current setup)
VI_MODE_SET_CURSOR=true
VI_MODE_CURSOR_NORMAL=1
VI_MODE_CURSOR_VISUAL=6
VI_MODE_CURSOR_INSERT=6
VI_MODE_CURSOR_OPPEND=0

# Cursor shapes for different vi modes
function zle-keymap-select {
  case $KEYMAP in
    vicmd)      print -n '\e[1 q';;  # block cursor (normal mode)
    viins|main) print -n '\e[6 q';;  # beam cursor (insert mode)
  esac
}
zle -N zle-keymap-select

function zle-line-init {
  print -n '\e[6 q'  # beam cursor on startup
}
zle -N zle-line-init

# Fix terminal on exit
function zle-line-finish {
  print -n '\e[1 q'  # block cursor
}
zle -N zle-line-finish

# Vi-mode key bindings
bindkey '^P' up-history
bindkey '^N' down-history
bindkey '^?' backward-delete-char
bindkey '^h' backward-delete-char
bindkey '^w' backward-kill-word
bindkey '^r' history-incremental-search-backward
bindkey '^s' history-incremental-search-forward
bindkey '^a' beginning-of-line
bindkey '^e' end-of-line

# Add this to prevent repeated expensive operations
if [[ -n "${_ZSHRC_LOADED:-}" && -z "$TMUX" ]]; then
  return
fi
export _ZSHRC_LOADED="true-$$-$(date +%s)"
# ============================================================================
# COMPLETIONS
# ============================================================================
autoload -Uz compinit

# Smart compinit - only run once per day for performance
if [[ -n ~/.zcompdump(#qN.mh+24) ]]; then
  compinit -d ~/.zcompdump
else
  compinit -C -d ~/.zcompdump
fi

# Completion styles
zstyle ':completion:*' menu select
zstyle ':completion:*' group-name ''
zstyle ':completion:*' verbose yes
zstyle ':completion:*' special-dirs true
zstyle ':completion:*' squeeze-slashes true
zstyle ':completion:*:descriptions' format '%B%F{green}%d%f%b'
zstyle ':completion:*:messages' format '%F{yellow}%d%f'
zstyle ':completion:*:warnings' format '%F{red}No matches found%f'

# Case-insensitive completion
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'

# Colors for completion
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}

# Custom completions directory
fpath=(~/.config/zsh/completions $fpath)



# ============================================================================
# PLUGIN REPLACEMENTS
# ============================================================================
#
# Autosuggestions (load early)
if [[ -f ~/.config/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh ]]; then
  source ~/.config/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
  ZSH_AUTOSUGGEST_STRATEGY=(history completion)
  ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=30
  # ↑ Prevents lag on huge commands
  ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#5c6370,underline"
  # ↑ Subtle, doesn't interfere with completion menus
fi

# Fast syntax highlighting (replacement for zsh-syntax-highlighting)
if [[ -f ~/.config/zsh/plugins/fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh ]]; then
  # XDG config location (preferred)
  source ~/.config/zsh/plugins/fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh
fi

# GitHub CLI completion (replacement for gh plugin)
if command -v gh >/dev/null 2>&1; then
  if [[ -f ~/.config/zsh/completions/_gh ]]; then
    # Use cached completion
    autoload -U ~/.config/zsh/completions/_gh
  else
    # Generate and cache completion
    eval "$(gh completion -s zsh)"
  fi
fi

# History substring search (perfect for complex commands)
if [[ -f ~/.config/zsh/plugins/zsh-history-substring-search/zsh-history-substring-search.zsh ]]; then
  source ~/.config/zsh/plugins/zsh-history-substring-search/zsh-history-substring-search.zsh
  # Vi-mode friendly bindings
  bindkey '^[[A' history-substring-search-up
  bindkey '^[[B' history-substring-search-down
  bindkey -M vicmd 'k' history-substring-search-up
  bindkey -M vicmd 'j' history-substring-search-down
fi

export FORGIT_NO_ALIASES=1  # ← Tells forgit "don't create ga, gd, glo"
# Forgit (interactive git with fzf)
if [[ -f ~/.config/zsh/plugins/forgit/forgit.plugin.zsh ]]; then
  source ~/.config/zsh/plugins/forgit/forgit.plugin.zsh
fi

# ============================================================================
# REPLACEMENT FUNCTIONS (for Oh My Zsh features)
# ============================================================================

# Gitignore function (replacement for gitignore plugin)
gi() {
  if [ $# -eq 0 ]; then
    echo "Usage: gi <template1> [template2] ..."
    echo "Available templates: https://www.toptal.com/developers/gitignore"
    return 1
  fi
  
  curl -sL "https://www.toptal.com/developers/gitignore/api/$*"
}

# Last working directory (replacement for last-working-dir plugin)
function chpwd() {
  # Only save if we're in an interactive shell and not in temp directories
  [[ -o interactive ]] && [[ ! "$PWD" =~ ^/(tmp|var) ]] && pwd > ~/.last_dir
}

# Load last directory on startup (optional - uncomment if you want this behavior)
# if [[ -f ~/.last_dir ]] && [[ "$PWD" == "$HOME" ]]; then
#   cd "$(cat ~/.last_dir)" 2>/dev/null || true
# fi

# Enhanced directory navigation with fzf (if available)
function d() {
  if command -v fzf >/dev/null 2>&1; then
    local dir
    dir=$(dirs -v | fzf --height=40% | awk '{print $2}') && cd "${dir/#\~/$HOME}"
  else
    dirs -v
  fi
}

# ============================================================================
# LAZY LOADING FOR PERFORMANCE
# ============================================================================

# Lazy load expensive completions
lazy_load_completions() {
  echo "Loading additional completions..."
  
  # Docker completion
  if command -v docker >/dev/null 2>&1; then
    source <(docker completion zsh) 2>/dev/null && echo "  ✅ Docker"
  fi
  
  # Kubectl completion
  if command -v kubectl >/dev/null 2>&1; then
    source <(kubectl completion zsh) 2>/dev/null && echo "  ✅ Kubectl"
  fi
  
  # Terraform completion
  if command -v terraform >/dev/null 2>&1; then
    complete -C terraform terraform 2>/dev/null && echo "  ✅ Terraform"
  fi
}

# ============================================================================
# PYTHON CONFIGURATION (matching your current setup)
# ============================================================================
alias python=python3.13

# ============================================================================
# CUSTOM CONFIGURATION (Your existing setup)
# ============================================================================


# Load your existing scripts
if [[ -f "$DOTFILES/zsh/scripts.sh" ]]; then
  source "$DOTFILES/zsh/scripts.sh"
fi

# Load your existing aliases
if [[ -f "$XDG_CONFIG_HOME/zsh/aliases" ]]; then
  source "$XDG_CONFIG_HOME/zsh/aliases"
fi
# Load P10k config (matching your current setup)
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh

# ============================================================================
# UTILITY FUNCTIONS
# ============================================================================

# Quick reload function
reload() {
  source ~/.zshrc
  echo "✅ Zsh configuration reloaded"
}

# Performance testing
zsh_benchmark() {
  echo "🏃 Running zsh startup benchmark (10 iterations)..."
  for i in {1..10}; do
    time zsh -i -c exit
  done
}

# Show loaded features
show_zsh_info() {
  echo "🔌 Loaded Zsh Features:"
  echo "  Theme: Powerlevel10k (standalone)"
  [[ -n "${functions[fast-highlight]}" ]] && echo "  ✅ Fast Syntax Highlighting"
  [[ -n "${functions[_gh]}" ]] && echo "  ✅ GitHub CLI completions"
  echo "  ✅ Native Vi-mode with cursor shapes"
  echo "  ✅ Enhanced completions"
  echo "  ✅ All your custom functions"
  echo ""
  echo "📊 Performance:"
  echo "  Functions loaded: ${#functions[@]}"
  echo "  Aliases loaded: ${#aliases[@]}"
  echo "  Completion cache: ~/.zcompdump"
}

# ============================================================================
# ALIASES
# ============================================================================
alias load-completions='lazy_load_completions'
alias zsh-info='show_zsh_info'
alias zsh-reload='reload'
alias zsh-benchmark='zsh_benchmark'

# Directory navigation (for the directory stack functionality)
alias d='d'  # Use our enhanced d function

# ============================================================================
# FINAL SETUP
# ============================================================================

# Create completion cache directory if it doesn't exist
[[ ! -d ~/.config/zsh/completions ]] && mkdir -p ~/.config/zsh/completions

# Performance profiling results (matching your current setup)
if [[ "$ZSH_PROFILE" == "true" ]]; then
  zprof > ~/.zsh_profile_output.txt
fi

[[ "$TERM_PROGRAM" == "kiro" ]] && . "$(kiro --locate-shell-integration-path zsh)"

. "$HOME/.config/local/share/../bin/env"
