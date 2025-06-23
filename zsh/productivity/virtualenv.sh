#!/bin/zsh
# =============================================================================
# Optimized Direnv-based Virtual Environment Management
# =============================================================================

export CENTRAL_VENVS="$HOME/.central_venvs"
[[ ! -d "$CENTRAL_VENVS" ]] && mkdir -p "$CENTRAL_VENVS"

# =============================================================================
# CORE HELPER FUNCTIONS
# =============================================================================

# Get environment path
_env_path() { echo "$CENTRAL_VENVS/$1"; }

# Check if environment exists
_env_exists() { [[ -d "$(_env_path "$1")" ]]; }

# Get environment name from .envrc
_get_envrc_env() {
  [[ -f ".envrc" ]] || return 1
  grep -o 'source.*activate' .envrc 2>/dev/null | sed -n 's|.*/.central_venvs/\([^/]*\)/.*|\1|p'
}

# Reload direnv safely
_reload_direnv() {
  if direnv allow . && direnv reload; then
    echo "✅ Environment reloaded"
  else
    echo "❌ Failed to reload direnv"
    return 1
  fi
}

# Interactive environment selection
_select_env() {
  local prompt="${1:-🐍 Select environment: }"
  
  if ! command -v fzf >/dev/null; then
    echo "📋 Available environments:"
    _list_environments
    echo "💡 Install fzf for interactive selection"
    return 1
  fi
  
  _list_environments | fzf --prompt="$prompt" --height=40% | awk '{print $2}'
}

# Create .envrc file and reload
_create_envrc() {
  local env_name="$1"
  cat > .envrc << EOF
# Auto-generated - Virtual Environment: $env_name
source $(_env_path "$env_name")/bin/activate
EOF
  direnv allow .
  echo "📄 Created .envrc pointing to: $env_name"
}

# List environments in consistent format
_list_environments() {
  if [[ ! -d "$CENTRAL_VENVS" || -z "$(ls -A "$CENTRAL_VENVS" 2>/dev/null)" ]]; then
    echo "   (no environments found)"
    return
  fi
  
  for env_dir in "$CENTRAL_VENVS"/*; do
    [[ ! -d "$env_dir" ]] && continue
    local name=$(basename "$env_dir")
    local size=$(du -sh "$env_dir" 2>/dev/null | cut -f1 || echo "?")
    echo "   🐍 $name ($size)"
  done
}

# Install template packages
_install_template() {
  local template="$1"
  pip install --upgrade pip setuptools wheel
  
  case "$template" in
    ""|"none")
      [[ -f "requirements.txt" ]] && pip install -r requirements.txt || echo "📝 Empty environment created"
      ;;
    "basic")
      echo "⚡ Installing basic development packages..."
      pip install requests black flake8 pytest pylint mypy
      ;;
    "ds"|"data-science")
      echo "📊 Installing data science packages..."
      pip install ipython jupyter pandas numpy scipy matplotlib seaborn scikit-learn plotly black flake8 pylint mypy
      ;;
    "de"|"data-engineering")
      echo "🔧 Installing data engineering packages..."
      pip install ipython jupyter pandas polars duckdb sqlalchemy great-expectations requests pyarrow black flake8 pylint mypy
      ;;
    "ml"|"machine-learning")
      echo "🤖 Installing ML packages..."
      pip install ipython jupyter pandas numpy matplotlib seaborn scikit-learn plotly black flake8 pylint mypy
      echo "💡 Add deep learning: pip install torch OR tensorflow"
      ;;
    *)
      echo "❌ Unknown template: $template. Available: basic, ds, de, ml, none"
      return 1
      ;;
  esac
}

# =============================================================================
# MAIN FUNCTIONS
# =============================================================================

# Create virtual environment and .envrc
vc() {
  local name="$1" template="$2"
  
  [[ -z "$name" ]] && {
    echo "Usage: vc <env_name> [template] | vc local [template]"
    echo "Templates: basic, ds, de, ml, none"
    return 1
  }
  
  # Handle "local" - use directory name
  [[ "$name" == "local" ]] && { name=$(basename "$PWD"); template="$2"; }
  
  local venv_path="$(_env_path "$name")"
  
  # Handle existing environment
  if _env_exists "$name"; then
    echo "⚠️  Environment '$name' exists. Setting up .envrc..."
    _create_envrc "$name"
    return 0
  fi
  
  echo "🐍 Creating virtual environment: $name at $venv_path"
  
  python3 -m venv "$venv_path" || { echo "❌ Failed to create environment"; return 1; }
  _create_envrc "$name"
  
  # Install packages
  source "$venv_path/bin/activate"
  _install_template "$template"
  
  echo "✅ Environment '$name' created!"
  echo "💡 Add '.envrc' to .gitignore if needed"
}

# Activate environment with smart .envrc handling
va() {
  local selected="$1"
  
  # Interactive selection if no argument
  [[ -z "$selected" ]] && { selected=$(_select_env); [[ -z "$selected" ]] && return 0; }
  
  # Validate environment exists
  if ! _env_exists "$selected"; then
    echo "❌ Environment '$selected' not found"
    echo "💡 Available environments:"
    _list_environments
    return 1
  fi
  
  # Smart .envrc handling
  if [[ -f ".envrc" ]]; then
    local current_env=$(_get_envrc_env)
    echo "📄 Found existing .envrc"
    [[ -n "$current_env" ]] && echo "🔗 Currently points to: $current_env"
    echo "🎯 You want to use: $selected"
    
    [[ "$current_env" == "$selected" ]] && { echo "✅ Already configured correctly"; _reload_direnv; return 0; }
    
    echo -e "\n1) Override .envrc (make $selected project default)\n2) Session only (manual activation)\n3) Cancel"
    printf "Choice [1-3]: "; read -r choice
    
    case "$choice" in
      1) echo "🔄 Updating .envrc..."; _create_envrc "$selected" ;;
      2) source "$(_env_path "$selected")/bin/activate"; echo "✅ Session activation: $selected" ;;
      *) echo "❌ Cancelled"; return 0 ;;
    esac
  else
    echo "📄 Creating .envrc for: $selected"
    _create_envrc "$selected"
  fi
}

# Project environment management
vp() {
  local current_env=$(_get_envrc_env)
  
  if [[ -n "$current_env" ]]; then
    echo "📋 Found .envrc pointing to: $current_env"
    if _env_exists "$current_env"; then
      _reload_direnv
    else
      echo "❌ Environment '$current_env' not found!"
      echo "💡 Use 'va' to select different environment or 'vc' to create it"
    fi
    return 0
  fi
  
  # No .envrc - try to set up project environment
  local project_name=$(basename "$PWD")
  
  if _env_exists "$project_name"; then
    echo "🎯 Found environment: $project_name"
    _create_envrc "$project_name"
  else
    echo "❓ No environment for project: $project_name"
    echo "💡 Create with: vc $project_name [template] or vc local [template]"
  fi
}

# Simple functions
vd() { 
  [[ -n "$VIRTUAL_ENV" ]] && { deactivate; echo "✅ Environment deactivated"; } || echo "ℹ️  No active environment"
}

vf() { 
  [[ -f ".envrc" ]] && { rm ".envrc"; echo "🗑️  Removed .envrc"; } || echo "ℹ️  No .envrc found"
}

vs() {
  [[ -z "$VIRTUAL_ENV" ]] && { echo "❌ No active environment. Activate first."; return 1; }
  [[ -f "requirements.txt" ]] && { echo "📦 Installing requirements..."; pip install -r requirements.txt; } || echo "❌ No requirements.txt"
}

# Remove environment
vr() {
  local env_name="$1"
  [[ -z "$env_name" ]] && { echo "Usage: vr <environment_name>"; _list_environments; return 1; }
  
  if ! _env_exists "$env_name"; then
    echo "❌ Environment '$env_name' not found"
    return 1
  fi
  
  echo "🗑️  Remove: $env_name at $(_env_path "$env_name")"
  printf "⚠️  Cannot be undone! Continue? [y/N]: "; read -r REPLY
  
  [[ $REPLY =~ ^[Yy]$ ]] || { echo "❌ Cancelled"; return 0; }
  
  # Deactivate if active
  [[ -n "$VIRTUAL_ENV" && "$VIRTUAL_ENV" == *"$env_name" ]] && { deactivate; echo "✅ Deactivated"; }
  
  rm -rf "$(_env_path "$env_name")"
  echo "✅ Environment '$env_name' removed"
}

# List environments and status
vl() {
  echo "🐍 Virtual Environments\n======================="
  
  # Current status
  if [[ -n "$VIRTUAL_ENV" ]]; then
    local current=$(basename "$VIRTUAL_ENV")
    local managed=$([[ -f ".envrc" ]] && echo "direnv" || echo "manual")
    echo "🟢 Active: $current ($managed)"
  else
    echo "⚪ No environment active"
  fi
  
  echo -e "\n📁 Central environments ($CENTRAL_VENVS):"
  _list_environments
  
  # Current directory info
  local current_env=$(_get_envrc_env)
  echo -e "\n📂 Current directory: $(basename "$PWD")"
  if [[ -n "$current_env" ]]; then
    echo "   📄 .envrc → $current_env"
  else
    echo "   ❌ No .envrc (not direnv-managed)"
  fi
}

# =============================================================================
# UTILITIES
# =============================================================================

show_project_info() {
  echo "🔍 Project Environment Status\n============================="
  echo "📁 Directory: $PWD\n📋 Project: $(basename "$PWD")"
  
  local current_env=$(_get_envrc_env)
  if [[ -n "$current_env" ]]; then
    echo "📄 .envrc → $current_env"
    _env_exists "$current_env" && echo "✅ Environment exists" || echo "❌ Environment missing!"
    echo "🔄 Direnv: $(direnv status)"
  else
    echo "📄 No .envrc found\n💡 Use 'vp' to set up project environment"
  fi
  
  [[ -n "$VIRTUAL_ENV" ]] && echo "🟢 Active: $(basename "$VIRTUAL_ENV")" || echo "⚪ No active environment"
}

check_envrc_health() {
  echo "🔍 Checking .envrc files..."
  local issues=0
  
  while IFS= read -r -d '' envrc_file; do
    local dir=$(dirname "$envrc_file")
    local env_name=$(grep -o 'source.*activate' "$envrc_file" 2>/dev/null | sed -n 's|.*/.central_venvs/\([^/]*\)/.*|\1|p')
    
    if [[ -n "$env_name" ]]; then
      if _env_exists "$env_name"; then
        echo "✅ $dir/.envrc → $env_name"
      else
        echo "❌ $dir/.envrc → $env_name (missing)"
        ((issues++))
      fi
    else
      echo "⚠️  $dir/.envrc (unrecognized format)"
      ((issues++))
    fi
  done < <(find . -name ".envrc" -type f -print0 2>/dev/null)
  
  ((issues == 0)) && echo "✅ All .envrc files healthy" || echo "⚠️  Found $issues issue(s)"
}

show_python_info() {
  echo "🐍 Python Environment Info:"
  echo "  Python: $(python --version 2>/dev/null || echo "Not found")"
  echo "  Pip: $(pip --version 2>/dev/null || echo "Not found")"
  
  if [[ -n "$VIRTUAL_ENV" ]]; then
    echo "  Virtual Env: $(basename "$VIRTUAL_ENV")"
    echo "  Packages: $(pip list 2>/dev/null | wc -l || echo "Unknown")"
    echo "  Location: $VIRTUAL_ENV"
  else
    echo "  Virtual Env: None active"
  fi
  
  echo "  Direnv: $(command -v direnv >/dev/null && direnv version || echo "Not found")"
}

venv_help() {
  cat << 'EOF'
🐍 Direnv-based Virtual Environment Quick Reference
==================================================
vc <name> [template]   - Create environment + .envrc
vc local [template]    - Create env named after current dir  
va [env]               - Activate environment (always shows selector if no arg)
vp                     - Project environment (reload .envrc or set up new)
vd                     - Deactivate current environment
vf                     - Remove .envrc (forget project)
vr <env>               - Remove environment completely
vs                     - Sync requirements.txt
vl                     - List environments and status

Templates: basic, ds (data-science), de (data-engineering), ml, none

💡 How it works:
   • Environments stored in: ~/.central_venvs/
   • direnv automatically activates/deactivates based on .envrc
   • va: choose any environment (smart .envrc handling)
   • vp: project-specific environment management

Utilities:
project-info    - Show current project environment status
check-envrc     - Find broken .envrc references
EOF
}

# =============================================================================
# ALIASES
# =============================================================================

alias project-info='show_project_info'
alias check-envrc='check_envrc_health'
alias vh='venv_help'
