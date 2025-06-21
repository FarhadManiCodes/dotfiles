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
# Safe tmux auto-attach function
tmux_simple_prompt() {
  # Only run if not already in tmux
  [ -n "$TMUX" ] && return

  # Check if tmux is available
  command -v tmux >/dev/null 2>&1 || return

  # Skip in certain environments
  [ -n "$INSIDE_EMACS" ] && return
  [ -n "$VSCODE_INJECTION" ] && return

  if tmux list-sessions >/dev/null 2>&1; then
    # Sessions exist - show them and do nothing
    echo "🔍 TMux sessions:"
    tmux list-sessions -F "  📋 #{session_name} (#{session_windows} windows, created #{t:session_created})"
    echo ""
    echo "💡 Use: tmux attach -t <name> or tmux-new (new session)"
  else
    # No sessions - auto-start
    echo "🚀 No tmux sessions found, starting with restoration..."
    tmux-start
  fi
}

tmux_simple_prompt

source $DOTFILES/zsh/productivity/virtualenv.sh
source $DOTFILES/zsh/productivity/git-enhancements.sh
source $DOTFILES/zsh/productivity/fzf-enhancements.sh

# to zoxide to work
eval "$(zoxide init zsh)"
