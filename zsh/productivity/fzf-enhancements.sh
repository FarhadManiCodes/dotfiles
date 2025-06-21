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
  local process
  process=$(ps aux --sort=-%mem |
    awk -v user="$USER" 'NR==1 || ($1 == user && $11 !~ /^\[.*\]$/)' |
    fzf --header-lines=1 \
      --preview='
        pid=$(echo {} | awk "{print \$2}")
        cmd=$(echo {} | awk "{print \$11}")
        mem=$(echo {} | awk "{print \$4}")
        cpu=$(echo {} | awk "{print \$3}")
        
        echo "📊 PID: $pid | CPU: ${cpu}% | Memory: ${mem}%"
        echo "💻 Command: $cmd"
        echo ""
        
        # Working directory and project detection
        workdir=$(readlink "/proc/$pid/cwd" 2>/dev/null)
        if [[ -n "$workdir" && -d "$workdir" ]]; then
          echo "📁 Working dir: $workdir"
          [[ -f "$workdir/requirements.txt" ]] && echo "   📦 Python project"
          [[ -f "$workdir/environment.yml" ]] && echo "   📦 Conda project"  
          [[ -d "$workdir/.git" ]] && echo "   🌳 Git repository"
        else
          echo "📁 Working dir: Not accessible"
        fi
        echo ""
        
        # Python-specific info
        if [[ "$cmd" == *python* ]] && command -v lsof >/dev/null 2>&1; then
          env_vars=$(cat "/proc/$pid/environ" 2>/dev/null | tr "\\0" "\\n")
          venv=$(echo "$env_vars" | grep "VIRTUAL_ENV=" | cut -d= -f2)
          if [[ -n "$venv" ]]; then
            echo "🐍 Environment: $(basename "$venv" 2>/dev/null || echo "venv")"
          else
            conda=$(echo "$env_vars" | grep "CONDA_DEFAULT_ENV=" | cut -d= -f2)
            echo "🐍 Environment: ${conda:-system}"
          fi
          
          # Single lsof call for efficiency
          lsof_output=$(lsof -p "$pid" 2>/dev/null)
          total_files=$(echo "$lsof_output" | wc -l)
          data_files=$(echo "$lsof_output" | grep -c -E "\\.(csv|parquet|pkl|json|h5|xlsx)$" || echo "0")
          echo "📊 Open data files: $data_files (of $total_files total)"
        fi
      ' \
      --preview-window=right:50% \
      --bind='ctrl-r:reload(ps aux --sort=-%mem | awk -v user="'"$USER"'" '"'"'NR==1 || ($1 == user && $11 !~ /^\[.*\]$/)'"'"')' \
      --header='🔍 Your Processes (memory sorted) | Ctrl+R: refresh')

  [[ -z "$process" ]] && return 0

  # Extract info and run actions
  local pid=$(echo "$process" | awk '{print $2}')
  local command=$(echo "$process" | awk '{print $11}')
  local mem=$(echo "$process" | awk '{print $4}')

  echo ""
  echo "🔍 Selected: PID $pid | Memory: ${mem}% | $(basename "$command")"
  echo ""

  # Action menu
  while true; do
    echo "Actions:"
    echo "  [w] Go to working directory"
    echo "  [i] Process info"
    echo "  [c] Copy PID"
    [[ "$command" == *python* ]] && echo "  [f] Show data files"
    echo "  [q] Quit"
    echo ""
    echo -n "Action: "

    local action
    read -k1 action
    echo ""

    case $action in
      w | W)
        local workdir=$(readlink "/proc/$pid/cwd" 2>/dev/null)
        if [[ -n "$workdir" && -d "$workdir" ]]; then
          cd "$workdir" || return 1
          echo "📁 → $(pwd)"
          break
        else
          echo "❌ Can't access working directory"
        fi
        ;;
      i | I)
        echo ""
        ps -p "$pid" -o pid,ppid,user,pcpu,pmem,etime,cmd 2>/dev/null || echo "Process not found"
        echo ""
        ;;
      c | C)
        if command -v wl-copy >/dev/null 2>&1; then
          echo -n "$pid" | wl-copy
          echo "📋 PID $pid copied (Wayland)"
        elif command -v xclip >/dev/null 2>&1; then
          echo -n "$pid" | xclip -selection clipboard
          echo "📋 PID $pid copied (X11)"
        else
          echo "📋 PID: $pid (no clipboard tool found - copy manually)"
        fi
        ;;
      f | F)
        if [[ "$command" == *python* ]] && command -v lsof >/dev/null 2>&1; then
          echo ""
          echo "📊 Data files:"
          lsof -p "$pid" 2>/dev/null | awk '$NF ~ /\.(csv|parquet|pkl|json|h5|xlsx)$/ {print $NF}' | head -10
          [[ $(lsof -p "$pid" 2>/dev/null | awk '$NF ~ /\.(csv|parquet|pkl|json|h5|xlsx)$/ {count++} END {print count+0}') -eq 0 ]] && echo "No data files open"
          echo ""
        fi
        ;;
      q | Q)
        break
        ;;
      *)
        echo "❌ Invalid choice"
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
  local original_dir="$PWD"

  # Get repos with increased count limit
  local repos=$(find . -maxdepth 6 -name ".git" -type d \
    -not -path "*/{node_modules,.venv,venv,.cache,build,dist}/*" 2>/dev/null |
    sed 's|/.git||' | head -100)

  if [ -z "$repos" ]; then
    echo "📭 No git repositories found"
    return 1
  fi

  local repo_count=$(echo "$repos" | wc -l)
  if [ "$repo_count" -eq 100 ]; then
    echo "⚠️  Showing first 100 repos (found more). Consider running from a more specific directory."
  fi

  while true; do
    local result=$(echo "$repos" |
      fzf --preview 'cd {} 2>/dev/null && 
                     echo "📂 $(basename {})" && 
                     echo "🌳 $(timeout 2 git branch --show-current 2>/dev/null || echo "unknown")" && 
                     echo "🌐 $(timeout 2 git remote -v 2>/dev/null | head -2 | sed "s/\t/ -> /" || echo "no remotes")" && 
                     echo "" && echo "📊 Git Status:" && 
                     timeout 3 git -c color.ui=always status --short --branch 2>/dev/null | head -8 || echo "  Could not load status" && 
                     echo "" && echo "📜 Recent commits:" && 
                     timeout 3 git log --oneline --color=always -5 2>/dev/null' \
        --ansi --preview-window='right:60%' \
        --expect 'ctrl-f,ctrl-l,ctrl-o' \
        --header="🔍 Git Repos ($repo_count found) | Enter: navigate | Ctrl+F: fetch | Ctrl+L: lazygit | Ctrl+O: open")

    local key=$(echo "$result" | head -1)
    local selected=$(echo "$result" | tail -1)

    [ -z "$selected" ] && break

    case "$key" in
      "ctrl-f")
        cd "$selected"
        echo "🔄 Fetching: $(basename "$selected")"
        echo "🌐 $(git remote -v | sed 's/\t/ -> /')"

        # Fetch only origin and upstream (5 second timeout)
        local fetch_success=false

        # Fetch origin if it exists
        if git remote | grep -q "^origin$"; then
          echo "📥 Fetching origin..."
          if timeout 5 git fetch origin --quiet 2>/dev/null; then
            echo "✅ Origin fetch successful"
            fetch_success=true
          else
            echo "❌ Origin fetch failed"
          fi
        fi

        # Fetch upstream if it exists and is different from origin
        if git remote | grep -q "^upstream$"; then
          echo "📥 Fetching upstream..."
          if timeout 5 git fetch upstream --quiet 2>/dev/null; then
            echo "✅ Upstream fetch successful"
            fetch_success=true
          else
            echo "❌ Upstream fetch failed"
          fi
        fi

        if [ "$fetch_success" = false ]; then
          echo "❌ No successful fetches"
        fi

        # Show status for relevant remote branches only
        echo ""
        echo "📈 Remote status:"
        for remote in origin upstream; do
          if git remote | grep -q "^$remote$"; then
            git branch -r | grep "^  $remote/" | grep -v "HEAD" | head -2 | while read branch; do
              ahead=$(git rev-list --count --max-count=100 "$branch"..HEAD 2>/dev/null || echo "?")
              behind=$(git rev-list --count --max-count=100 HEAD.."$branch" 2>/dev/null || echo "?")
              ahead_display="$ahead"
              behind_display="$behind"
              [ "$ahead" = "100" ] && ahead_display="100+"
              [ "$behind" = "100" ] && behind_display="100+"
              echo "  vs $branch: $ahead_display ahead, $behind_display behind"
            done
          fi
        done

        echo ""
        echo "📊 Current git status:"
        git -c color.ui=always status --short --branch | head -8
        echo ""
        echo "Press any key to return to repository selection..."
        read -n 1
        echo ""
        cd "$original_dir"
        continue
        ;;
      "ctrl-l")
        cd "$selected" && lazygit
        break
        ;;
      "ctrl-o")
        timeout 2 xdg-open "$selected" 2>/dev/null &
        continue
        ;;
      *)
        cd "$selected" && pwd
        break
        ;;
    esac
  done
}

# Enhanced Data & Model File Finder
fdata() {
  local result
  result=$(fd --type f \
    -e csv -e tsv -e jsonl -e ndjson \
    -e json -e yaml -e yml \
    -e parquet -e avro -e orc -e feather \
    -e xlsx -e xls \
    -e pkl -e pickle -e joblib \
    -e h5 -e hdf5 \
    -e pt -e pth -e onnx \
    --exclude __pycache__ --exclude .git --exclude node_modules --exclude .venv --exclude venv \
    --exclude "*.tmp" --exclude "*.cache" --exclude ".DS_Store" --exclude "__MACOSX" |
    fzf --preview='echo "📁 $(basename {})" && echo "📊 $(ls -lh {} 2>/dev/null | awk "{print \$5}" || echo "unknown")" && echo "" && 
                   if command -v bat >/dev/null 2>&1; then
                     bat --color=always --style=plain --line-range=:12 {} 2>/dev/null || head -8 {} 2>/dev/null
                   else
                     head -8 {} 2>/dev/null
                   fi' \
      --preview-window='right:40%' \
      --expect 'ctrl-d,ctrl-v' \
      --bind 'ctrl-o:execute(open $(dirname {}) 2>/dev/null || xdg-open $(dirname {}) 2>/dev/null &)' \
      --header '📊 Data & Model Files | Enter: edit | Ctrl+D: cd | Ctrl+V: copy path | Ctrl+O: open folder')

  local key=$(echo "$result" | head -1)
  local file=$(echo "$result" | tail -1)

  if [[ -n "$file" ]]; then
    case "$key" in
      ctrl-d)
        cd "$(dirname "$file")"
        echo "📁 Changed to: $(pwd)"
        echo "📁 File: $(basename "$file")"
        ;;
      ctrl-v)
        local full_path=$(realpath "$file" 2>/dev/null || echo "$file")
        if command -v wl-copy >/dev/null 2>&1; then
          echo -n "$full_path" | wl-copy
          echo "📋 Copied to clipboard: $full_path"
        elif command -v xclip >/dev/null 2>&1; then
          echo -n "$full_path" | xclip -selection clipboard
          echo "📋 Copied to clipboard: $full_path"
        else
          echo "📋 Path: $full_path (no clipboard tool found)"
        fi
        ;;
      *)
        # Default action: size-aware editing
        local size=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null || echo "0")
        if [[ "$size" -gt 50000000 ]]; then # Back to 10MB threshold
          echo "🚨 Large file detected (>10MB) - navigating to folder for safety"
          cd "$(dirname "$file")"
          echo "📁 Location: $(pwd)"
          echo "📁 File: $(basename "$file")"
        else
          echo "✏️  Opening: $(basename "$file")"
          "${EDITOR:-vim}" "$file"
        fi
        ;;
    esac
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
    nb) fnb ;;
    rg) frg ;;
    git) fgit ;;
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
