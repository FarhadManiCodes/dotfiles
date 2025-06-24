#!/bin/bash
# Git Layout - Simple 2-window setup
# ~/.config/tmux/layouts/git_layout.sh

# Use passed session name or fallback to current session
SESSION_NAME="${1:-$(tmux display-message -p '#S' 2>/dev/null)}"

if [[ -z "$SESSION_NAME" ]]; then
  echo "❌ No session name provided and not in tmux"
  exit 1
fi

echo "🌳 Setting up Git layout in session: $SESSION_NAME"

# Window 1: Shell (rename the existing window)
tmux rename-window -t "$SESSION_NAME:0" "shell"
tmux send-keys -t "$SESSION_NAME:shell" "clear" Enter
tmux send-keys -t "$SESSION_NAME:shell" "# Git repository shell" Enter
tmux send-keys -t "$SESSION_NAME:shell" "git status" Enter

# Window 2: Lazygit
tmux new-window -t "$SESSION_NAME" -n "lazygit" -c "#{pane_current_path}"
if command -v lazygit >/dev/null 2>&1; then
  tmux send-keys -t "$SESSION_NAME:lazygit" "lazygit" Enter
else
  tmux send-keys -t "$SESSION_NAME:lazygit" "echo '❌ lazygit not installed'" Enter
  tmux send-keys -t "$SESSION_NAME:lazygit" "echo '💡 Install: https://github.com/jesseduffield/lazygit'" Enter
  tmux send-keys -t "$SESSION_NAME:lazygit" "echo ''" Enter
  tmux send-keys -t "$SESSION_NAME:lazygit" "git log --oneline --graph -10" Enter
fi

# Select shell window by default
tmux select-window -t "$SESSION_NAME:shell"

echo "✅ Git layout ready in session: $SESSION_NAME"
