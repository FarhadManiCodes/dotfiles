#!/bin/bash
# Docker Layout - Simple 2-window setup
# ~/.config/tmux/layouts/docker_layout.sh

# Use passed session name or fallback to current session
SESSION_NAME="${1:-$(tmux display-message -p '#S' 2>/dev/null)}"

if [[ -z "$SESSION_NAME" ]]; then
  echo "❌ No session name provided and not in tmux"
  exit 1
fi

echo "🐳 Setting up Docker layout in session: $SESSION_NAME"

# Window 1: Shell (rename the existing window)
tmux rename-window -t "$SESSION_NAME:0" "shell"
tmux send-keys -t "$SESSION_NAME:shell" "clear" Enter
tmux send-keys -t "$SESSION_NAME:shell" "# Docker project shell" Enter
if [[ -f "docker-compose.yml" ]] || [[ -f "docker-compose.yaml" ]]; then
  tmux send-keys -t "$SESSION_NAME:shell" "docker-compose ps" Enter
elif [[ -f "Dockerfile" ]]; then
  tmux send-keys -t "$SESSION_NAME:shell" "docker images | head -5" Enter
else
  tmux send-keys -t "$SESSION_NAME:shell" "docker ps" Enter
fi

# Window 2: Lazydocker
tmux new-window -t "$SESSION_NAME" -n "lazydocker" -c "#{pane_current_path}"
if command -v lazydocker >/dev/null 2>&1; then
  tmux send-keys -t "$SESSION_NAME:lazydocker" "lazydocker" Enter
else
  tmux send-keys -t "$SESSION_NAME:lazydocker" "echo '❌ lazydocker not installed'" Enter
  tmux send-keys -t "$SESSION_NAME:lazydocker" "echo '💡 Install: https://github.com/jesseduffield/lazydocker'" Enter
  tmux send-keys -t "$SESSION_NAME:lazydocker" "echo ''" Enter
  tmux send-keys -t "$SESSION_NAME:lazydocker" "echo '🐳 Docker status:'" Enter
  tmux send-keys -t "$SESSION_NAME:lazydocker" "docker ps" Enter
  tmux send-keys -t "$SESSION_NAME:lazydocker" "echo ''" Enter
  tmux send-keys -t "$SESSION_NAME:lazydocker" "echo '📊 Images:'" Enter
  tmux send-keys -t "$SESSION_NAME:lazydocker" "docker images | head -5" Enter
fi

# Select shell window by default
tmux select-window -t "$SESSION_NAME:shell"

echo "✅ Docker layout ready in session: $SESSION_NAME"
