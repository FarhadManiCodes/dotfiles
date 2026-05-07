#!/bin/bash
# Git Layout - Simple 2-window setup (Fixed for integration)
# ~/.config/tmux/layouts/git_layout.sh

# Accept session name as parameter, fallback to auto-generation
if [[ -n "$1" ]]; then
    SESSION_NAME="$1"
else
    SESSION_NAME="git-$(basename "$PWD")"
fi

cd "$PWD"

echo "🌳 Creating Git workspace: $SESSION_NAME"

# Create new session or use existing
if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    echo "⚠️  Session '$SESSION_NAME' already exists"
    exit 1
fi

# Create the session
tmux new-session -d -s "$SESSION_NAME" -c "$PWD"

# Window 1: Shell (rename the default window)
tmux rename-window -t "$SESSION_NAME:1" "shell"
tmux send-keys -t "$SESSION_NAME:shell" "clear" Enter
tmux send-keys -t "$SESSION_NAME:shell" "# Git repository shell" Enter
tmux send-keys -t "$SESSION_NAME:shell" "git status" Enter

# Window 2: Lazygit
tmux new-window -t "$SESSION_NAME" -n "lazygit" -c "$PWD"
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

echo "✅ Git layout ready!"
echo "📋 Windows: shell, lazygit"
echo "🎯 Session: $SESSION_NAME"

# Only attach if not being called from smart start (no TMUX_SMART_START env var)
if [[ -z "$TMUX_SMART_START" && -z "$TMUX" ]]; then
  echo "🎯 Attaching to session..."
  tmux attach-session -t "$SESSION_NAME"
fi
