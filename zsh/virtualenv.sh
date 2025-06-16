# =============================================================================
# Smart Project Detection & Environment Management
# =============================================================================

# Configuration
export VENV_HOME="$HOME/virtualenv"
export ENV_PROJECT_MAP="$HOME/.env_project_map"

# Ensure directories exist
[ ! -d "$VENV_HOME" ] && mkdir -p "$VENV_HOME"
[ ! -f "$ENV_PROJECT_MAP" ] && touch "$ENV_PROJECT_MAP"

# Function to detect project name intelligently
get_project_name() {
  local project_name=""

  # Method 1: Check if we're in a git repository
  if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    # Get the git repository root directory name
    local git_root=$(git rev-parse --show-toplevel 2>/dev/null)
    if [ -n "$git_root" ]; then
      project_name=$(basename "$git_root")
      echo "git:$project_name"
      return
    fi
  fi

  # Method 2: Look for common project files in current or parent directories
  local current_dir="$PWD"
  local search_dir="$current_dir"

  # Search up to 3 levels up for project indicators
  for i in {1..3}; do
    # Python project indicators
    if [ -f "$search_dir/pyproject.toml" ]; then
      # Try to extract project name from pyproject.toml
      local pyproject_name=$(grep -E "^name\s*=" "$search_dir/pyproject.toml" 2>/dev/null | sed 's/.*=\s*["\x27]\([^"\x27]*\)["\x27].*/\1/')
      if [ -n "$pyproject_name" ]; then
        echo "pyproject:$pyproject_name"
        return
      else
        project_name=$(basename "$search_dir")
        echo "pyproject:$project_name"
        return
      fi
    fi

    # Other project file indicators
    if [ -f "$search_dir/setup.py" ] || [ -f "$search_dir/requirements.txt" ] || [ -f "$search_dir/Pipfile" ] || [ -f "$search_dir/poetry.lock" ]; then
      project_name=$(basename "$search_dir")
      echo "python:$project_name"
      return
    fi

    # Data science project indicators
    if [ -d "$search_dir/notebooks" ] && [ -d "$search_dir/data" ]; then
      project_name=$(basename "$search_dir")
      echo "datascience:$project_name"
      return
    fi

    # Scala/Java project indicators
    if [ -f "$search_dir/build.sbt" ] || [ -f "$search_dir/pom.xml" ]; then
      project_name=$(basename "$search_dir")
      echo "scala:$project_name"
      return
    fi

    # Docker project indicators
    if [ -f "$search_dir/Dockerfile" ] || [ -f "$search_dir/docker-compose.yml" ]; then
      project_name=$(basename "$search_dir")
      echo "docker:$project_name"
      return
    fi

    # Move up one directory
    search_dir=$(dirname "$search_dir")

    # Stop if we reach home or root
    if [ "$search_dir" = "$HOME" ] || [ "$search_dir" = "/" ]; then
      break
    fi
  done

  # Method 3: Special directory patterns
  case "$PWD" in
    */projects/*)
      # Extract project name from /path/to/projects/project-name/...
      project_name=$(echo "$PWD" | sed 's|.*/projects/\([^/]*\).*|\1|')
      echo "projects:$project_name"
      return
      ;;
    */work/*)
      # Extract project name from /path/to/work/project-name/...
      project_name=$(echo "$PWD" | sed 's|.*/work/\([^/]*\).*|\1|')
      echo "work:$project_name"
      return
      ;;
    */dev/*)
      # Extract project name from /path/to/dev/project-name/...
      project_name=$(echo "$PWD" | sed 's|.*/dev/\([^/]*\).*|\1|')
      echo "dev:$project_name"
      return
      ;;
  esac

  # Method 4: Manual project name (if set)
  if [ -f "$PWD/.project_name" ]; then
    project_name=$(cat "$PWD/.project_name" | tr -d '\n')
    echo "manual:$project_name"
    return
  fi

  # Method 5: Fallback to current directory name
  project_name=$(basename "$PWD")
  echo "directory:$project_name"
}

# Helper function to activate environment
_activate_env() {
  local env_name="$1"

  # Try conda first, then venv
  if command -v conda >/dev/null && conda info --envs | grep -q "^$env_name "; then
    conda activate "$env_name"
    echo "✅ Activated conda environment: $env_name"
  elif [ -d "$VENV_HOME/$env_name" ]; then
    source "$VENV_HOME/$env_name/bin/activate"
    echo "✅ Activated virtual environment: $env_name"
  else
    echo "❌ Environment '$env_name' not found"
    return 1
  fi
}

# Helper function to list environments
_list_environments() {
  echo "🅒 Conda environments:"
  if command -v conda >/dev/null; then
    conda info --envs 2>/dev/null | awk '/^\w/ && $1!="base" {print "  " $1}'
  fi
  echo ""
  echo "🐍 Virtual environments:"
  ls -1 "$VENV_HOME" 2>/dev/null | sed 's/^/  /' || echo "  (none found)"
}
# Quick environment activation with fuzzy search and project memory
# Quick environment activation with fuzzy search and project memory
va() {
  # Check if environment name was provided as argument
  if [ $# -gt 0 ]; then
    # Direct activation with provided argument
    _activate_env "$1"
    return
  fi

  # No arguments - show fuzzy selection
  _va_interactive_select
}

# Helper function for interactive selection
_va_interactive_select() {
  # Smart selection with fzf
  if ! command -v fzf >/dev/null; then
    echo "📋 Available environments:"
    _list_environments
    echo "💡 Install fzf for better selection: va <env_name>"
    return
  fi

  # Build environment list
  local project_info=$(get_project_name)
  local current_project="${project_info##*:}"
  local suggested_env=$(grep "^$current_project:" "$ENV_PROJECT_MAP" 2>/dev/null | cut -d: -f2)

  # Create environment list and get selection
  local selected
  selected=$(
    {
      # Current project suggestion (if mapping exists)
      if [ -n "$suggested_env" ]; then
        echo "🎯 $suggested_env (suggested for $current_project)"
      fi

      # Conda environments
      if command -v conda >/dev/null; then
        conda info --envs 2>/dev/null | awk '/^\w/ && $1!="base" {print "🅒 " $1}'
      fi

      # Virtual environments
      if [ -d "$VENV_HOME" ]; then
        for env in "$VENV_HOME"/*; do
          if [ -d "$env" ]; then
            local name=$(basename "$env")
            local project=$(grep ":$name$" "$ENV_PROJECT_MAP" 2>/dev/null | cut -d: -f1)
            if [ -n "$project" ]; then
              echo "🐍 $name (used in: $project)"
            else
              echo "🐍 $name"
            fi
          fi
        done
      fi
    } | fzf --prompt="Select environment: " --height=~40% | sed 's/^[🎯🅒🐍] *//' | sed 's/ (.*//'
  )

  if [ -n "$selected" ]; then
    _activate_env "$selected"

    # Remember this association
    if [[ ! "$PWD" =~ ^/tmp ]] && [[ ! "$PWD" =~ ^/var ]]; then
      grep -v "^$current_project:" "$ENV_PROJECT_MAP" >"${ENV_PROJECT_MAP}.tmp" 2>/dev/null || true
      echo "$current_project:$selected" >>"${ENV_PROJECT_MAP}.tmp"
      mv "${ENV_PROJECT_MAP}.tmp" "$ENV_PROJECT_MAP"
      echo "💾 Remembered: $current_project → $selected"
    fi
  fi
}
# Quick environment creation with smart templates
vc() {
  local name="$1"
  local template="${2:-basic}"

  if [ -z "$name" ]; then
    echo "Usage: vc <env_name> [template]"
    echo "Templates: basic, ds (data science), de (data engineering), ml"
    return 1
  fi

  if [ -d "$VENV_HOME/$name" ]; then
    echo "⚠️  Environment '$name' already exists"
    echo -n "Activate existing environment? [Y/n]: "
    read REPLY
    if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
      _activate_env "$name"
    fi
    return
  fi

  echo "🐍 Creating virtual environment: $name"

  # Create with Python 3.11 (adjust as needed)
  python3 -m venv "$VENV_HOME/$name"
  source "$VENV_HOME/$name/bin/activate"

  # Upgrade pip first
  pip install --upgrade pip setuptools wheel

  # Install packages based on template
  case "$template" in
    "ds" | "data-science")
      echo "📊 Installing data science packages..."
      pip install ipython jupyter pandas numpy matplotlib seaborn scikit-learn plotly
      ;;
    "de" | "data-engineering")
      echo "🔧 Installing data engineering packages..."
      pip install ipython jupyter pandas numpy polars duckdb sqlalchemy great-expectations
      ;;
    "ml" | "machine-learning")
      echo "🤖 Installing ML packages..."
      pip install ipython jupyter pandas numpy matplotlib seaborn scikit-learn plotly tensorflow torch
      ;;
    "basic")
      echo "⚡ Installing basic packages..."
      pip install ipython jupyter requests
      ;;
    *)
      echo "📦 Installing custom packages: $template"
      pip install ipython jupyter $template
      ;;
  esac

  # Remember association with current project
  local project_info=$(get_project_name)
  local current_project="${project_info##*:}"
  if [[ ! "$PWD" =~ ^/tmp ]] && [[ ! "$PWD" =~ ^/var ]]; then
    grep -v "^$current_project:" "$ENV_PROJECT_MAP" >"${ENV_PROJECT_MAP}.tmp" 2>/dev/null || true
    echo "$current_project:$name" >>"${ENV_PROJECT_MAP}.tmp"
    mv "${ENV_PROJECT_MAP}.tmp" "$ENV_PROJECT_MAP"
    echo "💾 Associated with project: $current_project"
  fi

  echo "✅ Environment '$name' created and activated!"
}

# Enhanced project environment function using smart detection
vp() {
  local project_info=$(get_project_name)
  local project_type="${project_info%%:*}"
  local project_name="${project_info##*:}"
  local mapped_env=$(grep "^$project_name:" "$ENV_PROJECT_MAP" 2>/dev/null | cut -d: -f2)

  echo "🔍 Project detected: $project_name ($project_type)"

  if [ -n "$mapped_env" ]; then
    echo "🎯 Found mapped environment: $mapped_env"
    _activate_env "$mapped_env"
  else
    # Look for environment with same name as project
    if [ -d "$VENV_HOME/$project_name" ]; then
      echo "🎯 Found environment matching project name: $project_name"
      _activate_env "$project_name"

      # Create mapping
      echo "$project_name:$project_name" >>"$ENV_PROJECT_MAP"
    elif command -v conda >/dev/null && conda info --envs | grep -q "^$project_name "; then
      echo "🎯 Found conda environment matching project name: $project_name"
      _activate_env "$project_name"

      # Create mapping
      echo "$project_name:$project_name" >>"$ENV_PROJECT_MAP"
    else
      echo "❓ No environment found for project: $project_name"
      echo "📁 Detected as: $project_type project"
      echo ""
      echo "Options:"
      echo "1. Create new environment: $project_name"
      echo "2. Select existing environment"
      echo "3. Skip"
      echo ""
      echo -n "Choose [1-3]: "
      read choice

      case $choice in
        1)
          # Suggest template based on project type
          local suggested_template="basic"
          case "$project_type" in
            "datascience") suggested_template="ds" ;;
            "python") suggested_template="ds" ;;
            "git")
              # Try to guess from repository content
              if [ -d "notebooks" ] || [ -d "data" ]; then
                suggested_template="ds"
              elif [ -f "requirements.txt" ] && grep -q "pandas\|numpy\|scikit" requirements.txt 2>/dev/null; then
                suggested_template="ds"
              elif [ -f "requirements.txt" ] && grep -q "airflow\|kafka\|dbt" requirements.txt 2>/dev/null; then
                suggested_template="de"
              fi
              ;;
          esac

          echo "📊 Suggested template based on project type: $suggested_template"
          echo "1. Data Science (ds) - pandas, numpy, matplotlib, scikit-learn"
          echo "2. Data Engineering (de) - polars, duckdb, sqlalchemy, great-expectations"
          echo "3. Machine Learning (ml) - + tensorflow, torch"
          echo "4. Basic (basic) - requests, ipython, jupyter"
          echo "5. Use suggested ($suggested_template)"
          echo -n "Choose template [1-5]: "
          read template_choice

          case $template_choice in
            1) vc "$project_name" "ds" ;;
            2) vc "$project_name" "de" ;;
            3) vc "$project_name" "ml" ;;
            4) vc "$project_name" "basic" ;;
            5 | *) vc "$project_name" "$suggested_template" ;;
          esac
          ;;
        2)
          va # Use existing environment selector
          ;;
        3)
          echo "👍 Continuing without virtual environment"
          ;;
      esac
    fi
  fi
}
# Quick deactivate
vd() {
  if [ -n "$VIRTUAL_ENV" ] || [ -n "$CONDA_DEFAULT_ENV" ]; then
    if [ -n "$CONDA_DEFAULT_ENV" ] && [ "$CONDA_DEFAULT_ENV" != "base" ]; then
      conda deactivate
      echo "✅ Deactivated conda environment"
    elif [ -n "$VIRTUAL_ENV" ]; then
      deactivate
      echo "✅ Deactivated virtual environment"
    fi
  else
    echo "ℹ️  No active virtual environment"
  fi
}

# List environments with project mappings
vl() {
  echo "🐍 Virtual Environments & Project Mappings"
  echo "==========================================="
  echo ""

  # Show current environment
  if [ -n "$VIRTUAL_ENV" ]; then
    echo "🟢 Currently active: $(basename "$VIRTUAL_ENV") (venv)"
  elif [ -n "$CONDA_DEFAULT_ENV" ] && [ "$CONDA_DEFAULT_ENV" != "base" ]; then
    echo "🟢 Currently active: $CONDA_DEFAULT_ENV (conda)"
  else
    echo "⚪ No environment active"
  fi
  echo ""

  # Conda environments
  if command -v conda >/dev/null; then
    echo "🅒 Conda environments:"
    conda info --envs 2>/dev/null | awk '/^\w/ && $1!="base" {print "  " $1}'
    echo ""
  fi

  # Virtual environments with project mappings
  echo "🐍 Virtual environments:"
  for env in "$VENV_HOME"/*; do
    if [ -d "$env" ]; then
      local name=$(basename "$env")
      local projects=$(grep ":$name$" "$ENV_PROJECT_MAP" 2>/dev/null | cut -d: -f1 | tr '\n' ', ' | sed 's/,$//')
      if [ -n "$projects" ]; then
        echo "  $name → used in: $projects"
      else
        echo "  $name"
      fi
    fi
  done

  if [ -f "$ENV_PROJECT_MAP" ] && [ -s "$ENV_PROJECT_MAP" ]; then
    echo ""
    echo "🗂️  Project mappings:"
    cat "$ENV_PROJECT_MAP" | sed 's/^/  /' | sed 's/:/ → /'
  fi
}

# Forget project-environment mapping
vf() {
  local project="${1:-$(get_project_name | cut -d: -f2)}"

  if grep -q "^$project:" "$ENV_PROJECT_MAP" 2>/dev/null; then
    grep -v "^$project:" "$ENV_PROJECT_MAP" >"${ENV_PROJECT_MAP}.tmp"
    mv "${ENV_PROJECT_MAP}.tmp" "$ENV_PROJECT_MAP"
    echo "🗑️  Removed mapping for project: $project"
  else
    echo "ℹ️  No mapping found for project: $project"
  fi
}

# Function to show project detection info
show_project_info() {
  local project_info=$(get_project_name)
  local project_type="${project_info%%:*}"
  local project_name="${project_info##*:}"

  echo "🔍 Project Detection Results"
  echo "============================"
  echo "📁 Current directory: $PWD"
  echo "📋 Project name: $project_name"
  echo "🏷️  Detection method: $project_type"
  echo ""

  case "$project_type" in
    "git")
      echo "✅ Detected via Git repository"
      echo "   Repository root: $(git rev-parse --show-toplevel 2>/dev/null)"
      ;;
    "pyproject")
      echo "✅ Detected via pyproject.toml"
      ;;
    "python")
      echo "✅ Detected via Python project files"
      ;;
    "datascience")
      echo "✅ Detected via data science project structure"
      ;;
    "manual")
      echo "✅ Manually set project name"
      echo "   File: $PWD/.project_name"
      ;;
    "directory")
      echo "⚠️  Fallback: using directory name"
      echo "💡 Consider setting up git or adding project files"
      ;;
  esac

  # Show environment mapping if exists
  local mapped_env=$(grep "^$project_name:" "$ENV_PROJECT_MAP" 2>/dev/null | cut -d: -f2)
  if [ -n "$mapped_env" ]; then
    echo ""
    echo "🔗 Environment mapping: $project_name → $mapped_env"
  fi
}

# Function to manually set project name (for edge cases)
set_project_name() {
  local name="$1"
  if [ -z "$name" ]; then
    read -p "Enter project name: " name
  fi

  if [ -n "$name" ]; then
    echo "$name" >"$PWD/.project_name"
    echo "✅ Project name set to: $name"
    echo "🗑️  Remove with: rm .project_name"
  fi
}

# Aliases
alias project-info='show_project_info'
alias set-project='set_project_name'
alias venv-list='vl'
alias venv-create='vc'
alias venv-project='vp'
alias venv-forget='vf'

# =============================================================================
# Auto-activate virtual environments based on directory
# =============================================================================

# Auto-activate virtual environments based on directory
auto_activate_venv() {
    # Skip in non-interactive shells or if functions aren't available
    if [[ ! -o interactive ]] || ! command -v get_project_name >/dev/null 2>&1; then
        return
    fi
    
    # Skip if we're in temp directories
    if [[ "$PWD" =~ ^/tmp ]] || [[ "$PWD" =~ ^/var ]]; then
        return
    fi
    
    # Get current project info
    local current_project_info=$(get_project_name 2>/dev/null)
    local project_name="${current_project_info##*:}"
    local current_env_name=""
    
    # Get currently active environment name
    if [ -n "$VIRTUAL_ENV" ]; then
        current_env_name=$(basename "$VIRTUAL_ENV")
    elif [ -n "$CONDA_DEFAULT_ENV" ] && [ "$CONDA_DEFAULT_ENV" != "base" ]; then
        current_env_name="$CONDA_DEFAULT_ENV"
    fi
    
    # If we're already in the right environment, do nothing
    if [ "$current_env_name" = "$project_name" ]; then
        return
    fi
    
    # Check if project has a mapped environment
    local mapped_env=$(grep "^$project_name:" "$ENV_PROJECT_MAP" 2>/dev/null | cut -d: -f2)
    local target_env=""
    
    if [ -n "$mapped_env" ]; then
        target_env="$mapped_env"
    elif [ -d "$VENV_HOME/$project_name" ]; then
        target_env="$project_name"
    elif command -v conda >/dev/null && conda info --envs | grep -q "^$project_name "; then
        target_env="$project_name"
    fi
    
    # If we found a target environment different from current, switch to it
    if [ -n "$target_env" ] && [ "$target_env" != "$current_env_name" ]; then
        # Deactivate current environment if any (quietly)
        if [ -n "$VIRTUAL_ENV" ]; then
            deactivate 2>/dev/null || true
        elif [ -n "$CONDA_DEFAULT_ENV" ] && [ "$CONDA_DEFAULT_ENV" != "base" ]; then
            conda deactivate 2>/dev/null || true
        fi
        
        # Activate the target environment (quietly)
        _activate_env "$target_env" 2>/dev/null && echo "🐍 Auto-activated: $target_env"
        
        # Update mapping if it was auto-detected but not recorded
        if [ -z "$mapped_env" ] && [ -n "$target_env" ]; then
            echo "$project_name:$target_env" >> "$ENV_PROJECT_MAP"
        fi
    fi
}

# Hook to run auto-activation on directory change
autoload -U add-zsh-hook
add-zsh-hook chpwd auto_activate_venv

# Also run on shell startup (but only if we're in a project directory)
auto_activate_venv
