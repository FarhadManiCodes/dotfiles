# =============================================================================
# OPTIMIZED Virtual Environment Management with Shared Helper Functions
# =============================================================================

# Configuration
export VENV_HOME="$HOME/virtualenv"
export ENV_PROJECT_MAP="$HOME/.env_project_map"

# Ensure directories exist
[ ! -d "$VENV_HOME" ] && mkdir -p "$VENV_HOME"
[ ! -f "$ENV_PROJECT_MAP" ] && touch "$ENV_PROJECT_MAP"

# Performance caches
typeset -A PROJECT_CACHE ENV_CACHE ENV_EXISTS_CACHE

# Check for conflicting aliases and remove them
if alias vh >/dev/null 2>&1; then
  unalias vh 2>/dev/null
fi

# =============================================================================
# SHARED HELPER FUNCTIONS
# =============================================================================

# Unified environment discovery - used by va, vl, and other functions
_discover_environments() {
  local format="${1:-detailed}" # detailed|simple|fzf
  local include_local="${2:-true}"
  local environments=()
  
  # Conda environments
  if command -v conda >/dev/null; then
    while IFS= read -r line; do
      local name=$(echo "$line" | awk '{print $1}')
      local path=$(echo "$line" | awk '{print $2}')
      case "$format" in
        "fzf") environments+=("🅒 $name ($path)") ;;
        "simple") environments+=("$name (conda)") ;;
        "detailed") environments+=("🅒 $name - $path") ;;
      esac
    done < <(conda info --envs 2>/dev/null | awk '/^\w/ && $1!="base" {print $1 " " $2}')
  fi
  
  # Virtual environments
  if [ -d "$VENV_HOME" ]; then
    for env_dir in "$VENV_HOME"/*; do
      if [ -d "$env_dir" ]; then
        local name=$(basename "$env_dir")
        local projects=$(grep ":$name$" "$ENV_PROJECT_MAP" 2>/dev/null | cut -d: -f1 | tr '\n' ', ' | sed 's/,$//')
        case "$format" in
          "fzf") 
            if [ -n "$projects" ]; then
              environments+=("🐍 $name ($env_dir - used in: $projects)")
            else
              environments+=("🐍 $name ($env_dir)")
            fi
            ;;
          "simple") environments+=("$name (venv)") ;;
          "detailed")
            if [ -n "$projects" ]; then
              environments+=("🐍 $name → used in: $projects")
            else
              environments+=("🐍 $name")
            fi
            ;;
        esac
      fi
    done
  fi
  
  # Local environments (for fzf format)
  if [[ "$format" == "fzf" && "$include_local" == "true" ]]; then
    for local_env in venv .venv env; do
      if [ -d "$local_env" ]; then
        environments+=("📁 $local_env (local in $(basename "$PWD"))")
      fi
    done
  fi
  
  printf '%s\n' "${environments[@]}"
}

# Unified environment type detection with caching - improved
_get_env_type() {
  local env_name="$1"
  
  # Check cache first
  if [[ -n "${ENV_EXISTS_CACHE[$env_name]:-}" ]]; then
    echo "${ENV_EXISTS_CACHE[$env_name]}"
    return
  fi
  
  local type="none"
  
  # Check for virtual environment first (faster)
  if [ -d "$VENV_HOME/$env_name" ]; then
    type="venv"
  # Then check conda (slower)
  elif command -v conda >/dev/null 2>&1; then
    if conda info --envs 2>/dev/null | grep -q "^$env_name "; then
      type="conda"
    fi
  fi
  
  # Cache result
  ENV_EXISTS_CACHE[$env_name]="$type"
  echo "$type"
}

# Unified environment activation
_activate_environment() {
  local env_name="$1"
  local type=$(_get_env_type "$env_name")
  
  case "$type" in
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

# Unified environment deactivation
_deactivate_current() {
  if [ -n "$CONDA_DEFAULT_ENV" ] && [ "$CONDA_DEFAULT_ENV" != "base" ]; then
    conda deactivate && echo "✅ Deactivated conda environment"
  elif [ -n "$VIRTUAL_ENV" ]; then
    deactivate && echo "✅ Deactivated virtual environment"
  else
    echo "ℹ️  No active virtual environment"
  fi
}

# Shared requirements.txt handling
_handle_requirements() {
  local action="$1"        # install|check|sync
  local template="$2"      # template name (optional)
  local create_if_missing="${3:-false}"
  
  case "$action" in
    "check")
      [ -f "requirements.txt" ] && echo "found" || echo "not_found"
      ;;
    "install")
      if [ -f "requirements.txt" ]; then
        echo "📦 Installing from requirements.txt..."
        pip install -r requirements.txt
        return 0
      elif [[ "$create_if_missing" == "true" ]]; then
        echo "📝 No requirements.txt found, creating empty environment"
        return 0
      else
        echo "❌ No requirements.txt found"
        return 1
      fi
      ;;
    "sync")
      if [ -z "$VIRTUAL_ENV" ]; then
        echo "❌ No virtual environment active"
        echo "💡 Use 'vp' to activate project environment first"
        return 1
      fi
      _handle_requirements "install"
      ;;
  esac
}

# Shared template installation
_install_template() {
  local template="$1"
  
  # Always upgrade pip first
  pip install --upgrade pip setuptools wheel
  
  case "$template" in
    ""|"none")
      _handle_requirements "install" "" "true"
      ;;
    "basic")
      echo "⚡ Installing basic development packages..."
      pip install requests black flake8 pytest pylint mypy
      ;;
    "ds"|"data-science")
      echo "📊 Installing data science packages..."
      pip install ipython jupyter pandas numpy scipy matplotlib seaborn scikit-learn plotly \
        black flake8 pylint mypy
      ;;
    "de"|"data-engineering")
      echo "🔧 Installing data engineering packages..."
      pip install ipython jupyter pandas numpy polars duckdb sqlalchemy great-expectations requests pyarrow \
        black flake8 pylint mypy
      ;;
    "ml"|"machine-learning")
      echo "🤖 Installing ML packages..."
      pip install ipython jupyter pandas numpy matplotlib seaborn scikit-learn plotly \
        black flake8 pylint mypy
      echo "💡 Add deep learning later: pip install torch torchvision OR pip install tensorflow"
      ;;
    *)
      echo "❌ Unknown template: $template"
      echo "Available templates: basic, ds, de, ml, none"
      return 1
      ;;
  esac
  
  # Show requirements.txt conflict warning if applicable
  if [[ "$template" != "" && "$template" != "none" ]] && [ -f "requirements.txt" ]; then
    echo "⚠️  Note: requirements.txt found but ignored (using $template template)"
    echo "💡 Use template 'none' to install from requirements.txt instead"
  fi
}

# Shared project-environment association logic
_associate_project_env() {
  local project_name="$1" env_name="$2"
  
  # Skip temporary directories
  [[ "$PWD" =~ ^(/tmp|/var) ]] && return
  
  # Update mapping file
  [ -f "$ENV_PROJECT_MAP" ] && grep -v "^$project_name:" "$ENV_PROJECT_MAP" >"${ENV_PROJECT_MAP}.tmp" || touch "${ENV_PROJECT_MAP}.tmp"
  echo "$project_name:$env_name" >>"${ENV_PROJECT_MAP}.tmp"
  mv "${ENV_PROJECT_MAP}.tmp" "$ENV_PROJECT_MAP"
  
  # Update cache
  ENV_CACHE["env_map:$project_name"]="$env_name"
  echo "💾 Associated: $project_name → $env_name"
}

# Get current environment name
_get_current_env() {
  if [[ -n "$VIRTUAL_ENV" ]]; then
    basename "$VIRTUAL_ENV"
  elif [[ -n "$CONDA_DEFAULT_ENV" && "$CONDA_DEFAULT_ENV" != "base" ]]; then
    echo "$CONDA_DEFAULT_ENV"
  fi
}

# =============================================================================
# PROJECT DETECTION (OPTIMIZED)
# =============================================================================

get_project_name() {
  local dir="$PWD"
  
  # Check cache first
  if [[ -n "${PROJECT_CACHE[$dir]:-}" ]]; then
    echo "${PROJECT_CACHE[$dir]}"
    return
  fi
  
  local result=""
  
  # Fast pattern matching first
  if [[ "$dir" =~ /(projects|work|dev)/([^/]+) ]]; then
    result="${BASH_REMATCH[1]}:${BASH_REMATCH[2]}"
  elif [ -f ".project_name" ]; then
    local name=$(cat .project_name 2>/dev/null | tr -d '\n')
    result="manual:$name"
  elif [ -f "pyproject.toml" ]; then
    local name=$(grep -m1 -E "^name\s*=" pyproject.toml 2>/dev/null | sed 's/.*=\s*["\x27]\([^"\x27]*\)["\x27].*/\1/')
    result="pyproject:${name:-$(basename "$dir")}"
  elif [ -f "requirements.txt" ] || [ -f "setup.py" ] || [ -f "Pipfile" ]; then
    result="python:$(basename "$dir")"
  elif [ -d "notebooks" ] && [ -d "data" ]; then
    result="datascience:$(basename "$dir")"
  elif [ -f "build.sbt" ] || [ -f "pom.xml" ]; then
    result="scala:$(basename "$dir")"
  elif [ -f "Dockerfile" ] || [ -f "docker-compose.yml" ]; then
    result="docker:$(basename "$dir")"
  elif git rev-parse --show-toplevel >/dev/null 2>&1; then
    local git_root=$(git rev-parse --show-toplevel 2>/dev/null)
    result="git:$(basename "$git_root")"
    # Cache for entire repo
    PROJECT_CACHE["$git_root"]="$result"
  else
    result="directory:$(basename "$dir")"
  fi
  
  PROJECT_CACHE[$dir]="$result"
  echo "$result"
}

_get_mapped_env() {
  local project_name="$1"
  local cache_key="env_map:$project_name"
  
  if [[ -n "${ENV_CACHE[$cache_key]:-}" ]]; then
    echo "${ENV_CACHE[$cache_key]}"
    return
  fi
  
  local mapped_env=$(grep -m1 "^$project_name:" "$ENV_PROJECT_MAP" 2>/dev/null | cut -d: -f2)
  ENV_CACHE[$cache_key]="${mapped_env:-}"
  echo "$mapped_env"
}

# =============================================================================
# MAIN FUNCTIONS (SIMPLIFIED)
# =============================================================================

# Enhanced va - activate environment
va() {
  if [ $# -gt 0 ]; then
    _activate_environment "$1"
    return
  fi
  
  # Interactive selection with fzf
  if ! command -v fzf >/dev/null; then
    echo "📋 Available environments:"
    _discover_environments "detailed"
    echo "💡 Install fzf for better selection: va <env_name>"
    return
  fi
  
  # Get project suggestion
  local project_info=$(get_project_name)
  local current_project="${project_info##*:}"
  local suggested_env=$(_get_mapped_env "$current_project")
  
  # Build environment list for fzf
  local environments=()
  if [ -n "$suggested_env" ]; then
    environments+=("🎯 $suggested_env (suggested for $current_project)")
  fi
  
  # Add all discovered environments
  local discovered_envs=$(_discover_environments "fzf")
  while IFS= read -r env; do
    [[ -n "$env" ]] && environments+=("$env")
  done <<< "$discovered_envs"
  
  # Select with fzf
  local selected=$(printf '%s\n' "${environments[@]}" | \
    fzf --prompt="🐍 Select environment: " --height=50% \
        --preview='env_name=$(echo {} | sed "s/^[🎯🅒🐍📁] *//" | awk "{print \$1}"); echo "🔍 Environment: $env_name"' \
        --preview-window=right:40% | \
    sed 's/^[🎯🅒🐍📁] *//' | sed 's/ (.*//')
  
  if [ -n "$selected" ]; then
    # Handle local environments
    if [[ "$selected" =~ ^(venv|\.venv|env)$ ]]; then
      if [ -f "./$selected/bin/activate" ]; then
        source "./$selected/bin/activate"
        echo "✅ Activated local environment: $selected"
      else
        echo "❌ Local environment not found: $selected"
      fi
    else
      _activate_environment "$selected"
      # Remember association for non-local environments
      if [[ ! "$PWD" =~ ^(/tmp|/var) ]]; then
        _associate_project_env "$current_project" "$selected"
      fi
    fi
  fi
}

# Simplified vc - create environment
vc() {
  local name="$1"
  local template="$2"
  
  if [ -z "$name" ]; then
    echo "Usage: vc <env_name> [template] OR vc local [template]"
    echo "Templates: basic, ds, de, ml, none"
    return 1
  fi
  
  # Handle local environment
  if [[ "$name" == "local" ]]; then
    if [ -d ".venv" ]; then
      echo "⚠️  Local environment already exists"
      printf "Activate existing? [Y/n]: "
      read -r REPLY
      if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
        source .venv/bin/activate
        echo "✅ Activated local environment"
      fi
      return
    fi
    
    echo "🐍 Creating local environment: .venv"
    python3 -m venv .venv && source .venv/bin/activate
    _install_template "$template"
    echo "✅ Local environment created!"
    echo "💡 Add '.venv/' to your .gitignore"
    return
  fi
  
  # Handle named environment
  local env_type=$(_get_env_type "$name")
  if [[ "$env_type" != "none" ]]; then
    echo "⚠️  Environment '$name' already exists"
    printf "Activate existing? [Y/n]: "
    read -r REPLY
    if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
      _activate_environment "$name"
    fi
    return
  fi
  
  echo "🐍 Creating environment: $name"
  python3 -m venv "$VENV_HOME/$name" && source "$VENV_HOME/$name/bin/activate"
  _install_template "$template"
  
  # Associate with project
  local project_info=$(get_project_name)
  local current_project="${project_info##*:}"
  _associate_project_env "$current_project" "$name"
  
  ENV_EXISTS_CACHE[$name]="venv"
  echo "✅ Environment '$name' created!"
}

# Project environment - fixed logic  
vp() {
  local project_info=$(get_project_name)
  local project_type="${project_info%%:*}"
  local project_name="${project_info##*:}"
  local mapped_env=$(_get_mapped_env "$project_name")

  echo "🔍 Project: $project_name ($project_type)"

  if [[ -n "$mapped_env" ]]; then
    echo "🎯 Using mapped environment: $mapped_env"
    _activate_environment "$mapped_env"
  elif [[ -d "$VENV_HOME/$project_name" ]]; then
    echo "🎯 Using project environment: $project_name"
    _activate_environment "$project_name"
    # Auto-save mapping and cache it
    _associate_project_env "$project_name" "$project_name"
  elif command -v conda >/dev/null && conda info --envs 2>/dev/null | grep -q "^$project_name "; then
    echo "🎯 Using conda environment: $project_name"
    conda activate "$project_name" 2>/dev/null && echo "✅ Activated conda: $project_name"
    # Auto-save mapping and cache it  
    _associate_project_env "$project_name" "$project_name"
  else
    echo "❓ No environment found for: $project_name"
    echo "💡 Create with: vc $project_name [ds|de|ml|basic]"
  fi
}

# Simplified vd - deactivate
vd() { _deactivate_current; }

# Simplified vl - list environments
vl() {
  echo "🐍 Virtual Environments & Project Mappings"
  echo "==========================================="
  echo ""
  
  # Show current environment
  local current=$(_get_current_env)
  if [ -n "$current" ]; then
    local type=$(_get_env_type "$current")
    echo "🟢 Currently active: $current ($type)"
  else
    echo "⚪ No environment active"
  fi
  echo ""
  
  # List all environments
  _discover_environments "detailed" "false"
  
  # Show project mappings if any exist
  if [ -s "$ENV_PROJECT_MAP" ]; then
    echo ""
    echo "🗂️  Project mappings:"
    cat "$ENV_PROJECT_MAP" | sed 's/^/  /' | sed 's/:/ → /'
  fi
}

# Simplified vs - sync requirements
vs() { _handle_requirements "sync"; }

# Environment removal - fixed logic
vr() {
  local env_name="${1:-}"
  
  if [ -z "$env_name" ]; then
    echo "Usage: vr <environment_name>"
    echo "💡 Use 'vl' to see available environments"
    return 1
  fi

  # Check if venv exists (only remove venvs, not conda)
  if [ ! -d "$VENV_HOME/$env_name" ]; then
    echo "❌ Virtual environment '$env_name' not found in $VENV_HOME"
    echo "💡 Available environments:"
    _discover_environments "simple" "false"
    return 1
  fi

  echo "🗑️  Remove virtual environment: $env_name"
  echo "📁 Location: $VENV_HOME/$env_name"
  echo "⚠️  This cannot be undone!"
  echo ""
  printf "Are you sure? [y/N]: "
  read -r REPLY

  if [[ $REPLY =~ ^[Yy]$ ]]; then
    # Deactivate if currently active
    if [ -n "$VIRTUAL_ENV" ] && [[ "$VIRTUAL_ENV" == *"$env_name" ]]; then
      deactivate
      echo "✅ Deactivated environment"
    fi

    # Remove the directory
    rm -rf "$VENV_HOME/$env_name"

    # Clean up caches and mappings
    if [[ -n "${ENV_EXISTS_CACHE[$env_name]:-}" ]]; then
      unset "ENV_EXISTS_CACHE[$env_name]"
    fi
    if [ -f "$ENV_PROJECT_MAP" ]; then
      grep -v ":$env_name$" "$ENV_PROJECT_MAP" >"${ENV_PROJECT_MAP}.tmp" 2>/dev/null || true
      mv "${ENV_PROJECT_MAP}.tmp" "$ENV_PROJECT_MAP" 2>/dev/null || true
    fi

    echo "✅ Environment '$env_name' removed"
    echo ""
    printf "Run cleanup to remove any orphaned project mappings? [y/N]: "
    read -r cleanup_reply
    if [[ $cleanup_reply =~ ^[Yy]$ ]]; then
      echo ""
      cleanup_mappings
    else
      echo "💡 Tip: Run 'cleanup-mappings' later to clean orphaned project mappings"
    fi
  else
    echo "❌ Cancelled"
  fi
}

# Forget project mapping
vf() {
  local project="${1:-$(get_project_name | cut -d: -f2)}"
  
  if grep -q "^$project:" "$ENV_PROJECT_MAP" 2>/dev/null; then
    grep -v "^$project:" "$ENV_PROJECT_MAP" >"${ENV_PROJECT_MAP}.tmp"
    mv "${ENV_PROJECT_MAP}.tmp" "$ENV_PROJECT_MAP"
    # Clear cache entry safely
    if [[ -n "${ENV_CACHE[env_map:$project]:-}" ]]; then
      unset "ENV_CACHE[env_map:$project]"
    fi
    echo "🗑️  Removed mapping for: $project"
  else
    echo "ℹ️  No mapping found for: $project"
  fi
}

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

show_project_info() {
  local project_info=$(get_project_name)
  local project_type="${project_info%%:*}"
  local project_name="${project_info##*:}"
  
  echo "🔍 Project Detection Results"
  echo "============================"
  echo "📁 Directory: $PWD"
  echo "📋 Name: $project_name"
  echo "🏷️  Method: $project_type"
  
  local mapped_env=$(_get_mapped_env "$project_name")
  [[ -n "$mapped_env" ]] && echo "🔗 Mapped to: $mapped_env"
}

clear_env_cache() {
  PROJECT_CACHE=() ENV_CACHE=() ENV_EXISTS_CACHE=()
  echo "🗑️ Environment cache cleared"
}

cache_stats() {
  echo "📊 Cache Statistics:"
  echo "  Project: ${#PROJECT_CACHE[@]} | Environment: ${#ENV_CACHE[@]} | Exists: ${#ENV_EXISTS_CACHE[@]}"
}

# Debug function to troubleshoot environment issues
debug_env() {
  local env_name="${1:-}"
  if [ -z "$env_name" ]; then
    echo "Usage: debug_env <environment_name>"
    return 1
  fi
  
  echo "🔍 Environment Debug: $env_name"
  echo "================================"
  echo "📁 VENV_HOME: $VENV_HOME"
  echo "📁 Expected path: $VENV_HOME/$env_name"
  echo "📂 Directory exists: $([ -d "$VENV_HOME/$env_name" ] && echo "✅ YES" || echo "❌ NO")"
  echo ""
  echo "🔍 Detection results:"
  echo "  _get_env_type: $(_get_env_type "$env_name")"
  echo ""
  echo "🗺️  Project mappings mentioning '$env_name':"
  grep "$env_name" "$ENV_PROJECT_MAP" 2>/dev/null || echo "  (none found)"
  echo ""
  echo "💾 Cache entries:"
  echo "  ENV_EXISTS_CACHE[$env_name]: ${ENV_EXISTS_CACHE[$env_name]:-'(not cached)'}"
}

# OPTIMIZED auto-activation (minimal overhead)
auto_activate_venv() {
  # Early returns for performance
  [[ ! -o interactive ]] && return
  [[ "$PWD" =~ ^(/tmp|/var) ]] && return

  local project_info=$(get_project_name)
  local project_name="${project_info##*:}"
  local current_env=""
  
  # Get current environment
  if [[ -n "$VIRTUAL_ENV" ]]; then
    current_env=$(basename "$VIRTUAL_ENV")
  elif [[ -n "$CONDA_DEFAULT_ENV" && "$CONDA_DEFAULT_ENV" != "base" ]]; then
    current_env="$CONDA_DEFAULT_ENV"
  fi

  # Skip if already in correct environment
  [[ "$current_env" == "$project_name" ]] && return

  # Find target environment
  local target_env=$(_get_mapped_env "$project_name")
  [[ -z "$target_env" && -d "$VENV_HOME/$project_name" ]] && target_env="$project_name"

  # Switch environment if needed
  if [[ -n "$target_env" && "$target_env" != "$current_env" ]]; then
    [[ -n "$current_env" ]] && { 
      [[ -n "$VIRTUAL_ENV" ]] && deactivate 2>/dev/null
      [[ -n "$CONDA_DEFAULT_ENV" && "$CONDA_DEFAULT_ENV" != "base" ]] && conda deactivate 2>/dev/null
    }
    
    case "${ENV_EXISTS_CACHE[$target_env]:-}" in
      "venv"|"") [ -d "$VENV_HOME/$target_env" ] && source "$VENV_HOME/$target_env/bin/activate" 2>/dev/null ;;
      "conda") conda activate "$target_env" 2>/dev/null ;;
    esac
  fi
}

# Auto-activation setup for zsh
if [[ -n "$ZSH_VERSION" ]]; then
  autoload -U add-zsh-hook
  add-zsh-hook chpwd auto_activate_venv
  auto_activate_venv
fi

# Aliases
alias project-info='show_project_info'
alias clear-cache='clear_env_cache'
alias cache-stats='cache_stats'
alias cleanup-mappings='cleanup_mappings'
alias vh='venv_help'
alias vh='echo "🐍 Virtual Environment Quick Reference
======================================
va [env]     - Activate environment (fuzzy select if no arg)
vc <name>    - Create environment with template [ds|de|ml|basic]
vp           - Project environment (auto-detect)
vd           - Deactivate current environment
vl           - List environments and mappings
vf [project] - Forget project mapping
vr <env>     - Remove environment
vs           - Sync requirements.txt"'

show-python-info() {
  echo "🐍 Python Environment Info:"
  echo "  Python: $(python --version 2>/dev/null || echo "Not found")"
  echo "  Pip: $(pip --version 2>/dev/null || echo "Not found")"
  echo "  Packages: $(pip list 2>/dev/null | wc -l || echo "Unknown")"
  [[ -n "$VIRTUAL_ENV" ]] && echo "  Virtual Env: $(basename "$VIRTUAL_ENV")"
  [[ -n "$CONDA_DEFAULT_ENV" ]] && echo "  Conda Env: $CONDA_DEFAULT_ENV"
}
