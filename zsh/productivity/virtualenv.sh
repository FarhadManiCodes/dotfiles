# =============================================================================
# FIXED Virtual Environment Management with Proper Zsh Array Handling
# =============================================================================

# Configuration
export VENV_HOME="$HOME/virtualenv"
export ENV_PROJECT_MAP="$HOME/.env_project_map"

# Ensure directories exist
[ ! -d "$VENV_HOME" ] && mkdir -p "$VENV_HOME"
[ ! -f "$ENV_PROJECT_MAP" ] && touch "$ENV_PROJECT_MAP"

# Performance caches - FIXED: Proper zsh associative array declaration
typeset -A PROJECT_CACHE
typeset -A ENV_CACHE
typeset -A ENV_EXISTS_CACHE

# Check for conflicting aliases and remove them
if alias vh >/dev/null 2>&1; then
  unalias vh 2>/dev/null
fi

# =============================================================================
# SHARED HELPER FUNCTIONS - FIXED
# =============================================================================

# Unified environment discovery - used by va, vl, and other functions
_discover_environments() {
  local format="${1:-detailed}" # detailed|simple|fzf
  local include_local="${2:-true}"
  local environments=()
  
  # Conda environments
  if command -v conda >/dev/null 2>&1; then
    local conda_output
    conda_output=$(conda info --envs 2>/dev/null | awk '/^\w/ && $1!="base" {print $1 " " $2}')
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      local name=$(echo "$line" | awk '{print $1}')
      local path=$(echo "$line" | awk '{print $2}')
      case "$format" in
        "fzf") environments+=("🅒 $name ($path)") ;;
        "simple") environments+=("$name (conda)") ;;
        "detailed") environments+=("🅒 $name - $path") ;;
      esac
    done <<< "$conda_output"
  fi
  
  # Virtual environments
  if [[ -d "$VENV_HOME" ]]; then
    for env_dir in "$VENV_HOME"/*; do
      [[ ! -d "$env_dir" ]] && continue
      local name=$(basename "$env_dir")
      local projects=$(grep ":$name\$" "$ENV_PROJECT_MAP" 2>/dev/null | cut -d: -f1 | tr '\n' ', ' | sed 's/,$//')
      case "$format" in
        "fzf") 
          if [[ -n "$projects" ]]; then
            environments+=("🐍 $name ($env_dir - used in: $projects)")
          else
            environments+=("🐍 $name ($env_dir)")
          fi
          ;;
        "simple") environments+=("$name (venv)") ;;
        "detailed")
          if [[ -n "$projects" ]]; then
            environments+=("🐍 $name → used in: $projects")
          else
            environments+=("🐍 $name")
          fi
          ;;
      esac
    done
  fi
  
  # Local environments (for fzf format)
  if [[ "$format" == "fzf" && "$include_local" == "true" ]]; then
    for local_env in venv .venv env; do
      [[ -d "$local_env" ]] && environments+=("📁 $local_env (local in $(basename "$PWD"))")
    done
  fi
  
  printf '%s\n' "${environments[@]}"
}

# ROBUST: Environment type detection with safe caching
_get_env_type() {
  local env_name="$1"
  [[ -z "$env_name" ]] && { echo "none"; return; }
  
  # Create safe cache key by removing special characters
  local cache_key="env_type_${env_name//[^a-zA-Z0-9]/_}"
  
  # Try to get from cache with error protection
  local cached_result=""
  { cached_result="${ENV_EXISTS_CACHE[$cache_key]}" } 2>/dev/null
  if [[ -n "$cached_result" ]]; then
    echo "$cached_result"
    return
  fi
  
  local type="none"
  
  # Check for virtual environment first (faster)
  if [[ -d "$VENV_HOME/$env_name" ]]; then
    type="venv"
  # Then check conda (slower)
  elif command -v conda >/dev/null 2>&1; then
    if conda info --envs 2>/dev/null | grep -q "^$env_name "; then
      type="conda"
    fi
  fi
  
  # Try to cache result with error protection
  { ENV_EXISTS_CACHE[$cache_key]="$type" } 2>/dev/null
  
  echo "$type"
}

# Unified environment activation
_activate_environment() {
  local env_name="$1"
  [[ -z "$env_name" ]] && { echo "❌ Environment name required"; return 1; }
  
  local type=$(_get_env_type "$env_name")
  
  case "$type" in
    "conda")
      if conda activate "$env_name" 2>/dev/null; then
        echo "✅ Activated conda: $env_name"
      else
        echo "❌ Failed to activate conda environment: $env_name"
        return 1
      fi
      ;;
    "venv")
      if source "$VENV_HOME/$env_name/bin/activate" 2>/dev/null; then
        echo "✅ Activated venv: $env_name"
      else
        echo "❌ Failed to activate virtual environment: $env_name"
        return 1
      fi
      ;;
    "none")
      echo "❌ Environment '$env_name' not found"
      return 1
      ;;
  esac
}

# Unified environment deactivation
_deactivate_current() {
  if [[ -n "$CONDA_DEFAULT_ENV" && "$CONDA_DEFAULT_ENV" != "base" ]]; then
    conda deactivate && echo "✅ Deactivated conda environment"
  elif [[ -n "$VIRTUAL_ENV" ]]; then
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
      [[ -f "requirements.txt" ]] && echo "found" || echo "not_found"
      ;;
    "install")
      if [[ -f "requirements.txt" ]]; then
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
      if [[ -z "$VIRTUAL_ENV" ]]; then
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
  if [[ "$template" != "" && "$template" != "none" && -f "requirements.txt" ]]; then
    echo "⚠️  Note: requirements.txt found but ignored (using $template template)"
    echo "💡 Use template 'none' to install from requirements.txt instead"
  fi
}

# Shared project-environment association logic with safe caching
_associate_project_env() {
  local project_name="$1" 
  local env_name="$2"
  
  [[ -z "$project_name" || -z "$env_name" ]] && return
  
  # Skip temporary directories
  [[ "$PWD" =~ ^(/tmp|/var) ]] && return
  
  # Update mapping file safely
  local temp_file="${ENV_PROJECT_MAP}.tmp.$"
  if [[ -f "$ENV_PROJECT_MAP" ]]; then
    grep -v "^${project_name}:" "$ENV_PROJECT_MAP" > "$temp_file" 2>/dev/null || true
  else
    touch "$temp_file"
  fi
  echo "$project_name:$env_name" >> "$temp_file"
  mv "$temp_file" "$ENV_PROJECT_MAP"
  
  # Update cache with safe key and error protection
  local cache_key="env_map_${project_name//[^a-zA-Z0-9]/_}"
  { ENV_CACHE[$cache_key]="$env_name" } 2>/dev/null
  
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
# PROJECT DETECTION - ROBUST VERSION WITHOUT PROBLEMATIC CACHING
# =============================================================================

get_project_name() {
  local dir="$PWD"
  
  # SAFE APPROACH: Use hash of path as cache key to avoid special characters
  local cache_key
  if command -v md5sum >/dev/null 2>&1; then
    cache_key=$(echo "$dir" | md5sum | cut -d' ' -f1)
  elif command -v shasum >/dev/null 2>&1; then
    cache_key=$(echo "$dir" | shasum | cut -d' ' -f1)
  else
    # Fallback: simple substitution but more comprehensive
    cache_key=$(echo "$dir" | sed 's|[^a-zA-Z0-9]|_|g')
  fi
  
  # Try to get from cache, but don't fail if cache access fails
  local cached_result=""
  { cached_result="${PROJECT_CACHE[$cache_key]}" } 2>/dev/null
  if [[ -n "$cached_result" ]]; then
    echo "$cached_result"
    return
  fi
  
  local result=""
  
  # Fast pattern matching first
  if [[ "$dir" =~ /(projects|work|dev)/([^/]+) ]]; then
    # Use zsh match array instead of bash BASH_REMATCH
    result="${match[1]}:${match[2]}"
  elif [[ -f ".project_name" ]]; then
    local name=$(cat .project_name 2>/dev/null | tr -d '\n')
    result="manual:$name"
  elif [[ -f "pyproject.toml" ]]; then
    local name=$(grep -m1 -E "^name\s*=" pyproject.toml 2>/dev/null | sed 's/.*=\s*["\x27]\([^"\x27]*\)["\x27].*/\1/')
    result="pyproject:${name:-$(basename "$dir")}"
  elif [[ -f "requirements.txt" || -f "setup.py" || -f "Pipfile" ]]; then
    result="python:$(basename "$dir")"
  elif [[ -d "notebooks" && -d "data" ]]; then
    result="datascience:$(basename "$dir")"
  elif [[ -f "build.sbt" || -f "pom.xml" ]]; then
    result="scala:$(basename "$dir")"
  elif [[ -f "Dockerfile" || -f "docker-compose.yml" ]]; then
    result="docker:$(basename "$dir")"
  elif git rev-parse --show-toplevel >/dev/null 2>&1; then
    local git_root=$(git rev-parse --show-toplevel 2>/dev/null)
    result="git:$(basename "$git_root")"
  else
    result="directory:$(basename "$dir")"
  fi
  
  # Try to cache result, but continue even if caching fails
  { PROJECT_CACHE[$cache_key]="$result" } 2>/dev/null
  
  echo "$result"
}

# SAFE: Simplified cache handling with error protection
_get_mapped_env() {
  local project_name="$1"
  [[ -z "$project_name" ]] && return
  
  # Create safe cache key
  local cache_key="env_map_${project_name//[^a-zA-Z0-9]/_}"
  
  # Try to get from cache with error protection
  local cached_result=""
  { cached_result="${ENV_CACHE[$cache_key]}" } 2>/dev/null
  if [[ -n "$cached_result" ]]; then
    echo "$cached_result"
    return
  fi
  
  # Get from file
  local mapped_env=$(grep -m1 "^${project_name}:" "$ENV_PROJECT_MAP" 2>/dev/null | cut -d: -f2)
  
  # Try to cache with error protection
  { ENV_CACHE[$cache_key]="${mapped_env:-}" } 2>/dev/null
  
  echo "$mapped_env"
}

# =============================================================================
# MAIN FUNCTIONS - FIXED
# =============================================================================

# Enhanced va - activate environment
va() {
  if [[ $# -gt 0 ]]; then
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
  [[ -n "$suggested_env" ]] && environments+=("🎯 $suggested_env (suggested for $current_project)")
  
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
  
  if [[ -n "$selected" ]]; then
    # Handle local environments
    if [[ "$selected" =~ ^(venv|\.venv|env)$ ]]; then
      if [[ -f "./$selected/bin/activate" ]]; then
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

# Simplified vc - create environment (robust version)
vc() {
  local name="$1"
  local template="$2"
  
  if [[ -z "$name" ]]; then
    echo "Usage: vc <env_name> [template] OR vc local [template]"
    echo "Templates: basic, ds, de, ml, none"
    return 1
  fi
  
  # Handle local environment
  if [[ "$name" == "local" ]]; then
    if [[ -d ".venv" ]]; then
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
  if python3 -m venv "$VENV_HOME/$name" && source "$VENV_HOME/$name/bin/activate"; then
    _install_template "$template"
    
    # Associate with project
    local project_info=$(get_project_name)
    local current_project="${project_info##*:}"
    _associate_project_env "$current_project" "$name"
    
    # Update cache safely
    local cache_key="env_type_${name//[^a-zA-Z0-9]/_}"
    { ENV_EXISTS_CACHE[$cache_key]="venv" } 2>/dev/null
    
    echo "✅ Environment '$name' created!"
  else
    echo "❌ Failed to create environment: $name"
    return 1
  fi
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
    if conda activate "$project_name" 2>/dev/null; then
      echo "✅ Activated conda: $project_name"
      # Auto-save mapping and cache it  
      _associate_project_env "$project_name" "$project_name"
    fi
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
  if [[ -n "$current" ]]; then
    local type=$(_get_env_type "$current")
    echo "🟢 Currently active: $current ($type)"
  else
    echo "⚪ No environment active"
  fi
  echo ""
  
  # List all environments
  _discover_environments "detailed" "false"
  
  # Show project mappings if any exist
  if [[ -s "$ENV_PROJECT_MAP" ]]; then
    echo ""
    echo "🗂️  Project mappings:"
    cat "$ENV_PROJECT_MAP" | sed 's/^/  /' | sed 's/:/ → /'
  fi
}

# Simplified vs - sync requirements
vs() { _handle_requirements "sync"; }

# Environment removal - robust version
vr() {
  local env_name="${1:-}"
  
  if [[ -z "$env_name" ]]; then
    echo "Usage: vr <environment_name>"
    echo "💡 Use 'vl' to see available environments"
    return 1
  fi

  # Check if venv exists (only remove venvs, not conda)
  if [[ ! -d "$VENV_HOME/$env_name" ]]; then
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
    if [[ -n "$VIRTUAL_ENV" && "$VIRTUAL_ENV" == *"$env_name" ]]; then
      deactivate
      echo "✅ Deactivated environment"
    fi

    # Remove the directory
    rm -rf "$VENV_HOME/$env_name"

    # Clean up caches - use safe approach
    local cache_key="env_type_${env_name//[^a-zA-Z0-9]/_}"
    { unset "ENV_EXISTS_CACHE[$cache_key]" } 2>/dev/null
    
    if [[ -f "$ENV_PROJECT_MAP" ]]; then
      local temp_file="${ENV_PROJECT_MAP}.tmp.$"
      grep -v ":$env_name\$" "$ENV_PROJECT_MAP" > "$temp_file" 2>/dev/null || true
      mv "$temp_file" "$ENV_PROJECT_MAP" 2>/dev/null || true
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

# Forget project mapping - robust version
vf() {
  local project="${1:-$(get_project_name | cut -d: -f2)}"
  
  if grep -q "^$project:" "$ENV_PROJECT_MAP" 2>/dev/null; then
    local temp_file="${ENV_PROJECT_MAP}.tmp.$"
    grep -v "^$project:" "$ENV_PROJECT_MAP" > "$temp_file"
    mv "$temp_file" "$ENV_PROJECT_MAP"
    # Clear cache entry safely
    local cache_key="env_map_${project//[^a-zA-Z0-9]/_}"
    { unset "ENV_CACHE[$cache_key]" } 2>/dev/null
    echo "🗑️  Removed mapping for: $project"
  else
    echo "ℹ️  No mapping found for: $project"
  fi
}

# =============================================================================
# UTILITY FUNCTIONS - FIXED
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
  PROJECT_CACHE=()
  ENV_CACHE=()
  ENV_EXISTS_CACHE=()
  echo "🗑️ Environment cache cleared"
}

cache_stats() {
  echo "📊 Cache Statistics:"
  echo "  Project: ${#PROJECT_CACHE[@]} | Environment: ${#ENV_CACHE[@]} | Exists: ${#ENV_EXISTS_CACHE[@]}"
}

# FIXED: Debug function to troubleshoot environment issues
debug_env() {
  local env_name="${1:-}"
  if [[ -z "$env_name" ]]; then
    echo "Usage: debug_env <environment_name>"
    return 1
  fi
  
  echo "🔍 Environment Debug: $env_name"
  echo "================================"
  echo "📁 VENV_HOME: $VENV_HOME"
  echo "📁 Expected path: $VENV_HOME/$env_name"
  echo "📂 Directory exists: $([[ -d "$VENV_HOME/$env_name" ]] && echo "✅ YES" || echo "❌ NO")"
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

# FIXED: Cleanup function for orphaned mappings
cleanup_mappings() {
  echo "🧹 Cleaning up orphaned project mappings..."
  
  if [[ ! -f "$ENV_PROJECT_MAP" ]]; then
    echo "No mapping file found"
    return
  fi
  
  local temp_file="${ENV_PROJECT_MAP}.tmp.$$"
  local removed=0
  
  while IFS=: read -r project env; do
    # Check if environment still exists
    if [[ -d "$VENV_HOME/$env" ]] || (command -v conda >/dev/null && conda info --envs 2>/dev/null | grep -q "^$env "); then
      echo "$project:$env" >> "$temp_file"
    else
      echo "  Removing orphaned mapping: $project → $env"
      ((removed++))
    fi
  done < "$ENV_PROJECT_MAP"
  
  if [[ $removed -gt 0 ]]; then
    mv "$temp_file" "$ENV_PROJECT_MAP"
    echo "✅ Removed $removed orphaned mapping(s)"
  else
    rm -f "$temp_file"
    echo "✅ No orphaned mappings found"
  fi
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
    
    local env_type="${ENV_EXISTS_CACHE[$target_env]:-}"
    case "$env_type" in
      "venv"|"") [[ -d "$VENV_HOME/$target_env" ]] && source "$VENV_HOME/$target_env/bin/activate" 2>/dev/null ;;
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

# =============================================================================
# ALIASES AND HELP
# =============================================================================

alias project-info='show_project_info'
alias clear-cache='clear_env_cache'
alias cache-stats='cache_stats'
alias cleanup-mappings='cleanup_mappings'

# Help function
venv_help() {
  echo "🐍 Virtual Environment Quick Reference"
  echo "======================================"
  echo "va [env]     - Activate environment (fuzzy select if no arg)"
  echo "vc <name>    - Create environment with template [ds|de|ml|basic]"
  echo "vp           - Project environment (auto-detect)"
  echo "vd           - Deactivate current environment"
  echo "vl           - List environments and mappings"
  echo "vf [project] - Forget project mapping"
  echo "vr <env>     - Remove environment"
  echo "vs           - Sync requirements.txt"
  echo ""
  echo "Utility commands:"
  echo "project-info     - Show project detection results"
  echo "clear-cache      - Clear internal caches"
  echo "cache-stats      - Show cache statistics"
  echo "cleanup-mappings - Remove orphaned project mappings"
  echo "debug_env <env>  - Debug environment issues"
}

alias vh='venv_help'

show-python-info() {
  echo "🐍 Python Environment Info:"
  echo "  Python: $(python --version 2>/dev/null || echo "Not found")"
  echo "  Pip: $(pip --version 2>/dev/null || echo "Not found")"
  echo "  Packages: $(pip list 2>/dev/null | wc -l || echo "Unknown")"
  [[ -n "$VIRTUAL_ENV" ]] && echo "  Virtual Env: $(basename "$VIRTUAL_ENV")"
  [[ -n "$CONDA_DEFAULT_ENV" ]] && echo "  Conda Env: $CONDA_DEFAULT_ENV"
}
