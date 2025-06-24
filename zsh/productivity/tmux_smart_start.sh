# Optimized tmux smart start using existing project detection functions

# Ensure project detection functions are available
if ! type get_project_name >/dev/null 2>&1 || ! type is_project_type >/dev/null 2>&1 || ! type get_project_types >/dev/null 2>&1; then
  # Try to load project detection functions
  local project_detection_script=""
  
  # Look for project detection script in common locations
  for location in \
    "$DOTFILES/zsh/productivity/project-detection.sh" \
    "$HOME/.config/zsh/project-detection.sh" \
    "$HOME/dotfiles/zsh/productivity/project-detection.sh"; do
    if [[ -f "$location" ]]; then
      project_detection_script="$location"
      break
    fi
  done
  
  if [[ -n "$project_detection_script" ]]; then
    echo "🔧 Loading project detection from: $project_detection_script"
    source "$project_detection_script"
  else
    echo "❌ Project detection functions not found"
    echo "💡 Create project-detection.sh with your is_project_type and get_project_name functions"
    return 1
  fi
  
  # Verify functions are now available
  if ! type get_project_name >/dev/null 2>&1; then
    echo "❌ get_project_name function still not available after loading"
    return 1
  fi
fi

# Generate session name based on project context
generate_session_name() {
  local session_name=""

  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    # In git repo
    local repo_name=$(basename "$(git rev-parse --show-toplevel)")
    local branch=$(git branch --show-current 2>/dev/null)

    if [[ -n "$branch" && "$branch" != "main" && "$branch" != "master" ]]; then
      # Feature branch: repo-branch
      session_name="${repo_name}-${branch}"
    else
      # Main branch: just repo name
      session_name="$repo_name"
    fi
  else
    # Not in git: use folder name
    session_name=$(basename "$PWD")
  fi

  # Clean name and handle duplicates
  session_name=$(echo "$session_name" | sed 's/[^a-zA-Z0-9_-]/_/g' | cut -c1-20)

  # Add number if session exists
  if tmux has-session -t "$session_name" 2>/dev/null; then
    local counter=2
    while tmux has-session -t "${session_name}-${counter}" 2>/dev/null; do
      counter=$((counter + 1))
    done
    session_name="${session_name}-${counter}"
  fi

  echo "$session_name"
}

# Enhanced should_start_tmux (unchanged - already optimized)
should_start_tmux() {
  [[ -n "$TMUX" ]] && return 1
  [[ ! -t 0 ]] && return 1
  [[ "$PWD" =~ ^(/tmp|/var|/proc|/sys|/dev|/run) ]] && return 1
  [[ -n "$VSCODE_INJECTION" || -n "$INSIDE_EMACS" ]] && return 1
  
  local current_dir=$(basename "$PWD")
  case "$current_dir" in
    "Downloads"|"Desktop"|"Documents"|"Pictures"|"Music"|"Videos"|"Public") return 1 ;;
  esac
  
  # Only auto-start in home if it looks like a project
  [[ "$PWD" == "$HOME" ]] && [[ ! -f ".project_name" && ! -f "pyproject.toml" && ! -f "package.json" && ! -d ".git" ]] && return 1
  
  return 0
}

# Centralized project type and layout detection (zsh-compatible)
_detect_project_layout() {
  local detected_types=($(get_project_types))
  local project_type=""
  local layout_choice=""
  local emoji=""
  
  # Helper function to check if array contains element (zsh-compatible)
  _has_type() {
    local target="$1"
    local type
    for type in "${detected_types[@]}"; do
      [[ "$type" == "$target" ]] && return 0
    done
    return 1
  }
  
  # Priority order for layout selection (most specific first)
  if _has_type "ml_training"; then
    project_type="ml"
    layout_choice="ml_training"
    emoji="🤖"
  elif _has_type "etl"; then
    project_type="de"
    layout_choice="etl"
    emoji="🔧"
  elif _has_type "sql"; then
    project_type="db"
    layout_choice="database"
    emoji="🗄️"
  elif _has_type "jupyter" && _has_type "data"; then
    project_type="ds"
    layout_choice="analysis"
    emoji="📊"
  elif _has_type "python" && _has_type "data"; then
    project_type="de"
    layout_choice="analysis"
    emoji="📊"
  elif _has_type "python"; then
    project_type="py"
    layout_choice="developer"
    emoji="🐍"
  elif _has_type "docker"; then
    project_type="docker"
    layout_choice="docker"
    emoji="🐳"
  elif _has_type "git"; then
    project_type="git"
    layout_choice="git"
    emoji="🌳"
  fi
  
  # Return results via variables (to avoid subshell)
  DETECTED_PROJECT_TYPE="$project_type"
  DETECTED_LAYOUT="$layout_choice"
  DETECTED_EMOJI="$emoji"
}

# Apply layout based on choice
_apply_layout() {
  local session_name="$1"
  local layout_choice="$2"
  local silent="${3:-false}"
  
  case "$layout_choice" in
    "analysis")
      [[ "$silent" != "true" ]] && echo "📊 + analysis layout"
      (sleep 1 && ~/.config/tmux/layouts/analysis_layout.sh "$session_name") &
      ;;
    "ml_training")
      [[ "$silent" != "true" ]] && echo "🤖 + ML training layout"
      (sleep 1 && ~/.config/tmux/layouts/ml_training_layout.sh "$session_name") &
      ;;
    "database")
      [[ "$silent" != "true" ]] && echo "🗄️ + database layout"
      (sleep 1 && ~/.config/tmux/layouts/database_layout.sh "$session_name") &
      ;;
    "etl")
      [[ "$silent" != "true" ]] && echo "🔧 + ETL layout"
      (sleep 1 && ~/.config/tmux/layouts/etl_layout.sh "$session_name") &
      ;;
    "developer")
      [[ "$silent" != "true" ]] && echo "🐍 + developer layout"
      (sleep 1 && ~/.config/tmux/layouts/developer_layout.sh "$session_name") &
      ;;
    "docker")
      [[ "$silent" != "true" ]] && echo "🐳 + docker layout"
      (sleep 1 && ~/.config/tmux/layouts/docker_layout.sh "$session_name") &
      ;;
    "git")
      [[ "$silent" != "true" ]] && echo "🌳 + git layout"
      (sleep 1 && ~/.config/tmux/layouts/git_layout.sh "$session_name") &
      ;;
  esac
}

# Get layout description for user prompts
_get_layout_description() {
  local layout="$1"
  case "$layout" in
    "ml_training") echo "🤖 Use ML training layout? [y/N]: " ;;
    "analysis") echo "📊 Use analysis layout? [y/N]: " ;;
    "etl") echo "🔧 Use ETL layout? [y/N]: " ;;
    "database") echo "🗄️ Use database layout? [y/N]: " ;;
    "developer") echo "🐍 Use developer layout? [y/N]: " ;;
    "docker") echo "🐳 Use docker layout? [y/N]: " ;;
    "git") echo "🌳 Use git layout? [y/N]: " ;;
    *) echo "" ;;
  esac
}

# Optimized smart tmux prompt
smart_tmux_prompt() {
  command -v tmux >/dev/null 2>&1 || return
  
  local project_name=$(get_project_name)
  project_name="${project_name##*:}"  # Extract just the name part
  
  # Detect project type and layout
  _detect_project_layout
  
  echo "🎯 $project_name${DETECTED_PROJECT_TYPE:+ ($DETECTED_EMOJI $DETECTED_PROJECT_TYPE)}"
  
  # Find project sessions (simplified)
  local project_sessions=""
  if tmux list-sessions >/dev/null 2>&1; then
    project_sessions=$(tmux list-sessions 2>/dev/null | grep -E "^($project_name|$project_name-|.*-$project_name):")
  fi
  
  if [[ -n "$project_sessions" ]]; then
    # Show project sessions
    echo "🔍 Project sessions:"
    echo "$project_sessions" | head -2 | sed 's/^/  🎯 /'
    
    # Show other sessions (max 2)
    local other_sessions=$(tmux list-sessions 2>/dev/null | grep -vE "^($project_name|$project_name-|.*-$project_name):" | head -2)
    [[ -n "$other_sessions" ]] && echo "📋 Others:" && echo "$other_sessions" | sed 's/^/  /'
    
    echo "💡 tmux attach -t $project_name"
    
  elif tmux list-sessions >/dev/null 2>&1; then
    echo "📋 Sessions:"
    tmux list-sessions -F "  #{session_name} (#{session_windows}w)" | head -3
    echo "💡 tmux attach  |  tmux-new"
    
  else
    echo "🚀 No sessions - creating $project_name"
    
    # Auto-create with smart layout
    local session_name=$(generate_session_name)
    tmux new-session -d -s "$session_name" -c "$PWD"
    
    # Apply layout if detected
    [[ -n "$DETECTED_LAYOUT" ]] && _apply_layout "$session_name" "$DETECTED_LAYOUT"
    
    echo "✅ Attaching to $session_name"
    sleep 1
    tmux attach-session -t "$session_name"
  fi
}

# Optimized tmux-new
tmux-new-enhanced() {
  local suggested_name=$(generate_session_name)
  echo -n "🎯 Session name [$suggested_name]: "
  read -r custom_name
  local session_name="${custom_name:-$suggested_name}"
  
  if tmux has-session -t "$session_name" 2>/dev/null; then
    echo "⚠️  Exists - attaching to $session_name"
    tmux attach-session -t "$session_name"
    return
  fi
  
  tmux new-session -d -s "$session_name" -c "$PWD"
  
  # Detect project layout
  _detect_project_layout
  
  # Offer layout if detected
  if [[ -n "$DETECTED_LAYOUT" ]]; then
    local layout_prompt=$(_get_layout_description "$DETECTED_LAYOUT")
    if [[ -n "$layout_prompt" ]]; then
      echo -n "$layout_prompt"
      read -r -n 1 choice && echo
      if [[ $choice =~ ^[Yy]$ ]]; then
        _apply_layout "$session_name" "$DETECTED_LAYOUT"
      fi
    fi
  fi
  
  tmux attach-session -t "$session_name"
}

# Enhanced session info (bonus utility)
tmux-project-info() {
  local project_name=$(get_project_name)
  project_name="${project_name##*:}"
  
  _detect_project_layout
  
  echo "🎯 Project: $project_name"
  echo "🔍 Type: ${DETECTED_EMOJI:-❓} ${DETECTED_PROJECT_TYPE:-unknown}"
  echo "🎨 Layout: ${DETECTED_LAYOUT:-default}"
  echo "📁 Path: $PWD"
  echo ""
  echo "🔧 Detected features:"
  local types=($(get_project_types))
  for type in "${types[@]}"; do
    case "$type" in
      "python") echo "  🐍 Python" ;;
      "data") echo "  📊 Data files" ;;
      "jupyter") echo "  📓 Jupyter notebooks" ;;
      "sql") echo "  🗃️ SQL/Database" ;;
      "etl") echo "  🔄 ETL/Pipeline" ;;
      "ml_training") echo "  🤖 ML Training" ;;
      "docker") echo "  🐳 Docker" ;;
      "git") echo "  🌳 Git repository" ;;
      "config") echo "  ⚙️ Configuration" ;;
    esac
  done
  
  # Show related sessions
  if tmux list-sessions >/dev/null 2>&1; then
    local related_sessions=$(tmux list-sessions 2>/dev/null | grep -E "^($project_name|$project_name-|.*-$project_name):")
    if [[ -n "$related_sessions" ]]; then
      echo ""
      echo "📋 Related sessions:"
      echo "$related_sessions" | sed 's/^/  /'
    fi
  fi
}

# Keep existing alias structure
alias tmux-new-basic='tmux-new'
alias tmux-new='tmux-new-enhanced'
alias tmux-info='tmux-project-info'

# Auto-start trigger (unchanged)
should_start_tmux && smart_tmux_prompt
