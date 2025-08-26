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

# Enhanced tmux-new command with full layout selection
tmux-new-with-layout-selection() {
  local suggested_name=$(get_session_name)
  echo -n "🎯 Session name [$suggested_name]: "
  read -r custom_name
  local session_name="${custom_name:-$suggested_name}"

  # Get suggested layout
  local suggested_layout=$(detect_layout)
  local suggested_index=1

  # Define all available layouts with descriptions
  local -a layouts=(
    "basic:🏠 Basic - Simple single window setup"
    "ml_training:🤖 ML Training - Model development & monitoring"
    "etl:🔧 ETL/Data Engineering - Pipeline development"
    "analysis:📊 Data Science - Jupyter & data analysis"
    "database:🗄️ Database - SQL development & querying"
    "developer:🐍 Python - General development environment"
    "docker:🐳 Docker - Container development"
    "git:🌳 Git - Version control focused"
  )

  # Find suggested layout index
  for i in {1..${#layouts[@]}}; do
    local layout_key="${layouts[$i]%%:*}"
    if [[ "$layout_key" == "$suggested_layout" ]]; then
      suggested_index=$i
      break
    fi
  done

  echo ""
  echo "🎨 Available layouts:"
  echo ""

  # Display layouts with numbers
  for i in {1..${#layouts[@]}}; do
    local layout_entry="${layouts[$i]}"
    local layout_key="${layout_entry%%:*}"
    local layout_desc="${layout_entry#*:}"

    if [[ "$layout_key" == "$suggested_layout" ]]; then
      echo "  [$i] $layout_desc ⭐ (suggested)"
    else
      echo "  [$i] $layout_desc"
    fi
  done

  echo ""
  echo -n "Select layout [1-${#layouts[@]}] (Enter for suggested #$suggested_index): "
  read -r choice

  # Parse choice
  local selected_layout="$suggested_layout"
  if [[ -n "$choice" && "$choice" =~ ^[0-9]+$ ]]; then
    if [[ "$choice" -ge 1 && "$choice" -le "${#layouts[@]}" ]]; then
      selected_layout="${layouts[$choice]%%:*}"
    else
      echo "❌ Invalid choice, using suggested layout: $suggested_layout"
    fi
  elif [[ -n "$choice" ]]; then
    echo "❌ Invalid input, using suggested layout: $suggested_layout"
  fi

  echo ""
  echo "🚀 Creating session '$session_name' with '$selected_layout' layout..."
  tmux-new-smart "$selected_layout" "$session_name"
}

# Alternative: Quick layout selection using fzf if available
tmux-new-fzf() {
  if ! command -v fzf >/dev/null 2>&1; then
    echo "❌ fzf not found, falling back to standard selection"
    tmux-new-with-layout-selection
    return
  fi

  local suggested_name=$(get_session_name)
  echo -n "🎯 Session name [$suggested_name]: "
  read -r custom_name
  local session_name="${custom_name:-$suggested_name}"

  # Get suggested layout
  local suggested_layout=$(detect_layout)

  # Define all available layouts for fzf
  local layout_options=(
    "🏠 basic - Simple single window setup"
    "🤖 ml_training - Model development & monitoring"
    "🔧 etl - ETL/Data Engineering pipeline development"
    "📊 analysis - Data Science with Jupyter & analysis tools"
    "🗄️ database - SQL development & database querying"
    "🐍 developer - Python general development environment"
    "🐳 docker - Container development environment"
    "🌳 git - Version control focused workspace"
  )

  # Find suggested layout for default selection
  local default_option=""
  for option in "${layout_options[@]}"; do
    if [[ "$option" =~ $suggested_layout ]]; then
      default_option="$option ⭐ (suggested)"
      break
    fi
  done

  echo ""
  echo "🎨 Select layout (suggested: $suggested_layout):"

  # Use fzf for selection
  local selected_option
  if [[ -n "$default_option" ]]; then
    # Add suggested marker to options
    local enhanced_options=()
    for option in "${layout_options[@]}"; do
      if [[ "$option" =~ $suggested_layout ]]; then
        enhanced_options+=("$option ⭐ (suggested)")
      else
        enhanced_options+=("$option")
      fi
    done

    selected_option=$(printf '%s\n' "${enhanced_options[@]}" | fzf --height=12 --layout=reverse --border --prompt="Layout: " --preview="echo 'Press Enter to select this layout'")
  else
    selected_option=$(printf '%s\n' "${layout_options[@]}" | fzf --height=12 --layout=reverse --border --prompt="Layout: " --preview="echo 'Press Enter to select this layout'")
  fi

  # Extract layout name from selection
  local selected_layout
  if [[ -n "$selected_option" ]]; then
    selected_layout=$(echo "$selected_option" | sed 's/^[^ ]* \([^ ]*\) -.*/\1/' | sed 's/ ⭐.*//')
  else
    echo "❌ No selection made, using suggested layout: $suggested_layout"
    selected_layout="$suggested_layout"
  fi

  echo ""
  echo "🚀 Creating session '$session_name' with '$selected_layout' layout..."
  tmux-new-smart "$selected_layout" "$session_name"
}

# Quick layout override function
tmux-new-quick() {
  local layout="$1"
  local session_name="$2"

  if [[ -z "$layout" ]]; then
    echo "Usage: tmux-new-quick <layout> [session_name]"
    echo ""
    echo "Available layouts:"
    echo "  basic, ml_training, etl, analysis, database, developer, docker, git"
    return 1
  fi

  local final_session_name="${session_name:-$(get_session_name)}"
  echo "🚀 Creating session '$final_session_name' with '$layout' layout..."
  tmux-new-smart "$layout" "$final_session_name"
}

# Layout info function to see what's available
tmux-layouts() {
  local current_layout=$(detect_layout)

  echo "🎨 Available TMux Layouts"
  echo "========================"
  echo ""
  echo "Current project suggestion: $current_layout"
  echo ""

  echo "📋 All available layouts:"
  echo ""
  echo "  🏠 basic         - Simple single window setup"
  echo "  🤖 ml_training   - Model development & monitoring with MLflow"
  echo "  🔧 etl           - ETL/Data Engineering pipeline development"
  echo "  📊 analysis      - Data Science with Jupyter & analysis tools"
  echo "  🗄️ database      - SQL development & database querying"
  echo "  🐍 developer     - Python general development environment"
  echo "  🐳 docker        - Container development environment"
  echo "  🌳 git           - Version control focused workspace"
  echo ""

  echo "🚀 Usage examples:"
  echo "  tmux-new                    # Interactive selection"
  echo "  tmux-new-quick developer    # Direct layout selection"
  echo "  tmux-new-fzf               # FZF-powered selection"
  echo ""

  # Show which layout scripts exist
  echo "📂 Layout script status:"
  local layouts=(basic ml_training etl analysis database developer docker git)
  for layout in "${layouts[@]}"; do
    local script_found=false
    for location in \
      "$HOME/dotfile/tmux/layouts/${layout}_layout.sh" \
      "$HOME/.config/tmux/layouts/${layout}_layout.sh" \
      "$DOTFILES/tmux/layouts/${layout}_layout.sh" \
      "$HOME/dotfiles/tmux/layouts/${layout}_layout.sh"; do
      if [[ -f "$location" ]]; then
        if [[ -x "$location" ]]; then
          echo "  ✅ $layout (executable)"
        else
          echo "  ⚠️  $layout (not executable)"
        fi
        script_found=true
        break
      fi
    done
    [[ "$script_found" == false ]] && echo "  ❌ $layout (script missing)"
  done
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
