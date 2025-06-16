# =============================================================================
# OPTIMIZED Smart Project Detection & Environment Management
# =============================================================================

# Configuration
export VENV_HOME="$HOME/virtualenv"
export ENV_PROJECT_MAP="$HOME/.env_project_map"

# Ensure directories exist
[ ! -d "$VENV_HOME" ] && mkdir -p "$VENV_HOME"
[ ! -f "$ENV_PROJECT_MAP" ] && touch "$ENV_PROJECT_MAP"

# Performance: Cache for project detection and environment mappings
typeset -A PROJECT_CACHE
typeset -A ENV_CACHE
typeset -A ENV_EXISTS_CACHE

# Optimized project detection with intelligent ordering and caching
get_project_name() {
  local dir="$PWD"

  # Check cache first (major speedup for repeated calls)
  if [[ -n "${PROJECT_CACHE[$dir]:-}" ]]; then
    echo "${PROJECT_CACHE[$dir]}"
    return
  fi

  local project_name=""
  local result=""

  # Method 1: Fast regex patterns FIRST (avoids expensive operations)
  if [[ "$dir" =~ /projects/([^/]+) ]]; then
    result="projects:${BASH_REMATCH[1]}"
  elif [[ "$dir" =~ /work/([^/]+) ]]; then
    result="work:${BASH_REMATCH[1]}"
  elif [[ "$dir" =~ /dev/([^/]+) ]]; then
    result="dev:${BASH_REMATCH[1]}"

  # Method 2: Quick file checks (current directory only - faster)
  elif [ -f ".project_name" ]; then
    project_name=$(cat .project_name 2>/dev/null | tr -d '\n')
    result="manual:$project_name"
  elif [ -f "pyproject.toml" ]; then
    # Quick name extraction (simplified regex)
    local pyproject_name=$(grep -m1 -E "^name\s*=" pyproject.toml 2>/dev/null | sed 's/.*=\s*["\x27]\([^"\x27]*\)["\x27].*/\1/')
    if [ -n "$pyproject_name" ]; then
      result="pyproject:$pyproject_name"
    else
      result="pyproject:$(basename "$dir")"
    fi
  elif [ -f "requirements.txt" ] || [ -f "setup.py" ] || [ -f "Pipfile" ]; then
    result="python:$(basename "$dir")"
  elif [ -d "notebooks" ] && [ -d "data" ]; then
    result="datascience:$(basename "$dir")"
  elif [ -f "build.sbt" ] || [ -f "pom.xml" ]; then
    result="scala:$(basename "$dir")"
  elif [ -f "Dockerfile" ] || [ -f "docker-compose.yml" ]; then
    result="docker:$(basename "$dir")"

  # Method 3: Git (expensive - do LAST and cache aggressively)
  elif git rev-parse --show-toplevel >/dev/null 2>&1; then
    local git_root=$(git rev-parse --show-toplevel 2>/dev/null)
    if [ -n "$git_root" ]; then
      result="git:$(basename "$git_root")"
      # Cache git result for entire repository tree
      PROJECT_CACHE["$git_root"]="$result"
    fi
  else
    # Fallback
    result="directory:$(basename "$dir")"
  fi

  # Cache result for this directory
  PROJECT_CACHE[$dir]="$result"
  echo "$result"
}

# Optimized environment activation with existence caching
_activate_env() {
  local env_name="$1"

  # Check if environment exists (with caching to avoid repeated checks)
  if [[ -z "${ENV_EXISTS_CACHE[$env_name]:-}" ]]; then
    if command -v conda >/dev/null && conda info --envs 2>/dev/null | grep -q "^$env_name "; then
      ENV_EXISTS_CACHE[$env_name]="conda"
    elif [ -d "$VENV_HOME/$env_name" ]; then
      ENV_EXISTS_CACHE[$env_name]="venv"
    else
      ENV_EXISTS_CACHE[$env_name]="none"
    fi
  fi

  case "${ENV_EXISTS_CACHE[$env_name]}" in
    "conda")
      conda activate "$env_name" 2>/dev/null && echo "✅ Activated conda: $env_name"
      ;;
    "venv")
      source "$VENV_HOME/$env_name/bin/activate" 2>/dev/null && echo "✅ Activated venv: $env_name"
      ;;
    "none")
      echo "❌ Environment '$env_name' not found"
      return 1
      ;;
  esac
}

# Helper function to list environments (unchanged)
_list_environments() {
  echo "🅒 Conda environments:"
  if command -v conda >/dev/null; then
    conda info --envs 2>/dev/null | awk '/^\w/ && $1!="base" {print "  " $1}'
  fi
  echo ""
  echo "🐍 Virtual environments:"
  ls -1 "$VENV_HOME" 2>/dev/null | sed 's/^/  /' || echo "  (none found)"
}

# Ultra-fast environment lookup with caching
_get_mapped_env() {
  local project_name="$1"
  local cache_key="env_map:$project_name"

  # Check cache first (avoids file reads)
  if [[ -n "${ENV_CACHE[$cache_key]:-}" ]]; then
    echo "${ENV_CACHE[$cache_key]}"
    return
  fi

  # Read from file only if not cached
  local mapped_env=$(grep -m1 "^$project_name:" "$ENV_PROJECT_MAP" 2>/dev/null | cut -d: -f2)

  # Cache result (even if empty)
  ENV_CACHE[$cache_key]="${mapped_env:-}"
  echo "$mapped_env"
}

# Optimized interactive environment selection
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

# Helper function for interactive selection (optimized)
_va_interactive_select() {
  # Smart selection with fzf
  if ! command -v fzf >/dev/null; then
    echo "📋 Available environments:"
    _list_environments
    echo "💡 Install fzf for better selection: va <env_name>"
    return
  fi

  # Fast project and environment detection
  local project_info=$(get_project_name)
  local current_project="${project_info##*:}"
  local suggested_env=$(_get_mapped_env "$current_project")

  # Create environment list and get selection (optimized)
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

    # Remember this association (with caching)
    if [[ ! "$PWD" =~ ^/tmp ]] && [[ ! "$PWD" =~ ^/var ]]; then
      grep -v "^$current_project:" "$ENV_PROJECT_MAP" >"${ENV_PROJECT_MAP}.tmp" 2>/dev/null || true
      echo "$current_project:$selected" >>"${ENV_PROJECT_MAP}.tmp"
      mv "${ENV_PROJECT_MAP}.tmp" "$ENV_PROJECT_MAP"
      # Update cache
      ENV_CACHE["env_map:$current_project"]="$selected"
      echo "💾 Remembered: $current_project → $selected"
    fi
  fi
}

# Quick environment creation (unchanged but optimized mapping)
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

  # Create environment
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

  # Remember association with current project (with caching)
  local project_info=$(get_project_name)
  local current_project="${project_info##*:}"
  if [[ ! "$PWD" =~ ^/tmp ]] && [[ ! "$PWD" =~ ^/var ]]; then
    grep -v "^$current_project:" "$ENV_PROJECT_MAP" >"${ENV_PROJECT_MAP}.tmp" 2>/dev/null || true
    echo "$current_project:$name" >>"${ENV_PROJECT_MAP}.tmp"
    mv "${ENV_PROJECT_MAP}.tmp" "$ENV_PROJECT_MAP"
    # Update cache
    ENV_CACHE["env_map:$current_project"]="$name"
    echo "💾 Associated with project: $current_project"
  fi

  # Cache that this environment exists
  ENV_EXISTS_CACHE[$name]="venv"

  echo "✅ Environment '$name' created and activated!"
}

# Optimized project environment function
vp() {
  local project_info=$(get_project_name)
  local project_type="${project_info%%:*}"
  local project_name="${project_info##*:}"
  local mapped_env=$(_get_mapped_env "$project_name")

  echo "🔍 Project: $project_name ($project_type)"

  if [[ -n "$mapped_env" ]]; then
    echo "🎯 Using mapped environment: $mapped_env"
    _activate_env "$mapped_env"
  elif [[ -d "$VENV_HOME/$project_name" ]]; then
    echo "🎯 Using project environment: $project_name"
    _activate_env "$project_name"
    # Auto-save mapping and cache it
    echo "$project_name:$project_name" >>"$ENV_PROJECT_MAP"
    ENV_CACHE["env_map:$project_name"]="$project_name"
  elif command -v conda >/dev/null && conda info --envs 2>/dev/null | grep -q "^$project_name "; then
    echo "🎯 Using conda environment: $project_name"
    _activate_env "$project_name"
    # Auto-save mapping and cache it
    echo "$project_name:$project_name" >>"$ENV_PROJECT_MAP"
    ENV_CACHE["env_map:$project_name"]="$project_name"
  else
    echo "❓ No environment found for: $project_name"
    echo "💡 Create with: vc $project_name [ds|de|ml|basic]"
  fi
}

# Quick deactivate (unchanged)
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

# List environments with project mappings (unchanged)
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

# Forget project-environment mapping (with cache invalidation)
vf() {
  local project="${1:-$(get_project_name | cut -d: -f2)}"

  if grep -q "^$project:" "$ENV_PROJECT_MAP" 2>/dev/null; then
    grep -v "^$project:" "$ENV_PROJECT_MAP" >"${ENV_PROJECT_MAP}.tmp"
    mv "${ENV_PROJECT_MAP}.tmp" "$ENV_PROJECT_MAP"
    # Clear cache entry
    unset ENV_CACHE["env_map:$project"]
    echo "🗑️  Removed mapping for project: $project"
  else
    echo "ℹ️  No mapping found for project: $project"
  fi
}

# Function to show project detection info (unchanged)
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
  local mapped_env=$(_get_mapped_env "$project_name")
  if [ -n "$mapped_env" ]; then
    echo ""
    echo "🔗 Environment mapping: $project_name → $mapped_env"
  fi
}

# Function to manually set project name (unchanged)
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

# OPTIMIZED auto-activation (minimal overhead)
auto_activate_venv() {
  # Early returns for maximum performance
  [[ ! -o interactive ]] && return
  [[ "$PWD" =~ ^/tmp ]] && return
  [[ "$PWD" =~ ^/var ]] && return

  # Fast project detection (with caching)
  local project_info=$(get_project_name)
  local project_name="${project_info##*:}"

  # Fast current environment detection
  local current_env=""
  if [[ -n "$VIRTUAL_ENV" ]]; then
    current_env=$(basename "$VIRTUAL_ENV")
  elif [[ -n "$CONDA_DEFAULT_ENV" && "$CONDA_DEFAULT_ENV" != "base" ]]; then
    current_env="$CONDA_DEFAULT_ENV"
  fi

  # Skip if already in correct environment (most common case)
  [[ "$current_env" == "$project_name" ]] && return

  # Fast environment lookup (with caching)
  local target_env=$(_get_mapped_env "$project_name")

  # If no mapping, check for direct environment match
  if [[ -z "$target_env" ]]; then
    if [[ -d "$VENV_HOME/$project_name" ]]; then
      target_env="$project_name"
      # Cache this discovered mapping
      ENV_CACHE["env_map:$project_name"]="$project_name"
    else
      return # Don't activate without clear mapping
    fi
  fi

  # Switch environment if different
  if [[ -n "$target_env" && "$target_env" != "$current_env" ]]; then
    # Fast deactivation
    [[ -n "$VIRTUAL_ENV" ]] && deactivate 2>/dev/null
    [[ -n "$CONDA_DEFAULT_ENV" && "$CONDA_DEFAULT_ENV" != "base" ]] && conda deactivate 2>/dev/null

    # Fast activation (with minimal output)
    case "${ENV_EXISTS_CACHE[$target_env]:-}" in
      "venv" | "")
        if [ -d "$VENV_HOME/$target_env" ]; then
          source "$VENV_HOME/$target_env/bin/activate" 2>/dev/null
          ENV_EXISTS_CACHE[$target_env]="venv"
        fi
        ;;
      "conda")
        conda activate "$target_env" 2>/dev/null
        ;;
    esac
  fi
}

# Cache management functions (NEW)
clear_env_cache() {
  PROJECT_CACHE=()
  ENV_CACHE=()
  ENV_EXISTS_CACHE=()
  echo "🗑️ Environment cache cleared"
}

cache_stats() {
  echo "📊 Cache Statistics:"
  echo "  Project cache: ${#PROJECT_CACHE[@]} entries"
  echo "  Environment cache: ${#ENV_CACHE[@]} entries"
  echo "  Environment exists cache: ${#ENV_EXISTS_CACHE[@]} entries"
}

# Performance debugging (NEW)
debug_performance() {
  echo "🔧 Performance Debug Mode"
  echo "Project detection timing:"
  time get_project_name
  echo ""
  echo "Environment lookup timing:"
  local project_info=$(get_project_name)
  local project_name="${project_info##*:}"
  time _get_mapped_env "$project_name"
  echo ""
  cache_stats
}

# Auto-activation hook (optimized for zsh)
if [[ -n "$ZSH_VERSION" ]]; then
  autoload -U add-zsh-hook
  add-zsh-hook chpwd auto_activate_venv
  auto_activate_venv # Run once on startup
fi

# Aliases (including new cache management)
alias project-info='show_project_info'
alias set-project='set_project_name'
alias venv-list='vl'
alias venv-create='vc'
alias venv-project='vp'
alias venv-forget='vf'
alias clear-cache='clear_env_cache'
alias cache-stats='cache_stats'
alias perf-debug='debug_performance'

# Add this function to your .zshrc for quick help
venv-help() {
  echo "🐍 Virtual Environment Quick Reference"
  echo "======================================"
  echo "va [env]     - Activate environment (fuzzy select if no arg)"
  echo "vc <name>    - Create environment with template [ds|de|ml|basic]"
  echo "vp           - Project environment (auto-detect/create)"
  echo "vd           - Deactivate current environment"
  echo "vl           - List environments and mappings"
  echo "vf [project] - Forget project mapping"
  echo "vr <env>     - Remove environment"
  echo "vs           - Sync requirements.txt"
  echo ""
  echo "🎯 Project & Cache:"
  echo "project-info  - Show project detection details"
  echo "cache-stats   - Show performance cache statistics"
  echo "clear-cache   - Clear all caches"
  echo "perf-debug    - Performance debugging"
  echo ""
  echo "🚀 TMux Integration:"
  echo "Prefix + W    - Workspace layouts (auto-activates environment)"
  echo "Prefix + v    - Quick project environment activation"
}

alias vh='venv-help'

# Environment Cleanup/Removal
vr() {
  local env_name="${1:-}"

  if [ -z "$env_name" ]; then
    echo "Usage: vr <environment_name>"
    echo "💡 Use 'vl' to see available environments"
    return 1
  fi

  # Check if environment exists
  if [ -d "$VENV_HOME/$env_name" ]; then
    echo "🗑️  Remove virtual environment: $env_name"
    echo "📁 Location: $VENV_HOME/$env_name"
    echo "⚠️  This cannot be undone!"
    echo ""
    read -p "Are you sure? [y/N]: " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      # Deactivate if currently active
      if [ -n "$VIRTUAL_ENV" ] && [[ "$VIRTUAL_ENV" == *"$env_name" ]]; then
        deactivate
      fi

      rm -rf "$VENV_HOME/$env_name"

      # Remove from cache
      unset ENV_EXISTS_CACHE["$env_name"]

      # Remove from mappings
      grep -v ":$env_name$" "$ENV_PROJECT_MAP" >"${ENV_PROJECT_MAP}.tmp" 2>/dev/null || true
      mv "${ENV_PROJECT_MAP}.tmp" "$ENV_PROJECT_MAP" 2>/dev/null || true

      echo "✅ Environment '$env_name' removed"
    else
      echo "❌ Cancelled"
    fi
  else
    echo "❌ Environment '$env_name' not found"
  fi
}

alias venv-remove='vr'

# Add this function to auto-install when requirements.txt changes
vs() {
    if [ -z "$VIRTUAL_ENV" ]; then
        echo "❌ No virtual environment active"
        echo "💡 Use 'vp' to activate project environment first"
        return 1
    fi
    
    if [ -f "requirements.txt" ]; then
        echo "📦 Syncing requirements.txt..."
        pip install -r requirements.txt
        echo "✅ Requirements synced"
    else
        echo "❌ No requirements.txt found"
    fi
}

alias venv-sync='vs'

