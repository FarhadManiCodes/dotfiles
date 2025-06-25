#!/usr/bin/zsh
# TMux Smart Start - Fixed Integration Version
# This version properly integrates with layout scripts

# Ensure project detection functions are available
if ! type get_project_name >/dev/null 2>&1 || ! type get_project_types >/dev/null 2>&1; then
  local project_detection_script=""

  for location in \
    "$DOTFILES/zsh/productivity/project-detection.sh" \
    "$HOME/.config/zsh/productivity/project-detection.sh" \
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
    return 1
  fi

  if ! type get_project_name >/dev/null 2>&1 || ! type get_project_types >/dev/null 2>&1; then
    echo "❌ Project detection functions not available after loading"
    return 1
  fi
fi

# Get clean session name from project detection
get_session_name() {
  local session_name=$(get_project_name 2>/dev/null)

  if [[ -z "$session_name" ]]; then
    session_name=$(basename "$PWD")
  fi

  # Clean name for tmux compatibility
  session_name=$(echo "$session_name" | sed 's/[^a-zA-Z0-9_-]/_/g' | cut -c1-20)

  echo "$session_name"
}

# Check if should auto-start tmux
should_start_tmux() {
  [[ -n "$TMUX" ]] && return 1
  [[ ! -t 0 ]] && return 1
  [[ "$PWD" =~ ^(/tmp|/var|/proc|/sys|/dev|/run) ]] && return 1
  [[ -n "$VSCODE_INJECTION" || -n "$INSIDE_EMACS" ]] && return 1

  local current_dir=$(basename "$PWD")
  case "$current_dir" in
    "Downloads" | "Desktop" | "Documents" | "Pictures" | "Music" | "Videos" | "Public") return 1 ;;
  esac

  [[ "$PWD" == "$HOME" ]] && [[ ! -f ".project_name" && ! -f "pyproject.toml" && ! -f "package.json" && ! -d ".git" ]] && return 1

  return 0
}

# Determine best layout for project (priority order) - with caching
detect_layout() {
  # Check .projectrc cache first
  if _is_projectrc_fresh 2>/dev/null && _load_projectrc 2>/dev/null && [[ -n "$PROJECTRC_LAYOUT" ]]; then
    echo "$PROJECTRC_LAYOUT"
    return 0
  fi

  # Fall back to live detection
  local detected_types=($(get_project_types 2>/dev/null))
  [[ $? -ne 0 ]] && return 1

  # Convert to associative lookup for faster checking
  local -A type_map
  for type in "${detected_types[@]}"; do
    type_map[$type]=1
  done

  # Priority-based layout selection (exact order as specified)

  # 1. 🤖 ML Training (highest priority)
  if [[ -n "${type_map[ml_training]}" ]]; then
    echo "ml_training"
    return 0
  fi

  # 2. 🔧 ETL/Data Engineering
  if [[ -n "${type_map[etl]}" ]]; then
    echo "etl"
    return 0
  fi

  # 3. 📊 Data Science (jupyter + data combination, or analysis type)
  if [[ -n "${type_map[jupyter]}" && -n "${type_map[data]}" ]]; then
    echo "analysis"
    return 0
  fi

  # 4. 🗄️ SQL/Database
  if [[ -n "${type_map[sql]}" ]]; then
    echo "database"
    return 0
  fi

  # 5. 🐍 Python (includes python + data combinations)
  if [[ -n "${type_map[python]}" ]]; then
    echo "developer"
    return 0
  fi

  # 6. 🐳 Docker
  if [[ -n "${type_map[docker]}" ]]; then
    echo "docker"
    return 0
  fi

  # 7. 🌳 Git (lowest priority)
  if [[ -n "${type_map[git]}" ]]; then
    echo "git"
    return 0
  fi

  # Fallback to basic if no specific type detected
  echo "basic"
}

# Live layout detection (bypasses cache)
detect_layout_live() {
  local detected_types=($(get_project_types 2>/dev/null))
  [[ $? -ne 0 ]] && return 1

  # Convert to associative lookup for faster checking
  local -A type_map
  for type in "${detected_types[@]}"; do
    type_map[$type]=1
  done

  # Priority-based layout selection (exact order as specified)

  # 1. 🤖 ML Training (highest priority)
  if [[ -n "${type_map[ml_training]}" ]]; then
    echo "ml_training"
    return 0
  fi

  # 2. 🔧 ETL/Data Engineering
  if [[ -n "${type_map[etl]}" ]]; then
    echo "etl"
    return 0
  fi

  # 3. 📊 Data Science (jupyter + data combination, or analysis type)
  if [[ -n "${type_map[jupyter]}" && -n "${type_map[data]}" ]]; then
    echo "analysis"
    return 0
  fi

  # 4. 🗄️ SQL/Database
  if [[ -n "${type_map[sql]}" ]]; then
    echo "database"
    return 0
  fi

  # 5. 🐍 Python (includes python + data combinations)
  if [[ -n "${type_map[python]}" ]]; then
    echo "developer"
    return 0
  fi

  # 6. 🐳 Docker
  if [[ -n "${type_map[docker]}" ]]; then
    echo "docker"
    return 0
  fi

  # 7. 🌳 Git (lowest priority)
  if [[ -n "${type_map[git]}" ]]; then
    echo "git"
    return 0
  fi

  # Fallback to basic if no specific type detected
  echo "basic"
}

# Create new session with smart layout (SIMPLIFIED VERSION)
tmux-new-smart() {
  local force_layout="$1"
  local final_session_name="$2"

  # Generate the smart session name we want
  if [[ -z "$final_session_name" ]]; then
    final_session_name=$(get_session_name)
  fi

  echo "🎯 Target session name: $final_session_name"

  # Check if target name already exists
  if tmux has-session -t "$final_session_name" 2>/dev/null; then
    echo "⚠️  Session '$final_session_name' already exists - attaching"
    if [[ -n "$TMUX" ]]; then
      tmux switch-client -t "$final_session_name"
    else
      tmux attach-session -t "$final_session_name"
    fi
    return
  fi

  # Detect layout
  local layout_choice="${force_layout:-$(detect_layout)}"
  echo "🎨 Detected layout: $layout_choice"

  if [[ -z "$layout_choice" || "$layout_choice" == "basic" ]]; then
    echo "🚀 Creating basic tmux session: $final_session_name"
    tmux new-session -s "$final_session_name" -c "$PWD"
    return
  fi

  # Find layout script
  local layout_script=""
  for location in \
    "$HOME/dotfile/tmux/layouts/${layout_choice}_layout.sh" \
    "$HOME/.config/tmux/layouts/${layout_choice}_layout.sh" \
    "$DOTFILES/tmux/layouts/${layout_choice}_layout.sh" \
    "$HOME/dotfiles/tmux/layouts/${layout_choice}_layout.sh"; do
    if [[ -f "$location" ]]; then
      layout_script="$location"
      break
    fi
  done

  if [[ -z "$layout_script" ]]; then
    echo "⚠️  Layout script not found: ${layout_choice}_layout.sh"
    echo "💡 Searched locations:"
    echo "   - $HOME/dotfile/tmux/layouts/${layout_choice}_layout.sh"
    echo "   - $HOME/.config/tmux/layouts/${layout_choice}_layout.sh"
    echo "   - $DOTFILES/tmux/layouts/${layout_choice}_layout.sh"
    echo "   - $HOME/dotfiles/tmux/layouts/${layout_choice}_layout.sh"
    echo "💡 Creating basic tmux session instead"
    tmux new-session -s "$final_session_name" -c "$PWD"
    return
  fi

  if [[ ! -x "$layout_script" ]]; then
    echo "⚠️  Layout script not executable: $layout_script"
    echo "💡 Fix with: chmod +x $layout_script"
    echo "💡 Creating basic tmux session instead"
    tmux new-session -s "$final_session_name" -c "$PWD"
    return
  fi

  echo "🎨 Using layout script: $layout_script"
  echo "🚀 Creating session with $layout_choice layout..."

  # Set environment variable to prevent layout script from auto-attaching
  export TMUX_SMART_START=1

  # Run the layout script with session name parameter
  echo "📋 Running: $layout_script '$final_session_name'"

  if "$layout_script" "$final_session_name"; then
    echo "✅ Layout script completed successfully"

    # Verify session was created
    if tmux has-session -t "$final_session_name" 2>/dev/null; then
      echo "✅ Session '$final_session_name' created successfully"

      # Attach to the session
      if [[ -n "$TMUX" ]]; then
        echo "🔀 Switching to session..."
        tmux switch-client -t "$final_session_name"
      else
        echo "🎯 Attaching to session..."
        tmux attach-session -t "$final_session_name"
      fi
    else
      echo "❌ Session not found after layout script execution"
      echo "💡 Creating basic session as fallback"
      tmux new-session -s "$final_session_name" -c "$PWD"
    fi
  else
    echo "❌ Layout script failed (exit code: $?)"
    echo "💡 Creating basic session as fallback"
    tmux new-session -s "$final_session_name" -c "$PWD"
  fi

  # Clean up environment variable
  unset TMUX_SMART_START
}

# Smart tmux prompt (shows existing sessions and offers layout)
smart_tmux_prompt() {
  command -v tmux >/dev/null 2>&1 || return

  local project_name
  project_name=$(get_project_name 2>/dev/null)
  if [[ $? -ne 0 || -z "$project_name" ]]; then
    echo "❌ Could not detect project name"
    return 1
  fi

  # Check for existing sessions first
  local existing_sessions=""
  if tmux list-sessions >/dev/null 2>&1; then
    # Look for project-related sessions
    existing_sessions=$(tmux list-sessions 2>/dev/null | grep -E "^($project_name|$project_name-|.*-$project_name):")
  fi

  # If .projectrc exists but no layout is cached, and no sessions running, update it
  local project_root=$(_get_project_root 2>/dev/null)
  if [[ -f "$project_root/.projectrc" && -z "$existing_sessions" ]]; then
    if _load_projectrc 2>/dev/null && [[ -z "$PROJECTRC_LAYOUT" ]]; then
      echo "🔄 Updating .projectrc with detected layout..."
      local detected_layout=$(detect_layout_live)
      local project_types=$(get_project_types 2>/dev/null)
      _save_projectrc "$PROJECTRC_NAME" "$project_types" "$detected_layout"
      echo ""
    fi
  fi

  local layout_choice=$(detect_layout)

  # Show project info with emoji
  local emoji=""
  case "$layout_choice" in
    "ml_training") emoji="🤖" ;;
    "etl") emoji="🔧" ;;
    "database") emoji="🗄️" ;;
    "analysis") emoji="📊" ;;
    "developer") emoji="🐍" ;;
    "docker") emoji="🐳" ;;
    "git") emoji="🌳" ;;
  esac

  echo "🎯 $project_name${emoji:+ ($emoji $layout_choice)}"

  # Check for existing sessions
  if [[ -n "$existing_sessions" ]]; then
    echo "🔍 Project sessions:"
    echo "$existing_sessions" | head -2 | sed 's/^/  🎯 /'

    # Show other sessions (max 2)
    local other_sessions=""
    if tmux list-sessions >/dev/null 2>&1; then
      other_sessions=$(tmux list-sessions 2>/dev/null | grep -vE "^($project_name|$project_name-|.*-$project_name):" | head -2)
    fi
    [[ -n "$other_sessions" ]] && echo "📋 Others:" && echo "$other_sessions" | sed 's/^/  /'

    echo "💡 tmux attach -t $project_name"
    return
  fi

  # No existing sessions found - check if we should auto-create

  # If .projectrc exists, auto-create session without prompting
  if [[ -f "$project_root/.projectrc" ]]; then
    echo "✅ Project configured (.projectrc found)"

    # Show if layout was cached or live-detected
    if _load_projectrc 2>/dev/null && [[ -n "$PROJECTRC_LAYOUT" ]]; then
      echo "📋 Using cached layout: $layout_choice"
    else
      echo "🔍 Using live-detected layout: $layout_choice"
    fi

    echo "🚀 Auto-creating tmux session: $project_name with $layout_choice layout..."
    echo ""
    tmux-new-smart "$layout_choice" "$project_name"
    return
  fi

  # No .projectrc - show manual options
  if tmux list-sessions >/dev/null 2>&1; then
    echo "📋 Existing sessions:"
    tmux list-sessions -F "  #{session_name} (#{session_windows}w)" | head -3
    echo "💡 tmux attach  |  tmux-new"
  else
    echo "🚀 No sessions - would create '$project_name' with $layout_choice layout"
    echo "💡 Run: tmux-new"
    echo "💡 Or setup project config: project-setup"
  fi
}

# Enhanced tmux-new command
tmux-new-enhanced() {
  local suggested_name=$(get_session_name)
  echo -n "🎯 Session name [$suggested_name]: "
  read -r custom_name
  local session_name="${custom_name:-$suggested_name}"

  # Offer layout choice
  local suggested_layout=$(detect_layout)
  if [[ -n "$suggested_layout" && "$suggested_layout" != "basic" ]]; then
    echo -n "🎨 Use $suggested_layout layout? [Y/n]: "
    read -r -n 1 choice && echo
    if [[ $choice =~ ^[Nn]$ ]]; then
      suggested_layout="basic"
    fi
  fi

  tmux-new-smart "$suggested_layout" "$session_name"
}

# Session info utility
tmux-project-info() {
  local project_name=$(get_project_name 2>/dev/null)
  local layout_choice=$(detect_layout)

  echo "🎯 Project: ${project_name:-unknown}"
  echo "🎨 Suggested layout: $layout_choice"
  echo "📁 Path: $PWD"
  echo ""
  echo "🔧 Detected features:"
  local types=($(get_project_types 2>/dev/null))
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
    esac
  done

  # Show related sessions
  if tmux list-sessions >/dev/null 2>&1 && [[ -n "$project_name" ]]; then
    local related_sessions=$(tmux list-sessions 2>/dev/null | grep -E "^($project_name|$project_name-|.*-$project_name):")
    if [[ -n "$related_sessions" ]]; then
      echo ""
      echo "📋 Related sessions:"
      echo "$related_sessions" | sed 's/^/  /'
    fi
  fi
}

# Debug function to test integration
tmux-debug-integration() {
  echo "🔧 TMux Smart Start Integration Debug"
  echo "====================================="

  echo "📁 Current directory: $PWD"
  echo "🎯 Project name: $(get_project_name 2>/dev/null || echo 'FAILED')"
  echo "🏷️  Project types: $(get_project_types 2>/dev/null || echo 'FAILED')"

  # Show both cached and live layout detection
  local cached_layout=$(detect_layout 2>/dev/null || echo 'FAILED')
  local live_layout=$(detect_layout_live 2>/dev/null || echo 'FAILED')

  echo "🎨 Layout (cached): $cached_layout"
  if [[ "$cached_layout" != "$live_layout" ]]; then
    echo "🔍 Layout (live): $live_layout"
  fi

  echo "🔖 Session name: $(get_session_name 2>/dev/null || echo 'FAILED')"

  # Check .projectrc status
  echo ""
  echo "💾 Project Configuration:"
  local project_root=$(_get_project_root 2>/dev/null)
  if [[ -f "$project_root/.projectrc" ]]; then
    if _load_projectrc 2>/dev/null; then
      echo "  ✅ .projectrc found"
      echo "     Name: $PROJECTRC_NAME"
      echo "     Types: $PROJECTRC_TYPES"
      if [[ -n "$PROJECTRC_LAYOUT" ]]; then
        echo "     Layout: $PROJECTRC_LAYOUT (cached)"
      else
        echo "     Layout: Not cached (will be updated on next run)"
      fi

      if _is_projectrc_fresh 2>/dev/null; then
        echo "     Status: Fresh (auto-start enabled)"
      else
        echo "     Status: Stale (manual start required)"
      fi
    else
      echo "  ⚠️  .projectrc found but unreadable"
    fi
  else
    echo "  ❌ No .projectrc found (manual start required)"
    echo "  💡 Run 'project-setup' to enable auto-start and caching"
  fi

  echo ""
  echo "🎯 Layout Priority Order:"
  echo "  1. 🤖 ML Training → ml_training_layout.sh"
  echo "  2. 🔧 ETL/Data Engineering → etl_layout.sh"
  echo "  3. 📊 Data Science → analysis_layout.sh"
  echo "  4. 🗄️ SQL/Database → database_layout.sh"
  echo "  5. 🐍 Python → developer_layout.sh"
  echo "  6. 🐳 Docker → docker_layout.sh"
  echo "  7. 🌳 Git → git_layout.sh"

  echo ""
  echo "📂 Layout script locations:"
  local layout_choice="$cached_layout"
  for location in \
    "$HOME/dotfile/tmux/layouts/${layout_choice}_layout.sh" \
    "$HOME/.config/tmux/layouts/${layout_choice}_layout.sh" \
    "$DOTFILES/tmux/layouts/${layout_choice}_layout.sh" \
    "$HOME/dotfiles/tmux/layouts/${layout_choice}_layout.sh"; do
    if [[ -f "$location" ]]; then
      echo "  ✅ $location"
      [[ -x "$location" ]] && echo "     (executable)" || echo "     (NOT executable)"
    else
      echo "  ❌ $location"
    fi
  done

  echo ""
  echo "💡 Layout Caching:"
  echo "   - First run: Detects layout and caches in .projectrc"
  echo "   - Subsequent runs: Uses cached layout for consistency"
  echo "   - Manual override: Delete .projectrc to re-detect"
  echo ""
  echo "💡 To test: tmux-new-smart (or just open new terminal if .projectrc exists)"
}

# Aliases
alias project-setup='project-setup'
alias detect-layout-live='detect_layout_live'

# Auto-start trigger
if should_start_tmux; then
  smart_tmux_prompt
fi

# Always return success to avoid sourcing errors when already in tmux
true
