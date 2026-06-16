# =============================================================================
# Direnv-based Virtual Environment Management (Powered by uv)
# Location: ~/.config/zsh/functions/virtualenv.zsh
# =============================================================================

export CENTRAL_VENVS="$HOME/.central_venvs"
export DEFAULT_PYTHON="3.13"

[[ ! -d "$CENTRAL_VENVS" ]] && mkdir -p "$CENTRAL_VENVS"

# Check if uv is installed
if ! command -v uv >/dev/null 2>&1; then
  echo "⚠️  uv not found! Virtual environment functions will not work."
  echo "📦 Install with: curl -LsSf https://astral.sh/uv/install.sh | sh"
fi

# =============================================================================
# VALIDATION HELPERS
# =============================================================================

TEMPLATES=("basic" "ds" "de" "ml" "none")

_is_template() {
  local arg="$1"
  [[ " ${TEMPLATES[*]} " == *" ${arg} "* ]]
}

# UPDATED: Regex match for version numbers (e.g. 3.12, 3.12.1, 3.9)
# This prevents the script from breaking when Python 3.15 comes out.
_is_version() {
  local arg="$1"
  [[ "$arg" =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ ]]
}

_is_local_name() {
  local name="$1"
  [[ "$name" == "local" || "$name" == "." ]]
}

# =============================================================================
# CORE HELPER FUNCTIONS
# =============================================================================

_env_path() { 
  local name="$1"
  if _is_local_name "$name"; then
    echo ".venv"
  else
    echo "$CENTRAL_VENVS/$name"
  fi
}

_env_exists() { 
  local name="$1"
  [[ -d "$(_env_path "$name")" ]]
}

_get_envrc_env() {
  [[ -f ".envrc" ]] || return 1
  
  # Check if it's local
  if grep -q "source ./.venv/bin/activate" .envrc 2>/dev/null; then
    echo "local"
    return 0
  fi
  
  # Check if it's centralized
  grep -o 'source.*activate' .envrc 2>/dev/null | sed -n 's|.*/.central_venvs/\([^/]*\)/.*|\1|p'
}

_reload_direnv() {
  if direnv allow . && direnv reload; then
    echo "✅ Environment reloaded"
  else
    echo "❌ Failed to reload direnv"
    return 1
  fi
}

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

# UPDATED: Safer .envrc creation
_create_envrc() {
  local env_name="$1"
  local venv_path="$(_env_path "$env_name")"
  
  # Safety check for existing custom .envrc
  if [[ -f ".envrc" ]]; then
    # If it doesn't contain our signature, it might be a manual file
    if ! grep -q "# Auto-generated" .envrc; then
        echo "⚠️  Existing .envrc found (not auto-generated)."
        echo "   It might contain custom variables."
        read "reply?Overwrite? [y/N]: "
        [[ ! "$reply" =~ ^[Yy]$ ]] && echo "❌ Skipped .envrc creation" && return 0
        
        # Create backup
        cp .envrc ".envrc.bak.$(date +%s)"
        echo "💾 Backed up old .envrc"
    fi
  fi
  
  cat > .envrc << EOF
# Auto-generated - Virtual Environment: $env_name
source $venv_path/bin/activate
EOF
  direnv allow .
  echo "📄 Created .envrc"
}

_list_environments() {
  if [[ ! -d "$CENTRAL_VENVS" || -z "$(ls -A "$CENTRAL_VENVS" 2>/dev/null)" ]]; then
    echo "   (no environments found)"
    return
  fi
  
  for env_dir in "$CENTRAL_VENVS"/*; do
    [[ ! -d "$env_dir" ]] && continue
    local name=$(basename "$env_dir")
    local size=$(du -sh "$env_dir" 2>/dev/null | cut -f1 || echo "?")
    local py_ver=$("$env_dir/bin/python" --version 2>/dev/null | awk '{print $2}')
    echo "   🐍 $name ($size) [Py $py_ver]"
  done
}

_install_template() {
  local template="$1"
  local python_path="$VIRTUAL_ENV/bin/python"

  case "$template" in
    ""|"none")
      if [[ -f "requirements.txt" ]]; then
        echo "📦 Installing from requirements.txt..."
        uv pip install -r requirements.txt --python "$python_path"
      else
        echo "📝 Empty environment created"
      fi
      ;;
    "basic")
      echo "⚡ Installing basic development packages..."
      uv pip install requests black flake8 pytest pylint mypy --python "$python_path"
      ;;
    "ds"|"data-science")
      echo "📊 Installing data science packages..."
      uv pip install ipython jupyter pandas numpy scipy matplotlib seaborn scikit-learn plotly black flake8 pylint mypy --python "$python_path"
      ;;
    "de"|"data-engineering")
      echo "🔧 Installing data engineering packages..."
      uv pip install ipython jupyter pandas polars duckdb sqlalchemy great-expectations requests pyarrow black flake8 pylint mypy --python "$python_path"
      ;;
    "ml"|"machine-learning")
      echo "🤖 Installing ML packages..."
      uv pip install ipython jupyter pandas numpy matplotlib seaborn scikit-learn plotly black flake8 pylint mypy --python "$python_path"
      echo "💡 For PyTorch/TensorFlow, run 'uv pip install torch' manually."
      ;;
    *)
      echo "❌ Unknown template: $template"
      echo "💡 Available: basic, ds, de, ml, none"
      return 1
      ;;
  esac
}

# =============================================================================
# MAIN FUNCTIONS
# =============================================================================

# Create virtual environment
# Usage: vc [name] [template] [version]
vc() {
  local name template version
  
  # Parse arguments with smart detection
  if [[ $# -eq 0 ]]; then
    # No arguments - prompt for name
    read "name?Environment name (Enter for local): "
    [[ -z "$name" ]] && name="local"
    template="none"
    version="$DEFAULT_PYTHON"
    
  elif [[ $# -eq 1 ]]; then
    if _is_template "$1"; then
      # Single template argument - prompt for name
      template="$1"
      read "name?Environment name (Enter for local): "
      [[ -z "$name" ]] && name="local"
      version="$DEFAULT_PYTHON"
    else
      # Single name argument
      name="$1"
      template="none"
      version="$DEFAULT_PYTHON"
    fi
    
  elif [[ $# -eq 2 ]]; then
    # Check for invalid: template + non-version
    if _is_template "$1" && ! _is_version "$2"; then
      echo "❌ Error: Wrong argument order"
      echo "💡 Did you mean: vc $2 $1"
      return 1
    fi
    
    if _is_template "$1" && _is_version "$2"; then
      # Template + version - prompt for name
      template="$1"
      version="$2"
      read "name?Environment name (Enter for local): "
      [[ -z "$name" ]] && name="local"
    else
      # Name + template
      name="$1"
      template="$2"
      version="$DEFAULT_PYTHON"
    fi
    
  elif [[ $# -eq 3 ]]; then
    # Full specification: name template version
    name="$1"
    template="$2"
    version="$3"
    
  else
    echo "Usage: vc [name] [template] [version]"
    echo "Templates: basic, ds, de, ml, none"
    echo "Examples:"
    echo "  vc                      # Prompts for name"
    echo "  vc myproject            # Quick create with defaults"
    echo "  vc myproject ds         # With template"
    echo "  vc myproject ds 3.12    # Full control"
    echo "  vc ds                   # Prompts for name with template"
    echo "  vc local ds             # Local .venv with template"
    return 1
  fi
  
  # Validate: name cannot be a template name
  if _is_template "$name"; then
    echo "❌ Error: Cannot use template name '$name' as environment name"
    echo "💡 Choose a different name"
    return 1
  fi
  
  # Check if environment already exists
  if _env_exists "$name" && ! _is_local_name "$name"; then
    echo "❌ Error: Environment '$name' already exists at $(_env_path "$name")"
    echo "💡 Options:"
    echo "   - Use 'va $name' to activate it"
    echo "   - Use 'vr $name' to remove it first"
    echo "   - Choose a different name"
    return 1
  fi
  
  # Check for existing local .venv
  if _is_local_name "$name" && [[ -d ".venv" ]]; then
    echo "⚠️  Warning: .venv already exists in this directory"
    read "confirm?Overwrite? [y/N]: "
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
      echo "❌ Cancelled"
      return 0
    fi
    rm -rf .venv
  fi
  
  local venv_path="$(_env_path "$name")"
  local display_name="$name"
  _is_local_name "$name" && display_name=".venv (local)"
  
  echo "🐍 Creating virtual environment: $display_name"
  echo "   Location: $venv_path"
  echo "   Python: $version"
  echo "   Template: $template"
  echo ""
  
  # Create virtual environment with uv
  uv venv "$venv_path" --python "$version" || {
    echo "❌ Failed to create environment"
    echo "💡 Check that Python $version is available"
    return 1
  }
  
  # Create .envrc for direnv
  _create_envrc "$name"
  
  # Activate and install template
  source "$venv_path/bin/activate"
  _install_template "$template"
  
  echo ""
  echo "✅ Environment '$display_name' created!"
  _is_local_name "$name" || echo "💡 Use 'va $name' to activate in other directories"
  echo "💡 direnv will auto-activate when you cd here"
}

# Activate/switch environment
va() {
  local selected="$1"
  
  # Handle local activation
  if [[ "$selected" == "local" || "$selected" == "." ]]; then
    if [[ ! -d ".venv" ]]; then
      echo "❌ No local .venv found in current directory"
      echo "💡 Create one with: vc local"
      return 1
    fi
    source .venv/bin/activate
    echo "✅ Activated local .venv"
    return 0
  fi
  
  # Interactive selection if no argument
  [[ -z "$selected" ]] && { 
    selected=$(_select_env)
    [[ -z "$selected" ]] && return 0
  }
  
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
    
    [[ "$current_env" == "$selected" ]] && { 
      echo "✅ Already configured correctly"
      _reload_direnv
      return 0
    }
    
    echo ""
    echo "1) Override .envrc (make $selected project default)"
    echo "2) Session only (manual activation)"
    echo "3) Cancel"
    read "choice?Choice [1-3]: "
    
    case "$choice" in
      1) echo "🔄 Updating .envrc..."; _create_envrc "$selected" ;;
      2) source "$(_env_path "$selected")/bin/activate"; echo "✅ Session activated: $selected" ;;
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
      echo "💡 Use 'va' to select or 'vc' to create it"
    fi
    return 0
  fi
  
  local project_name=$(basename "$PWD")
  
  if _env_exists "$project_name"; then
    echo "🎯 Found environment: $project_name"
    _create_envrc "$project_name"
  else
    echo "❓ No environment for project: $project_name"
    echo "💡 Create with: vc $project_name [template] [version]"
  fi
}

# Deactivate environment
vd() { 
  [[ -n "$VIRTUAL_ENV" ]] && { 
    deactivate
    echo "✅ Environment deactivated"
  } || echo "ℹ️  No active environment"
}

# Forget project (remove .envrc)
vf() { 
  [[ -f ".envrc" ]] && { 
    rm ".envrc"
    echo "🗑️  Removed .envrc"
  } || echo "ℹ️  No .envrc found"
}

# Sync from requirements.txt
vs() {
  [[ -z "$VIRTUAL_ENV" ]] && { 
    echo "❌ No active environment. Activate first."
    return 1
  }
  
  if [[ -f "requirements.txt" ]]; then
    echo "📦 Installing requirements..."
    uv pip install -r requirements.txt --python "$VIRTUAL_ENV/bin/python"
  else
    echo "❌ No requirements.txt found"
  fi
}

# Remove environment
vr() {
  local env_name="$1"
  
  [[ -z "$env_name" ]] && { 
    echo "Usage: vr <environment_name>"
    echo ""
    echo "Available environments:"
    _list_environments
    return 1
  }
  
  if ! _env_exists "$env_name"; then
    echo "❌ Environment '$env_name' not found"
    return 1
  fi
  
  local venv_path="$(_env_path "$env_name")"
  local size=$(du -sh "$venv_path" 2>/dev/null | cut -f1)
  
  echo "🗑️  Remove: $env_name"
  echo "   Location: $venv_path"
  echo "   Size: $size"
  read "REPLY?⚠️  Cannot be undone! Continue? [y/N]: "
  
  [[ $REPLY =~ ^[Yy]$ ]] || { 
    echo "❌ Cancelled"
    return 0
  }
  
  # Deactivate if active
  [[ -n "$VIRTUAL_ENV" && "$VIRTUAL_ENV" == *"$env_name"* ]] && { 
    deactivate
    echo "✅ Deactivated"
  }
  
  rm -rf "$venv_path"
  echo "✅ Environment '$env_name' removed"
}

# List environments (centralized only)
vl() {
  echo "🐍 Virtual Environments (uv managed)"
  echo "==================================="
  
  # Show active environment
  if [[ -n "$VIRTUAL_ENV" ]]; then
    local current=$(basename "$VIRTUAL_ENV")
    if [[ "$VIRTUAL_ENV" == *".venv"* ]]; then
      current="local (.venv)"
    fi
    local managed=$([[ -f ".envrc" ]] && echo "direnv" || echo "manual")
    echo "🟢 Active: $current ($managed)"
  else
    echo "⚪ No environment active"
  fi
  
  # Show centralized environments
  echo ""
  echo "📁 Centralized environments ($CENTRAL_VENVS):"
  _list_environments
  
  # Show current directory info
  local current_env=$(_get_envrc_env)
  echo ""
  echo "📂 Current directory: $(basename "$PWD")"
  if [[ -n "$current_env" ]]; then
    if [[ "$current_env" == "local" ]]; then
      echo "   📄 .envrc → local (.venv)"
    else
      echo "   📄 .envrc → $current_env"
    fi
  else
    echo "   ❌ No .envrc (not direnv-managed)"
  fi
  
  # Show local .venv if exists
  if [[ -d ".venv" ]]; then
    local size=$(du -sh .venv 2>/dev/null | cut -f1)
    local py_ver=$(.venv/bin/python --version 2>/dev/null | awk '{print $2}')
    echo "   🏠 Local .venv: $size [Py $py_ver]"
  fi
}

# Show active environment info
vinfo() {
  if [[ -z "$VIRTUAL_ENV" ]]; then
    echo "⚪ No active environment"
    return 0
  fi
  
  echo ""
  echo "🐍 Active Environment Info"
  echo "=========================="
  echo "Name: $(basename "$VIRTUAL_ENV")"
  echo "Python: $("$VIRTUAL_ENV/bin/python" --version)"
  echo "Location: $VIRTUAL_ENV"
  echo "Packages: $(uv pip list 2>/dev/null | wc -l)"
  echo ""
  echo "📦 Top 10 packages:"
  uv pip list 2>/dev/null | head -11 | tail -10
  echo ""
}

# =============================================================================
# UTILITIES
# =============================================================================

# Show project environment status
show_project_info() {
  echo ""
  echo "🔍 Project Environment Status"
  echo "============================="
  echo "📁 Directory: $PWD"
  echo "📋 Project: $(basename "$PWD")"
  
  local current_env=$(_get_envrc_env)
  if [[ -n "$current_env" ]]; then
    echo "📄 .envrc → $current_env"
    _env_exists "$current_env" && echo "✅ Environment exists" || echo "❌ Environment missing!"
    echo "🔄 Direnv: $(direnv status 2>/dev/null | head -1)"
  else
    echo "📄 No .envrc found"
    echo "💡 Use 'vp' to set up project environment"
  fi
  
  if [[ -n "$VIRTUAL_ENV" ]]; then
    echo "🟢 Active: $(basename "$VIRTUAL_ENV")"
  else
    echo "⚪ No active environment"
  fi
  
  if [[ -d ".venv" ]]; then
    local size=$(du -sh .venv 2>/dev/null | cut -f1)
    echo "🏠 Local .venv: $size"
  fi
  
  echo ""
}

# Check health of .envrc files
check_envrc_health() {
  echo "🔍 Checking .envrc files..."
  local issues=0
  
  while IFS= read -r -d '' envrc_file; do
    local dir=$(dirname "$envrc_file")
    
    # Check for local .venv
    if grep -q "source ./.venv/bin/activate" "$envrc_file" 2>/dev/null; then
      if [[ -d "$dir/.venv" ]]; then
        echo "✅ $dir/.envrc → local .venv"
      else
        echo "❌ $dir/.envrc → local .venv (missing)"
        ((issues++))
      fi
      continue
    fi
    
    # Check for centralized env
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

# Show Python/uv/direnv info
show_python_info() {
  echo ""
  echo "🐍 Python Environment Info"
  echo "=========================="
  echo "System Python: $(python --version 2>/dev/null || echo "Not found")"
  echo "System Pip: $(pip --version 2>/dev/null | cut -d' ' -f2 || echo "Not found")"
  echo "uv: $(uv --version 2>/dev/null || echo "Not found")"
  echo "Direnv: $(direnv version 2>/dev/null || echo "Not found")"
  
  if [[ -n "$VIRTUAL_ENV" ]]; then
    echo ""
    echo "Active Environment:"
    echo "   Name: $(basename "$VIRTUAL_ENV")"
    echo "   Python: $("$VIRTUAL_ENV/bin/python" --version)"
    echo "   Packages: $(uv pip list 2>/dev/null | wc -l)"
    echo "   Location: $VIRTUAL_ENV"
  else
    echo ""
    echo "⚪ No active virtual environment"
  fi
  echo ""
}

# =============================================================================
# ALIASES
# =============================================================================

alias project-info='show_project_info'
alias check-envrc='check_envrc_health'
alias python-info='show_python_info'

alias vh='cat << "EOF"
🐍 Direnv + uv Virtual Environment Manager
==========================================

SIGNATURE:
  vc [name] [template] [version]

CORE COMMANDS:
  vc                               - Prompts for name
  vc myproject                     - Quick create (defaults)
  vc myproject ds                  - With template
  vc myproject ds 3.12             - Full control
  vc ds                            - Prompts for name, template=ds
  vc ds 3.14                       - Prompts for name, ds + Python 3.14
  vc local                         - Create local .venv
  vc local ds                      - Local .venv with template
  
  va [name]                        - Activate (interactive with fzf)
  va local                         - Activate local .venv
  vp                               - Auto-setup project environment
  vd                               - Deactivate
  vl                               - List centralized environments
  vinfo                            - Show active environment info
  vr <name>                        - Delete environment (shows size)
  vs                               - Sync from requirements.txt
  vf                               - Remove .envrc

UTILITIES:
  project-info                     - Show project status
  check-envrc                      - Health check .envrc files
  python-info                      - Show Python/uv/direnv info

TEMPLATES:
  basic - requests, black, flake8, pytest, pylint, mypy
  ds    - Data science (pandas, jupyter, numpy, matplotlib, etc)
  de    - Data engineering (polars, duckdb, sqlalchemy, etc)
  ml    - Machine learning (scikit-learn, plotly, etc)
  none  - Empty (installs from requirements.txt if present)

PYTHON VERSIONS:
  3.9, 3.10, 3.11, 3.12, 3.13 (default), 3.14+ (regex matched)

LOCATIONS:
  Centralized: ~/.central_venvs/
  Local: ./.venv

WORKFLOW:
  cd ~/projects/myapp
  vc myapp ds              # Creates centralized + .envrc
  # direnv auto-activates!
  uv pip install pandas    # Fast installs with uv
EOF'