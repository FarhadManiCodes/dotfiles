#!/bin/zsh
# activate the python v_end on the start
. "$HOME/.cargo/env"
# Go optimizations
source "$HOME/.cargo/env"

# Go interactive features
# Add any Go-specific shell functions or aliases here
# Example: alias gob='go build'

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

# tmux to start automatically when you open a terminal
# ============================================================================
# BASIC TMUX CONDITIONAL LOADING
# ============================================================================
# Basic function to decide if we should show tmux prompt
should_load_tmux_basic() {
  # Don't load if already in tmux
  [[ -n "$TMUX" ]] && return 1

  # Don't load if not interactive terminal
  [[ ! -t 0 ]] && return 1

  # Don't load in system directories (big performance saver)
  [[ "$PWD" =~ ^(/tmp|/var|/proc|/sys|/dev|/run) ]] && return 1

  # Don't load in IDE environments
  [[ -n "$VSCODE_INJECTION" ]] && return 1
  [[ -n "$INSIDE_EMACS" ]] && return 1

  # Don't load for quick SSH tasks (optional - comment out if you want tmux over SSH)
  [[ -n "$SSH_CONNECTION" && ! "$PWD" =~ (projects|work|dev) ]] && return 1

  # Load tmux for everything else
  return 0
}

basic_tmux_prompt() {
  # Quick exit if tmux isn't available
  command -v tmux >/dev/null 2>&1 || return

  if tmux list-sessions >/dev/null 2>&1; then
    # Sessions exist - show them briefly
    echo "🔍 TMux sessions:"
    tmux list-sessions -F "  📋 #{session_name} (#{session_windows} windows)"
    echo ""
    echo "💡 Use: tmux attach -t <name> or tmux-new"
  else
    # No sessions - offer to start
    echo "🚀 No tmux sessions found, starting with restoration..."
    tmux-start
  fi
}

if should_load_tmux_basic; then
  basic_tmux_prompt
fi

# ============================================================================
# PRODUCTIVITY SCRIPTS LOADING
# ============================================================================

# Load smart last working directory (always load - it's smart about when to activate)
if [[ -f "$DOTFILES/zsh/productivity/last-working-dir.sh" ]]; then
  source "$DOTFILES/zsh/productivity/last-working-dir.sh"
fi

# Load virtual environment management (conditional loading)
if [[ "$PWD" =~ (projects|work|learning|dev|\.py$|requirements\.txt|pyproject\.toml) ]] || [[ -n "$VIRTUAL_ENV" ]]; then
  source "$DOTFILES/zsh/productivity/virtualenv.sh"
fi

# Load git enhancements (conditional loading)
if git rev-parse --git-dir >/dev/null 2>&1 || [[ "$PWD" =~ (projects|work|dev|learning) ]]; then
  source "$DOTFILES/zsh/productivity/git-enhancements.sh"
else
  # Provide basic git aliases only
  alias gs='git status'
  alias ga='git add'
  alias gc='git commit'
  alias gp='git push'
  alias gpu='git pull'
fi

# Load enhanced completions (after other productivity scripts so functions are available)
if [[ -f "$DOTFILES/zsh/productivity/completions.sh" ]]; then
  source "$DOTFILES/zsh/productivity/completions.sh"
fi

# ============================================================================
# FZF LAZY LOADING SETUP
# ============================================================================
_setup_fzf_lazy_loading() {
  command -v fzf >/dev/null 2>&1 || return

  local _loaded=false
  local functions=(fnb frg fdir fproc fhist fdata ff fgit fzf-enhanced)

  _load_once() {
    if [[ "$_loaded" == "false" ]]; then
      source "$DOTFILES/zsh/productivity/fzf-enhancements.sh"
      _loaded=true
    fi
  }

  # Create all lazy functions in a loop
  for func in "${functions[@]}"; do
    eval "$func() { _load_once && $func \"\$@\"; }"
  done
}

# Enable the lazy loading
_setup_fzf_lazy_loading

# Load enhanced cli
if [[ -f "$DOTFILES/zsh/productivity/cli-enhancements.sh" ]]; then
  source "$DOTFILES/zsh/productivity/cli-enhancements.sh"
fi
# to zoxide to work
eval "$(zoxide init zsh)"
# Load enhanced completions
if [[ -f "$DOTFILES/zsh/productivity/completions.sh" ]]; then
  source "$DOTFILES/zsh/productivity/completions.sh"
fi
