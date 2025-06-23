#!/bin/zsh
# =============================================================================
# Direnv-based Virtual Environment Management for Data Engineering/MLOps
# Much simpler than the old approach - direnv handles the heavy lifting!
# =============================================================================

# Configuration
export CENTRAL_VENVS="$HOME/.central_venvs"

# Ensure central venvs directory exists
[[ ! -d "$CENTRAL_VENVS" ]] && mkdir -p "$CENTRAL_VENVS"

# =============================================================================
# CORE FUNCTIONS - Simplified with direnv
# =============================================================================

# Create virtual environment and .envrc
vc() {
  local name="$1"
  local template="$2"
  
  if [[ -z "$name" ]]; then
    echo "Usage: vc <env_name> [template]"
    echo "   or: vc local [template]  # creates env named after current directory"
    echo "Templates: basic, ds (data-science), de (data-engineering), ml, none"
    return 1
  fi
  
  # Handle "local" - use directory name
  if [[ "$name" == "local" ]]; then
    name=$(basename "$PWD")
    template="$2"
  fi
  
  local venv_path="$CENTRAL_VENVS/$name"
  
  # Check if environment already exists
  if [[ -d "$venv_path" ]]; then
    echo "⚠️  Environment '$name' already exists at $venv_path"
    echo "🔄 Setting up .envrc to use existing environment..."
    _create_envrc "$name"
    return 0
  fi
  
  echo "🐍 Creating virtual environment: $name"
  echo "📁 Location: $venv_path"
  
  # Create the virtual environment
  if ! python3 -m venv "$venv_path"; then
    echo "❌ Failed to create virtual environment"
    return 1
  fi
  
  # Create .envrc file
  _create_envrc "$name"
  
  # Activate temporarily to install packages
  source "$venv_path/bin/activate"
  
  # Install template packages
  _install_template "$template"
  
  echo "✅ Environment '$name' created!"
  echo "🔄 direnv will activate it automatically when you cd here"
  echo "💡 Add '.envrc' to .gitignore if you don't want to version it"
}

# Activate environment with smart .envrc handling
va() {
  # Interactive selection if no argument
  if [[ $# -eq 0 ]]; then
    if ! command -v fzf >/dev/null; then
      echo "📋 Available environments:"
      _list_environments
      echo "💡 Usage: va <env_name>"
      return 0
    fi
    
    local selected=$(_list_environments | fzf --prompt="🐍 Select environment: " --height=40%)
    [[ -z "$selected" ]] && return 0
    
    # Extract name from the formatted output
    selected=$(echo "$selected" | awk '{print $2}')
  else
    local selected="$1"
  fi
  
  local venv_path="$CENTRAL_VENVS/$selected"
  
  if [[ ! -d "$venv_path" ]]; then
    echo "❌ Environment '$selected' not found"
    echo "💡 Available environments:"
    _list_environments
    return 1
  fi
  
  # Smart .envrc handling
  if [[ -f ".envrc" ]]; then
    # Get current environment from .envrc
    local current_env=$(grep -o 'source.*activate' .envrc 2>/dev/null | sed -n 's|.*/.central_venvs/\([^/]*\)/.*|\1|p')
    
    echo "📄 Found existing .envrc"
    if [[ -n "$current_env" ]]; then
      echo "🔗 Currently points to: $current_env"
    else
      echo "⚠️  .envrc format not recognized"
    fi
    echo "🎯 You want to use: $selected"
    echo ""
    
    if [[ "$current_env" == "$selected" ]]; then
      echo "✅ .envrc already points to the correct environment"
      direnv allow . && direnv reload
      return 0
    fi
    
    echo "Choose an option:"
    echo "  1) Override .envrc (make $selected the project default)"
    echo "  2) Session only (don't change .envrc, manual activation)"
    echo "  3) Cancel"
    echo ""
    printf "Choice [1-3]: "
    read -r choice
    
    case "$choice" in
      1)
        echo "🔄 Updating .envrc to use: $selected"
        _create_envrc "$selected"
        ;;
      2)
        echo "🔧 Manual activation for this session only"
        source "$venv_path/bin/activate"
        echo "✅ Activated: $selected (session only)"
        echo "💡 Use 'vd' to deactivate, or cd elsewhere to return to direnv environment"
        ;;
      *)
        echo "❌ Cancelled"
        return 0
        ;;
    esac
  else
    # No .envrc exists - create it automatically
    echo "📄 No .envrc found in current directory"
    echo "🎯 Creating .envrc for environment: $selected"
    _create_envrc "$selected"
    echo "✅ Environment will activate automatically with direnv"
  fi
}

# Project environment - use or create .envrc based on project name
vp() {
  # Check if we already have .envrc
  if [[ -f ".envrc" ]]; then
    echo "📋 Found existing .envrc"
    local current_env=$(grep -o 'source.*activate' .envrc 2>/dev/null | sed -n 's|.*/.central_venvs/\([^/]*\)/.*|\1|p')
    
    if [[ -n "$current_env" ]]; then
      echo "🔗 Currently configured for: $current_env"
      if [[ -d "$CENTRAL_VENVS/$current_env" ]]; then
        echo "✅ Environment exists - reloading direnv"
        direnv allow . && direnv reload
      else
        echo "❌ Environment '$current_env' not found!"
        echo "💡 Use 'va' to select a different environment or 'vc' to create it"
      fi
    else
      echo "⚠️  .envrc format not recognized"
      echo "💡 Use 'va' to set up a proper environment"
    fi
    return 0
  fi
  
  # Detect project name
  local project_name=$(basename "$PWD")
  local venv_path="$CENTRAL_VENVS/$project_name"
  
  # Check if environment exists
  if [[ -d "$venv_path" ]]; then
    echo "🎯 Found existing environment: $project_name"
    _create_envrc "$project_name"
    echo "✅ Created .envrc for existing environment"
  else
    echo "❓ No environment found for project: $project_name"
    echo "💡 Create with: vc $project_name [template]"
    echo "💡 Or use: vc local [template] (creates env named '$project_name')"
  fi
}

# Deactivate current environment
vd() {
  if [[ -n "$VIRTUAL_ENV" ]]; then
    deactivate
    echo "✅ Environment deactivated"
  else
    echo "ℹ️  No active virtual environment"
  fi
}

# Remove .envrc (forget project association)
vf() {
  if [[ -f ".envrc" ]]; then
    rm ".envrc"
    echo "🗑️  Removed .envrc"
    echo "🔄 Run 'direnv reload' or cd elsewhere to deactivate"
  else
    echo "ℹ️  No .envrc found in current directory"
  fi
}

# Remove virtual environment completely
vr() {
  local env_name="$1"
  
  if [[ -z "$env_name" ]]; then
    echo "Usage: vr <environment_name>"
    echo "💡 Available environments:"
    _list_environments
    return 1
  fi
  
  local venv_path="$CENTRAL_VENVS/$env_name"
  
  if [[ ! -d "$venv_path" ]]; then
    echo "❌ Environment '$env_name' not found"
    return 1
  fi
  
  echo "🗑️  Remove virtual environment: $env_name"
  echo "📁 Location: $venv_path"
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
    
    rm -rf "$venv_path"
    echo "✅ Environment '$env_name' removed"
    echo "💡 Any .envrc files referencing it will need manual cleanup"
  else
    echo "❌ Cancelled"
  fi
}

# Sync requirements.txt
vs() {
  if [[ -z "$VIRTUAL_ENV" ]]; then
    echo "❌ No active virtual environment"
    echo "💡 Activate an environment first (cd to direnv directory or use 'va')"
    return 1
  fi
  
  if [[ -f "requirements.txt" ]]; then
    echo "📦 Installing from requirements.txt..."
    pip install -r requirements.txt
  else
    echo "❌ No requirements.txt found"
  fi
}

# List environments
vl() {
  echo "🐍 Virtual Environments"
  echo "======================="
  echo ""
  
  # Show current environment
  if [[ -n "$VIRTUAL_ENV" ]]; then
    local current=$(basename "$VIRTUAL_ENV")
    echo "🟢 Currently active: $current"
    if [[ -f ".envrc" ]]; then
      echo "   📄 Managed by direnv (.envrc present)"
    else
      echo "   🔧 Manually activated"
    fi
  else
    echo "⚪ No environment active"
  fi
  echo ""
  
  # List all environments
  echo "📁 Central environments ($CENTRAL_VENVS):"
  _list_environments
  
  # Show current directory status
  echo ""
  echo "📂 Current directory: $(basename "$PWD")"
  if [[ -f ".envrc" ]]; then
    echo "   📄 .envrc present"
    local env_name=$(grep -o 'source.*activate' .envrc 2>/dev/null | sed -n 's|.*/.central_venvs/\([^/]*\)/.*|\1|p')
    [[ -n "$env_name" ]] && echo "   🔗 Points to: $env_name"
  else
    echo "   ❌ No .envrc (not direnv-managed)"
  fi
}

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

# Create .envrc file
_create_envrc() {
  local env_name="$1"
  local venv_path="$CENTRAL_VENVS/$env_name"
  
  cat > .envrc << EOF
# Auto-generated by vc - Virtual Environment: $env_name
source $venv_path/bin/activate
EOF
  
  direnv allow .
  echo "📄 Created .envrc pointing to: $env_name"
}

# List environments in a consistent format
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
  
  # Upgrade pip first
  pip install --upgrade pip setuptools wheel
  
  case "$template" in
    ""|"none")
      # Try to install from requirements.txt if present
      if [[ -f "requirements.txt" ]]; then
        echo "📦 Installing from requirements.txt..."
        pip install -r requirements.txt
      else
        echo "📝 Empty environment created (no template, no requirements.txt)"
      fi
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
      pip install ipython jupyter pandas polars duckdb sqlalchemy great-expectations requests pyarrow \
        black flake8 pylint mypy
      ;;
    "ml"|"machine-learning")
      echo "🤖 Installing ML packages..."
      pip install ipython jupyter pandas numpy matplotlib seaborn scikit-learn plotly \
        black flake8 pylint mypy
      echo "💡 Add deep learning later: pip install torch OR pip install tensorflow"
      ;;
    *)
      echo "❌ Unknown template: $template"
      echo "Available templates: basic, ds, de, ml, none"
      return 1
      ;;
  esac
}

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

# Show current project info
show_project_info() {
  echo "🔍 Project Environment Status"
  echo "============================="
  echo "📁 Directory: $PWD"
  echo "📋 Project: $(basename "$PWD")"
  
  if [[ -f ".envrc" ]]; then
    echo "📄 .envrc: Present"
    local env_name=$(grep -o 'source.*activate' .envrc 2>/dev/null | sed -n 's|.*/.central_venvs/\([^/]*\)/.*|\1|p')
    if [[ -n "$env_name" ]]; then
      echo "🔗 Environment: $env_name"
      local venv_path="$CENTRAL_VENVS/$env_name"
      if [[ -d "$venv_path" ]]; then
        echo "✅ Environment exists"
      else
        echo "❌ Environment missing!"
      fi
    fi
    echo "🔄 Direnv status: $(direnv status)"
  else
    echo "📄 .envrc: Not found"
    echo "💡 Use 'vp' to set up project environment"
  fi
  
  if [[ -n "$VIRTUAL_ENV" ]]; then
    echo "🟢 Active: $(basename "$VIRTUAL_ENV")"
  else
    echo "⚪ No active environment"
  fi
}

# Find orphaned .envrc files (point to non-existent environments)
check_envrc_health() {
  echo "🔍 Checking .envrc files for broken references..."
  local found_issues=0
  
  # Search for .envrc files in current directory and subdirectories
  while IFS= read -r -d '' envrc_file; do
    local dir=$(dirname "$envrc_file")
    local env_name=$(grep -o 'source.*activate' "$envrc_file" 2>/dev/null | sed -n 's|.*/.central_venvs/\([^/]*\)/.*|\1|p')
    
    if [[ -n "$env_name" ]]; then
      local venv_path="$CENTRAL_VENVS/$env_name"
      if [[ ! -d "$venv_path" ]]; then
        echo "❌ $dir/.envrc → $env_name (missing)"
        ((found_issues++))
      else
        echo "✅ $dir/.envrc → $env_name (ok)"
      fi
    else
      echo "⚠️  $dir/.envrc (unrecognized format)"
      ((found_issues++))
    fi
  done < <(find . -name ".envrc" -type f -print0 2>/dev/null)
  
  if [[ $found_issues -eq 0 ]]; then
    echo "✅ All .envrc files are healthy"
  else
    echo "⚠️  Found $found_issues issue(s)"
  fi
}

# =============================================================================
# ALIASES AND HELP
# =============================================================================

alias project-info='show_project_info'
alias check-envrc='check_envrc_health'

# Help function
venv_help() {
  echo "🐍 Direnv-based Virtual Environment Quick Reference"
  echo "=================================================="
  echo "vc <name> [template]  - Create environment + .envrc"
  echo "vc local [template]   - Create env named after current dir"
  echo "va [env]             - Activate environment (or reload direnv)"
  echo "vp                   - Set up project environment"
  echo "vd                   - Deactivate current environment"
  echo "vf                   - Remove .envrc (forget project)"
  echo "vr <env>             - Remove environment completely"
  echo "vs                   - Sync requirements.txt"
  echo "vl                   - List environments and status"
  echo ""
  echo "Templates: basic, ds (data-science), de (data-engineering), ml, none"
  echo ""
  echo "💡 How it works:"
  echo "   • Environments stored in: $CENTRAL_VENVS"
  echo "   • direnv automatically activates/deactivates based on .envrc"
  echo "   • .envrc files can be gitignored or versioned per project needs"
  echo ""
  echo "Utilities:"
  echo "project-info    - Show current project environment status"
  echo "check-envrc     - Find broken .envrc references"
}

alias vh='venv_help'

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
  
  if command -v direnv >/dev/null; then
    echo "  Direnv: $(direnv version)"
  else
    echo "  Direnv: Not found"
  fi
}
