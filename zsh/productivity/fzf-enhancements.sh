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
    --exclude '*.pyc' --exclude '__pycache__' 2>/dev/null |
    fzf --preview 'if command -v bat >/dev/null 2>&1; then bat --theme=OneHalfDark --color=always --style=numbers --line-range :50 {} 2>/dev/null; else head -30 {} 2>/dev/null; fi' \
      --expect 'ctrl-d' \
      --header 'Enter: edit, Ctrl+D: cd to folder')

  local key=$(echo "$result" | head -1)
  local file=$(echo "$result" | tail -1)

  if [ -n "$file" ]; then
    if [ "$key" = "ctrl-d" ]; then
      cd "$(dirname "$file")" && pwd
    else
      ${EDITOR:-vim} "$file"
    fi
  fi
}

# Jupyter notebook finder
fnb() {
  local result=$(fd --type f --extension ipynb 2>/dev/null |
    fzf --preview 'echo "📊 Size: $(ls -lh {} 2>/dev/null | awk "{print \$5}" || echo "unknown")" && echo "📅 Modified: $(ls -l {} 2>/dev/null | awk "{print \$6, \$7, \$8}" || echo "unknown")" && echo "📝 Cells: $(jq ".cells | length" {} 2>/dev/null || echo "unknown")"' \
      --preview-window='right:30%' \
      --expect 'ctrl-d' \
      --bind 'ctrl-o:execute(timeout 2 xdg-open $(dirname {}) 2>/dev/null &)' \
      --header 'Enter: open notebook, Ctrl+D: cd to folder, Ctrl+O: open folder')

  local key=$(echo "$result" | head -1)
  local file=$(echo "$result" | tail -1)

  if [ -n "$file" ]; then
    local dir=$(dirname "$file")

    if [ "$key" = "ctrl-d" ]; then
      cd "$dir" && pwd
    else
      echo "📁 Changing to: $dir"
      cd "$dir"

      if [ -n "$TMUX" ]; then
        echo "🚀 Starting Jupyter in tmux..."
        tmux-jupyter-auto 2>/dev/null || echo "tmux-jupyter-auto not available"
      else
        echo "📓 Starting Jupyter notebook..."
        jupyter notebook "$(basename "$file")" 2>/dev/null || echo "Jupyter not available"
      fi
    fi
  fi
}

# Live grep with preview
frg() {
  local result=$(rg --column --line-number --no-heading --smart-case . 2>/dev/null |
    fzf --ansi --preview 'file=$(echo {} | cut -d: -f1) && line=$(echo {} | cut -d: -f2) && if command -v bat >/dev/null 2>&1; then bat --theme=OneHalfDark --color=always --style=numbers --highlight-line $line --line-range $(($line-5)):$(($line+15)) "$file" 2>/dev/null; else sed -n "$(($line-2)),$(($line+2))p" "$file" 2>/dev/null; fi' \
      --preview-window='right:60%' \
      --expect 'ctrl-d' \
      --bind 'ctrl-o:execute(timeout 2 xdg-open $(dirname $(echo {} | cut -d: -f1)) 2>/dev/null &)' \
      --header 'Enter: edit file, Ctrl+D: cd to folder, Ctrl+O: open folder')

  local key=$(echo "$result" | head -1)
  local match=$(echo "$result" | tail -1)

  if [ -n "$match" ]; then
    local file=$(echo "$match" | cut -d: -f1)
    local line=$(echo "$match" | cut -d: -f2)
    if [ "$key" = "ctrl-d" ]; then
      cd "$(dirname "$file")" && pwd
    else
      ${EDITOR:-vim} "+$line" "$file"
    fi
  fi
}

# Enhanced Python definition finder
fpydef() {
  local result=$(rg --vimgrep --type py '^(class|def)\s+\w+' 2>/dev/null |
    fzf --delimiter=':' --preview 'file=$(echo {} | cut -d: -f1) && line=$(echo {} | cut -d: -f2) && if command -v bat >/dev/null 2>&1; then bat --theme=OneHalfDark --color=always --style=numbers --highlight-line $line --line-range $(($line-5)):$(($line+15)) "$file" 2>/dev/null; else sed -n "$(($line-2)),$(($line+5))p" "$file" 2>/dev/null; fi' \
      --preview-window='right:60%' \
      --expect 'ctrl-d' \
      --bind 'ctrl-o:execute(timeout 2 xdg-open $(dirname $(echo {} | cut -d: -f1)) 2>/dev/null &)' \
      --header 'Enter: jump to definition, Ctrl+D: cd to folder, Ctrl+O: open folder')

  local key=$(echo "$result" | head -1)
  local match=$(echo "$result" | tail -1)

  if [ -n "$match" ]; then
    local file=$(echo "$match" | cut -d: -f1)
    local line=$(echo "$match" | cut -d: -f2)

    if [ "$key" = "ctrl-d" ]; then
      cd "$(dirname "$file")" && pwd
    else
      ${EDITOR:-vim} "+$line" "$file"
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
  local result=$(fd --type f '(requirements.*\.(txt|in)$|pyproject\.toml$|environment\.ya?ml$|Pipfile$)' 2>/dev/null |
    fzf --preview 'echo "📊 Lines: $(wc -l {} 2>/dev/null | cut -d" " -f1 || echo "unknown")" && echo "📅 Modified: $(ls -l {} 2>/dev/null | awk "{print \$6, \$7, \$8}" || echo "unknown")" && echo "--- Content (first 50 lines) ---" && if command -v bat >/dev/null 2>&1; then bat --theme=OneHalfDark --color=always --style=numbers --line-range :50 {} 2>/dev/null; else head -50 {} 2>/dev/null; fi' \
      --preview-window='right:60%' \
      --expect 'ctrl-d' \
      --bind 'ctrl-o:execute(timeout 2 xdg-open $(dirname {}) 2>/dev/null &)' \
      --header 'Enter: edit, Ctrl+D: cd to folder, Ctrl+O: open folder')

  local key=$(echo "$result" | head -1)
  local file=$(echo "$result" | tail -1)

  if [ -n "$file" ]; then
    if [ "$key" = "ctrl-d" ]; then
      cd "$(dirname "$file")" && pwd
    else
      ${EDITOR:-vim} "$file"
    fi
  fi
}

# Model file finder
fmodel() {
  local result=$(fd --type f -e h5 -e pt -e pth -e joblib -e onnx -e pkl -e pickle -e pb -e tflite -e safetensors -e bin 2>/dev/null |
    fzf --preview 'echo "📊 Size: $(ls -lh {} 2>/dev/null | awk "{print \$5}" || echo "unknown")" && echo "📅 Modified: $(ls -l {} 2>/dev/null | awk "{print \$6, \$7, \$8}" || echo "unknown")" && echo "🔍 Type: $(file {} 2>/dev/null | cut -d: -f2 | sed "s/^ *//" || echo "unknown")"' \
      --preview-window='right:35%' \
      --expect 'ctrl-d' \
      --bind 'ctrl-o:execute(timeout 2 xdg-open $(dirname {}) 2>/dev/null &)' \
      --header 'Enter: copy path, Ctrl+D: cd to folder, Ctrl+O: open folder')

  local key=$(echo "$result" | head -1)
  local file=$(echo "$result" | tail -1)

  if [ -n "$file" ]; then
    if [ "$key" = "ctrl-d" ]; then
      cd "$(dirname "$file")" && pwd
    else
      # Copy to clipboard with Ubuntu support
      if command -v wl-copy >/dev/null 2>&1; then
        echo -n "$file" | wl-copy
        echo "📋 Copied to clipboard (Wayland): $file"
      elif command -v xclip >/dev/null 2>&1; then
        echo -n "$file" | xclip -selection clipboard
        echo "📋 Copied to clipboard (X11): $file"
      else
        echo "📁 Model path: $file"
        echo "💡 No clipboard tool found (install wl-clipboard or xclip)"
      fi
    fi
  fi
}

# Enhanced Directory Browser - Tree Level 2
fdir() {
  local dir=$(fd --type d --max-depth 3 \
    --exclude .git --exclude __pycache__ --exclude .venv --exclude venv \
    --exclude node_modules --exclude .pytest_cache --exclude .mypy_cache \
    --exclude build --exclude dist --exclude "*.egg-info" --exclude .cache \
    --exclude .tmp --exclude tmp 2>/dev/null |
    fzf --preview 'echo "📁 Directory: $(basename {})" && files=$(find {} -maxdepth 1 -type f 2>/dev/null | wc -l) && dirs=$(find {} -maxdepth 1 -type d 2>/dev/null | wc -l) && dirs=$((dirs-1)) && echo "📄 Files: $files | 📁 Folders: $dirs" && echo "📊 Size: $(timeout 2 du -sh {} 2>/dev/null | cut -f1 || echo "unknown")" && echo "🔒 Permissions: $(ls -ld {} 2>/dev/null | cut -d" " -f1 || echo "unknown")" && echo "--- Tree Structure ---" && if command -v eza >/dev/null 2>&1; then eza --tree --level=2 --icons {} 2>/dev/null; else find {} -maxdepth 2 -type d 2>/dev/null | head -10 | sed "s|^{}/||" | sed "s|^|  |"; fi' \
      --preview-window='right:50%' \
      --expect 'ctrl-o' \
      --header='📁 Select directory | Enter: navigate | Ctrl+O: open folder')

  local key=$(echo "$dir" | head -1)
  local selected_dir=$(echo "$dir" | tail -1)

  if [ -n "$selected_dir" ]; then
    if [ "$key" = "ctrl-o" ]; then
      echo "🗂️ Opening folder: $selected_dir"
      timeout 2 xdg-open "$selected_dir" 2>/dev/null &
    else
      cd "$selected_dir" && pwd
      echo ""
      echo "📋 Current directory contents:"
      if command -v eza >/dev/null 2>&1; then
        eza --long --icons 2>/dev/null | head -10
      else
        ls -la | head -10
      fi
    fi
  fi
}

# Enhanced Process Browser - Safer and More Useful
fproc() {
  # Filter to user processes only (exclude system/kernel processes)
  local process=$(ps aux |
    awk 'NR==1 || ($1 != "root" && $1 != "daemon" && $1 != "nobody" && $11 !~ /^\[.*\]$/)' |
    fzf --header-lines=1 \
      --preview 'pid=$(echo {} | awk "{print \$2}") && 
                   echo "\033[1;36m🔍 Process Details\033[0m" &&
                   echo "PID: $pid | User: $(echo {} | awk "{print \$1}") | Command: $(echo {} | awk "{print \$11}")" &&
                   echo "" &&
                   echo "\033[1;35m🌳 Process Tree:\033[0m" &&
                   pstree -p $pid 2>/dev/null | head -10 || ps --forest -o pid,ppid,cmd -g $(ps -o pgrp= -p $pid 2>/dev/null) 2>/dev/null | head -10 || echo "Process tree not available" &&
                   echo "" &&
                   echo "\033[1;33m📁 Open Files (top 5):\033[0m" &&
                   lsof -p $pid 2>/dev/null | head -6 | tail -5 || echo "No open files or lsof not available" &&
                   echo "" &&
                   echo "\033[1;32m🌐 Network Connections:\033[0m" &&
                   netstat -tulpn 2>/dev/null | grep $pid | head -3 || ss -tulpn 2>/dev/null | grep $pid | head -3 || echo "No network connections"' \
      --preview-window=right:65% \
      --header='🔍 Select process (user processes only)')

  if [ -z "$process" ]; then
    return 0
  fi

  # Extract process info
  local pid=$(echo "$process" | awk '{print $2}')
  local user=$(echo "$process" | awk '{print $1}')
  local command=$(echo "$process" | awk '{print $11}')

  echo ""
  echo "🔍 Selected Process:"
  echo "   PID: $pid"
  echo "   User: $user"
  echo "   Command: $command"
  echo ""

  # Safe action menu
  while true; do
    echo "🛡️  Safe Process Actions:"
    echo ""
    echo "  [i] Show detailed process information"
    echo "  [f] Show open files (lsof)"
    echo "  [n] Show network connections"
    echo "  [t] Show process tree"
    echo "  [e] Show environment variables"
    echo "  [w] Navigate to working directory"
    echo "  [c] Copy PID to clipboard"
    echo "  [l] Show recent logs (if available)"
    echo "  [q] Quit"
    echo ""
    echo -n "Choose action: "

    read -k1 action
    echo ""
    echo ""

    case $action in
      i | I)
        echo "📋 Detailed Process Information:"
        echo "================================"
        ps -p $pid -o pid,ppid,user,pcpu,pmem,etime,nice,cmd 2>/dev/null || echo "Process no longer exists"
        echo ""
        echo "📊 Memory Details:"
        cat /proc/$pid/status 2>/dev/null | grep -E "(VmPeak|VmSize|VmRSS|VmData)" 2>/dev/null || echo "Memory info not available"
        echo ""
        echo "Press any key to continue..."
        read -k1
        echo ""
        ;;
      f | F)
        echo "📁 Open Files:"
        echo "=============="
        lsof -p $pid 2>/dev/null || echo "No open files or lsof not available"
        echo ""
        echo "Press any key to continue..."
        read -k1
        echo ""
        ;;
      n | N)
        echo "🌐 Network Connections:"
        echo "======================"
        echo "TCP connections:"
        netstat -tulpn 2>/dev/null | grep $pid || ss -tulpn 2>/dev/null | grep $pid || echo "No network connections"
        echo ""
        echo "Press any key to continue..."
        read -k1
        echo ""
        ;;
      t | T)
        echo "🌳 Process Tree:"
        echo "==============="
        pstree -p $pid 2>/dev/null || ps --forest -o pid,ppid,cmd -g $(ps -o pgrp= -p $pid 2>/dev/null) 2>/dev/null || echo "Process tree not available"
        echo ""
        echo "Press any key to continue..."
        read -k1
        echo ""
        ;;
      e | E)
        echo "🔧 Environment Variables:"
        echo "========================"
        if [ -r "/proc/$pid/environ" ]; then
          cat /proc/$pid/environ 2>/dev/null | tr '\0' '\n' | head -20
          echo ""
          echo "(showing first 20 variables)"
        else
          echo "Environment variables not accessible"
        fi
        echo ""
        echo "Press any key to continue..."
        read -k1
        echo ""
        ;;
      w | W)
        echo "📂 Working Directory:"
        echo "===================="
        local workdir=$(readlink /proc/$pid/cwd 2>/dev/null)
        if [ -n "$workdir" ] && [ -d "$workdir" ]; then
          echo "Process working directory: $workdir"
          echo -n "Navigate to this directory? [y/N]: "
          read -k1 confirm
          echo ""
          if [[ $confirm =~ ^[Yy]$ ]]; then
            cd "$workdir"
            echo "📁 Changed to: $(pwd)"
            break
          fi
        else
          echo "Working directory not accessible or process no longer exists"
        fi
        echo ""
        ;;
      c | C)
        echo "📋 Copying PID to clipboard..."
        if command -v xclip >/dev/null 2>&1; then
          echo -n "$pid" | xclip -selection clipboard
          echo "✅ PID $pid copied to clipboard (X11)"
        elif command -v wl-copy >/dev/null 2>&1; then
          echo -n "$pid" | wl-copy
          echo "✅ PID $pid copied to clipboard (Wayland)"
        elif command -v pbcopy >/dev/null 2>&1; then
          echo -n "$pid" | pbcopy
          echo "✅ PID $pid copied to clipboard (macOS)"
        else
          echo "📋 PID: $pid (copy manually - no clipboard tool found)"
        fi
        echo ""
        ;;
      l | L)
        echo "📜 Recent Logs:"
        echo "=============="
        echo "Checking journalctl for this process..."
        if command -v journalctl >/dev/null 2>&1; then
          journalctl _PID=$pid --lines=10 --no-pager 2>/dev/null || echo "No logs found in journal"
        else
          echo "journalctl not available"
        fi
        echo ""
        echo "Press any key to continue..."
        read -k1
        echo ""
        ;;
      q | Q)
        echo "👋 Exiting process browser"
        break
        ;;
      *)
        echo "❌ Invalid choice. Please try again."
        echo ""
        ;;
    esac
  done
}

# Enhanced History Search - Streamlined edit-first approach
fhist() {
  local selected=$(fc -l 1 |
    fzf --tac \
      --preview 'cmd=$(echo {} | sed "s/^[[:space:]]*[0-9]*[[:space:]]*//") && 
                   first_word=$(echo "$cmd" | awk "{print \$1}") && 
                   echo "📝 Command: $cmd" && echo "" && echo "⚠️  Safety check:" && 
                   if ! type "$first_word" >/dev/null 2>&1; then 
                     echo "❓ Could not assess safety (unknown command: $first_word)" 
                   else 
                     case "$cmd" in 
                       *"rm -rf"*|*"sudo rm"*|*"mkfs"*|*"dd if="*) echo "🚨 DANGEROUS command" ;; 
                       *"sudo"*) echo "⚠️  Uses sudo" ;; 
                       *">"*|*">>"*) echo "⚠️  File redirection" ;; 
                       *"curl"*|*"wget"*) echo "🌐 Network download" ;; 
                       *) echo "✅ Appears safe" ;; 
                     esac 
                   fi' \
      --preview-window='right:40%' \
      --header='📚 Select command to edit and run')

  [[ -z "$selected" ]] && return 0

  local cmd=$(echo "$selected" | sed 's/^[[:space:]]*[0-9]*[[:space:]]*//')

  echo -e "\n✏️  Edit command (Esc to cancel):\n"

  if command -v vared >/dev/null 2>&1; then
    local edited_cmd="$cmd"
    vared edited_cmd
    cmd="$edited_cmd"
  else
    read -e -i "$cmd" cmd
  fi

  if [[ -n "$cmd" ]]; then
    echo -e "\n🚀 Executing: $cmd\n"
    eval "$cmd"
  else
    echo "❌ Cancelled"
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

# to find data
fdata() {
  local result=$(fd --type f \
    -e csv -e json -e parquet -e xlsx -e pkl -e pickle -e h5 -e hdf5 -e yaml -e yml \
    -e tsv -e jsonl -e ndjson -e avro -e feather -e orc -e npy -e npz \
    -e db -e sqlite -e sqlite3 -e arrow -e xml -e bson -e msgpack \
    --exclude __pycache__ --exclude .git --exclude node_modules --exclude .venv --exclude venv \
    --exclude "*.tmp" --exclude "*.log" --exclude ".DS_Store" --exclude "*.cache" --exclude "__MACOSX" 2>/dev/null |
    fzf --preview 'echo "📊 Size: $(ls -lh {} 2>/dev/null | awk "{print \$5}" || echo "unknown")" && echo "📅 Modified: $(ls -l {} 2>/dev/null | awk "{print \$6, \$7, \$8}" || echo "unknown")" && echo "--- Preview (30 lines) ---" && if command -v bat >/dev/null 2>&1; then bat --color=always --style=numbers --line-range=:30 {} 2>/dev/null; else head -30 {} 2>/dev/null; fi' \
      --preview-window='right:50%' \
      --expect 'ctrl-d' \
      --bind 'ctrl-o:execute(timeout 2 xdg-open $(dirname {}) 2>/dev/null &)' \
      --header '📊 Data Files | Enter: edit | Ctrl+D: cd | Ctrl+O: open folder')

  local key=$(echo "$result" | head -1)
  local file=$(echo "$result" | tail -1)

  if [[ -n "$file" ]]; then
    if [[ "$key" = "ctrl-d" ]]; then
      cd "$(dirname "$file")" && pwd
    else
      # Size check for safety
      local size=$(stat -c%s "$file" 2>/dev/null || echo "0")
      if [[ "$size" -gt 10000000 ]]; then
        echo "🚨 Large file (>10MB) - navigating to folder for safety"
        cd "$(dirname "$file")" && pwd
      else
        ${EDITOR:-vim} "$file"
      fi
    fi
  fi
}
# Enhanced general file finder
ff() {
  local result=$(fd --type f \
    -e py -e ipynb -e sql -e csv -e json -e yaml -e yml -e md -e sh -e toml -e txt \
    -e js -e go -e rs -e c -e cpp -e scala -e log \
    -e env -e ini -e conf -e cfg -e dockerfile -e properties -e gitignore -e dockerignore \
    -e lock -e makefile \
    --exclude .git --exclude __pycache__ --exclude .venv --exclude venv \
    --exclude "*.tmp" --exclude ".DS_Store" --exclude "*.cache" --exclude "__MACOSX" 2>/dev/null |
    fzf --preview 'echo "📊 Size: $(ls -lh {} 2>/dev/null | awk "{print \$5}" || echo "unknown")" && echo "📅 Modified: $(ls -l {} 2>/dev/null | awk "{print \$6, \$7, \$8}" || echo "unknown")" && echo "--- Preview ---" && if command -v bat >/dev/null 2>&1; then bat --color=always --style=numbers --line-range=:30 {} 2>/dev/null; else head -30 {} 2>/dev/null; fi' \
      --preview-window='right:50%' \
      --expect 'ctrl-d' \
      --bind 'ctrl-o:execute(timeout 2 xdg-open $(dirname {}) 2>/dev/null &)' \
      --header '📁 Files | Enter: edit | Ctrl+D: cd | Ctrl+O: open folder')

  local key=$(echo "$result" | head -1)
  local file=$(echo "$result" | tail -1)

  if [ -n "$file" ]; then
    if [ "$key" = "ctrl-d" ]; then
      cd "$(dirname "$file")" && pwd
    else
      # Size check for safety
      local size=$(stat -c%s "$file" 2>/dev/null || echo "0")
      if [ "$size" -gt 10000000 ]; then
        echo "🚨 Large file (>10MB) - navigating to folder for safety"
        cd "$(dirname "$file")" && pwd
        echo "📁 File: $(basename "$file")"
      else
        ${EDITOR:-vim} "$file"
      fi
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

echo "✅ Enhanced FZF functions loaded!"
