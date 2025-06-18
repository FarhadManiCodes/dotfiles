#!/usr/bin/env zsh
# Set One Half theme for bat
export BAT_THEME="OneHalfDark"

# Configure FZF with toggleable preview
export FZF_DEFAULT_OPTS="
--height 40%
--layout=reverse
--border
--color=fg:#dcdfe4,bg:#282c34,hl:#e06c75
--color=fg+:#dcdfe4,bg+:#2c323c,hl+:#e06c75
--color=info:#61afef,prompt:#98c379,pointer:#c678dd
--color=marker:#e5c07b,spinner:#56b6c2,header:#56b6c2
--bind 'ctrl-p:toggle-preview'
--preview-window 'right:50%:hidden'"

# Use fd with sensible defaults
export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git --exclude **pycache**'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"

# Enhanced Python file finder
fp() {
  local result=$(fd --type f --extension py \
    --exclude '*.pyc' --exclude '__pycache__' |
    fzf --preview 'bat --theme=OneHalfDark --color=always --style=numbers,changes,header --line-range :300 {}' \
      --expect 'ctrl-d' \
      --bind 'ctrl-o:execute(open $(dirname {}) 2>/dev/null || xdg-open $(dirname {}) 2>/dev/null || nautilus $(dirname {}) 2>/dev/null &)' \
      --header 'Enter: edit, Ctrl+D: cd to folder, Ctrl+O: open folder')

  local key=$(echo "$result" | head -1)
  local file=$(echo "$result" | tail -1)

  if [ -n "$file" ]; then
    if [ "$key" = "ctrl-d" ]; then
      cd "$(dirname "$file")"
      pwd
    else
      vim "$file"
    fi
  fi
}

# Jupyter notebook finder
fnb() {
  local result=$(fd --type f --extension ipynb |
    fzf --preview 'jq -r ".cells[] | .source[]" {} | bat --theme=OneHalfDark --language python --style=grid' \
      --expect 'ctrl-d' \
      --bind 'ctrl-o:execute(open $(dirname {}) 2>/dev/null || xdg-open $(dirname {}) 2>/dev/null || nautilus $(dirname {}) 2>/dev/null &)' \
      --header 'Enter: open notebook, Ctrl+D: cd to folder only, Ctrl+O: open folder')

  local key=$(echo "$result" | head -1)
  local file=$(echo "$result" | tail -1)

  if [ -n "$file" ]; then
    local dir=$(dirname "$file")

    if [ "$key" = "ctrl-d" ]; then
      cd "$dir"
      pwd
    else
      echo "📁 Changing to: $dir"
      cd "$dir"

      if [ -n "$TMUX" ]; then
        echo "🚀 Starting Jupyter in tmux..."
        tmux-jupyter-auto
      else
        echo "📓 Starting Jupyter notebook..."
        jupyter notebook "$(basename "$file")"
      fi
    fi
  fi
}

# Live grep with preview
frg() {
  local result=$(rg --column --line-number --no-heading --smart-case . |
    fzf --ansi --preview 'bat --theme=OneHalfDark --color=always --style=numbers,changes --highlight-line {2} {1}' \
      --expect 'ctrl-d' \
      --bind 'ctrl-o:execute(open $(dirname {1}) 2>/dev/null || xdg-open $(dirname {1}) 2>/dev/null || nautilus $(dirname {1}) 2>/dev/null &)' \
      --header 'Enter: edit file, Ctrl+D: cd to folder, Ctrl+O: open folder')

  local key=$(echo "$result" | head -1)
  local match=$(echo "$result" | tail -1)

  if [ -n "$match" ]; then
    local file=$(echo "$match" | awk -F: '{print $1}')
    if [ "$key" = "ctrl-d" ]; then
      cd "$(dirname "$file")"
      pwd
    else
      vim "$file"
    fi
  fi
}

# Enhanced Python definition finder
fpydef() {
  local result=$(rg --vimgrep '^(class|def)\s+\w+' |
    fzf --delimiter=':' --preview 'bat --theme=OneHalfDark --color=always --style=numbers,changes --highlight-line {2} {1}' \
      --expect 'ctrl-d' \
      --bind 'ctrl-o:execute(open $(dirname {1}) 2>/dev/null || xdg-open $(dirname {1}) 2>/dev/null || nautilus $(dirname {1}) 2>/dev/null &)' \
      --header 'Enter: jump to definition, Ctrl+D: cd to folder, Ctrl+O: open folder')

  local key=$(echo "$result" | head -1)
  local match=$(echo "$result" | tail -1)

  if [ -n "$match" ]; then
    local file=$(echo "$match" | awk -F: '{print $1}')
    local line=$(echo "$match" | awk -F: '{print $2}')
    local col=$(echo "$match" | awk -F: '{print $3}')

    if [ "$key" = "ctrl-d" ]; then
      cd "$(dirname "$file")"
      pwd
    else
      vim "+call cursor($line,$col)" "$file"
    fi
  fi
}

# Docker container finder
fdc() {
  docker ps -a --format 'table {{.ID}}\t{{.Image}}\t{{.Status}}\t{{.Names}}' |
    fzf --header-lines=1 \
      --delimiter='\t' \
      --preview 'echo "Container: {4}" && echo "ID: {1}" && echo "Image: {2}" && echo "Status: {3}" && echo "========== LOGS ==========" && docker logs --tail 15 {1} 2>&1' \
      --preview-window 'right:50%:hidden'
}

# Requirements.txt viewer
freq() {
  local result=$(fd --type f 'requirements.*\.(txt|in)$' |
    fzf --preview 'bat --theme=OneHalfDark --color=always {}' \
      --expect 'ctrl-d' \
      --bind 'ctrl-o:execute(open $(dirname {}) 2>/dev/null || xdg-open $(dirname {}) 2>/dev/null || nautilus $(dirname {}) 2>/dev/null &)' \
      --header 'Enter: edit requirements, Ctrl+D: cd to folder, Ctrl+O: open folder')

  local key=$(echo "$result" | head -1)
  local file=$(echo "$result" | tail -1)

  if [ -n "$file" ]; then
    if [ "$key" = "ctrl-d" ]; then
      cd "$(dirname "$file")"
      pwd
    else
      vim "$file"
    fi
  fi
}

# Model file finder
fmodel() {
  local result=$(fd --type f -e h5 -e pt -e pth -e joblib -e onnx |
    fzf --preview 'echo "Model File: {}" && echo "Size: $(ls -lh {} | awk "{print \$5}")" && echo "Type: $(file {} | cut -d: -f2)"' \
      --expect 'ctrl-d' \
      --bind 'ctrl-o:execute(open $(dirname {}) 2>/dev/null || xdg-open $(dirname {}) 2>/dev/null || nautilus $(dirname {}) 2>/dev/null &)' \
      --header 'Enter: select model, Ctrl+D: cd to folder, Ctrl+O: open folder')

  local key=$(echo "$result" | head -1)
  local file=$(echo "$result" | tail -1)

  if [ -n "$file" ]; then
    if [ "$key" = "ctrl-d" ]; then
      cd "$(dirname "$file")"
      pwd
    else
      echo "Selected model: $file"
    fi
  fi
}

# Directory browser
fdir() {
  local dir=$(fd --type d --max-depth 3 \
    --exclude .git --exclude __pycache__ --exclude .venv --exclude venv |
    fzf --preview 'echo "Directory: {}" && echo "Files:" && ls -la {} | head -10')
  [ -n "$dir" ] && cd "$dir" && pwd
}

# Process browser
fproc() {
  local process=$(ps aux |
    fzf --header-lines=1 --preview 'echo "Process Details:" && ps -p $(echo {} | awk "{print \$2}") -o pid,ppid,user,pcpu,pmem,etime,command 2>/dev/null')
  if [ -n "$process" ]; then
    local pid=$(echo "$process" | awk '{print $2}')
    echo "Selected PID: $pid"
    echo "Actions: [k]ill [s]ignal [q]uit"
    read -k1 action
    case $action in
      k) kill "$pid" && echo "\nKilled process $pid" ;;
      s) echo "\nEnter signal (TERM/KILL/STOP/CONT): " && read signal && kill -"$signal" "$pid" ;;
      *) echo "\nNo action taken" ;;
    esac
  fi
}

# History search
fhist() {
  local cmd=$(fc -l 1 |
    fzf --tac --preview 'echo "Command:" && echo {} | sed "s/^[[:space:]]*[0-9]*[[:space:]]*//" | bat --theme=OneHalfDark --language=bash --style=plain' |
    sed 's/^[[:space:]]*[0-9]*[[:space:]]*//')
  if [ -n "$cmd" ]; then
    echo "Executing: $cmd"
    eval "$cmd"
  fi
}

# Git repository finder

fgit() {
  find . -name ".git" -type d |
    sed 's|/.git||' |
    fzf --preview 'cd {} && echo "\033[1;36m📊 Repository: $(basename {})\033[0m" && echo "\033[1;32m🌳 Branch: $(git branch --show-current)\033[0m" && echo "\033[1;33m📁 Status:\033[0m" && git -c color.status=always status --short --branch | head -5 && echo "\033[1;35m📜 Recent commits:\033[0m" && git log --oneline -3 --color=always' \
      --ansi \
      --preview-window=right:60% \
      --header="🔍 Select git repository"
}

# Data file browser
fdata() {
  local result=$(fd --type f -e csv -e json -e parquet -e xlsx -e pkl -e h5 \
    --exclude __pycache__ |
    fzf --preview 'echo "Data File: {}" && echo "Size: $(ls -lh {} | awk "{print \$5}")" && echo "Preview:" && head -10 {}' \
      --expect 'ctrl-d' \
      --bind 'ctrl-o:execute(open $(dirname {}) 2>/dev/null || xdg-open $(dirname {}) 2>/dev/null || nautilus $(dirname {}) 2>/dev/null &)' \
      --header 'Enter: edit data file, Ctrl+D: cd to folder, Ctrl+O: open folder')

  local key=$(echo "$result" | head -1)
  local file=$(echo "$result" | tail -1)

  if [ -n "$file" ]; then
    if [ "$key" = "ctrl-d" ]; then
      cd "$(dirname "$file")"
      pwd
    else
      vim "$file"
    fi
  fi
}

# Enhanced general file finder
ff() {
  local result=$(fd --type f \
    -e py -e ipynb -e sql -e csv -e json -e yaml -e yml -e md -e sh -e toml \
    --exclude .git --exclude __pycache__ --exclude .venv --exclude venv |
    fzf --preview 'bat --theme=OneHalfDark --color=always --style=numbers,changes,header --line-range :300 {}' \
      --expect 'ctrl-d' \
      --bind 'ctrl-o:execute(open $(dirname {}) 2>/dev/null || xdg-open $(dirname {}) 2>/dev/null || nautilus $(dirname {}) 2>/dev/null &)' \
      --header 'Enter: edit file, Ctrl+D: cd to folder, Ctrl+O: open folder')

  local key=$(echo "$result" | head -1)
  local file=$(echo "$result" | tail -1)

  if [ -n "$file" ]; then
    if [ "$key" = "ctrl-d" ]; then
      cd "$(dirname "$file")"
      pwd
    else
      vim "$file"
    fi
  fi
}

# Main dispatcher
fzf-enhanced() {
  case "$1" in
    py) fp ;;
    nb) fnb ;;
    rg) frg ;;
    pydef) fpydef ;;
    dc) fdc ;;
    git) fgit ;;
    req) freq ;;
    model) fmodel ;;
    dir) fdir ;;
    proc) fproc ;;
    hist) fhist ;;
    data) fdata ;;
    file) ff ;;
    *) echo "Available commands:" &&
      echo "  📁 With folder navigation: py, nb, file, data, req, model, rg, pydef" &&
      echo "  🔍 Search/Navigate: dir, git, hist" &&
      echo "  ⚙️  System: proc, dc" ;;
  esac
}

# Key bindings
bindkey -s '^f' 'fzf-enhanced^M'

echo "✅ Enhanced FZF functions loaded!"
echo "💡 Use: Ctrl+F then choose from:"
echo "   📁 Files (with folder nav): py, nb, file, data, req, model, rg, pydef"
echo "   🔍 Navigate: dir, git"
echo "   📚 Search: hist"
echo "   ⚙️  System: proc, dc"
echo ""
echo "🎹 Folder navigation keybindings:"
echo "   Ctrl+D: cd to folder"
echo "   Ctrl+O: open folder in file manager"
echo ""
echo "📓 Special: nb (notebooks) auto-detects tmux and activates venv"
echo "🌳 Special: git shows branch, commits, and repo status"
