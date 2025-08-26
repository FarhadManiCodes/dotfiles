#!/bin/zsh
# ~/dotfiles/zsh/productivity/completions.sh
# Custom completions for data engineering workflow (corrected for actual setup)

# ============================================================================
# VIRTUAL ENVIRONMENT COMPLETIONS (virtualenv.sh integration)
# ============================================================================

# Helper to get environment names from central location
_get_venv_names() {
  local central_venvs="${CENTRAL_VENVS:-$HOME/.central_venvs}"
  local -a envs

  if [[ -d "$central_venvs" ]]; then
    for env_dir in "$central_venvs"/*; do
      [[ -d "$env_dir" ]] && envs+=("$(basename "$env_dir"):venv ($(du -sh "$env_dir" 2>/dev/null | cut -f1 || echo "?"))")
    done
  fi

  printf '%s\n' "${envs[@]}"
}

# Completion for va (activate environment)
_va_completion() {
  local -a envs
  while IFS= read -r line; do
    [[ -n "$line" ]] && envs+=("$line")
  done < <(_get_venv_names)

  # Add current project suggestion
  local project_name=$(get_project_name)
  envs+=("$project_name:suggested for current project")

  _describe 'virtual environments' envs
}

# Completion for vc (create environment)
_vc_completion() {
  if [[ $CURRENT -eq 2 ]]; then
    # Environment name suggestions
    local -a suggestions
    suggestions+=("local:Create local .venv environment")

    # Smart project name suggestion
    local project_name=$(get_project_name)
    local current_dir=$(basename "$PWD")

    if [[ "$project_name" != "$current_dir" ]]; then
      suggestions+=("$project_name:Smart project name")
      suggestions+=("$current_dir:Current directory name")
    else
      suggestions+=("$project_name:Project name")
    fi

    # Add git repo name if different from project name
    if is_project_type "git"; then
      local git_name=""
      local remote_url=$(git remote get-url origin 2>/dev/null)
      if [[ -n "$remote_url" ]]; then
        # Extract repo name from git remote
        if [[ "$remote_url" =~ github\.com[:/]([^/]+)/([^/\.]+) ]]; then
          git_name="${match[2]}"
        elif [[ "$remote_url" =~ gitlab\.com[:/]([^/]+)/([^/\.]+) ]]; then
          git_name="${match[2]}"
        elif [[ "$remote_url" =~ bitbucket\.org[:/]([^/]+)/([^/\.]+) ]]; then
          git_name="${match[2]}"
        else
          git_name=$(basename "$remote_url" .git 2>/dev/null)
        fi
      else
        # Fallback to git root directory name
        local git_root=$(git rev-parse --show-toplevel 2>/dev/null)
        [[ -n "$git_root" ]] && git_name=$(basename "$git_root")
      fi

      # Only add if different from project name and current dir
      if [[ -n "$git_name" && "$git_name" != "$project_name" && "$git_name" != "$current_dir" ]]; then
        suggestions+=("$git_name:Git repository name")
      fi
    fi

    _describe 'environment name' suggestions

  elif [[ $CURRENT -eq 3 ]]; then
    # Template type (same as before)
    local -a templates
    templates=(
      'basic:Basic development packages (requests, black, flake8, pytest, pylint, mypy)'
      'ds:Data Science stack (ipython, jupyter, pandas, numpy, scipy, matplotlib, seaborn, scikit-learn, plotly)'
      'de:Data Engineering stack (ipython, jupyter, pandas, polars, duckdb, sqlalchemy, great-expectations, requests, pyarrow)'
      'ml:Machine Learning stack (ipython, jupyter, pandas, numpy, matplotlib, seaborn, scikit-learn, plotly)'
      'none:No template, install from requirements.txt only'
    )
    _describe 'templates' templates
  fi
}

# Completion for vr (remove environment)
_vr_completion() {
  local -a envs
  while IFS= read -r line; do
    [[ -n "$line" ]] && envs+=("$line")
  done < <(_get_venv_names)

  _describe 'environments to remove' envs
}

# Register the completions
compdef _va_completion va
compdef _vc_completion vc
compdef _vr_completion vr

# ============================================================================
# JUPYTER COMPLETIONS (jupyter-smart integration)
# ============================================================================

_jupyter_smart_completion() {
  if [[ $CURRENT -eq 2 ]]; then
    # Port number or command
    local -a commands
    commands=(
      'ls:List all running instances'
      'list:List all running instances'
      'status:Check status of default port (8888)'
      'stop:Stop instance on default port'
      'restart:Restart instance on default port'
      'force:Force start on default port'
      'force-start:Force start on default port'
      'url:Get URL for default port'
      'logs:Show logs for default port'
      '8888:Default Jupyter port'
      '8889:Alternative port (common for conflicts)'
      '8890:Alternative port'
      '8891:Alternative port'
      '8892:Alternative port'
      '9000:Alternative port'
    )

    # Add currently running instances
    if [[ -d "/tmp" ]]; then
      for pidfile in /tmp/jupyter-lab-$USER-*.pid; do
        if [[ -f "$pidfile" ]]; then
          local port=$(basename "$pidfile" | sed "s/jupyter-lab-$USER-\([0-9]*\)\.pid/\1/")
          if [[ -n "$port" ]]; then
            commands+=("$port:running instance")
          fi
        fi
      done
    fi

    _describe 'commands or ports' commands
  elif [[ $CURRENT -eq 3 ]]; then
    # Command for specific port
    local -a commands
    commands=(
      'start:Start Jupyter on this port (safe, warns if running)'
      'stop:Stop Jupyter on this port'
      'restart:Restart Jupyter on this port'
      'force:Force start on this port'
      'force-start:Force start on this port'
      'status:Check status of this port'
      'url:Get URL for this port'
      'logs:Show logs for this port'
    )
    _describe 'commands' commands
  fi
}

# ============================================================================
# TMUX COMPLETIONS (tmux scripts integration)
# ============================================================================

_tmux_session_completion() {
  local -a sessions

  # Get current tmux sessions
  if command -v tmux >/dev/null && tmux list-sessions >/dev/null 2>&1; then
    while IFS= read -r line; do
      local session_name=$(echo "$line" | cut -d: -f1)
      local session_info=$(echo "$line" | cut -d: -f2-)
      sessions+=("$session_name:$session_info")
    done < <(tmux list-sessions 2>/dev/null)
  fi

  _describe 'tmux sessions' sessions
}

# Enhanced completion for tmux-save-named-session
_tmux_save_named_completion() {
  if [[ $CURRENT -eq 2 ]]; then
    local -a suggestions

    # Current tmux session name (if in tmux and renaming)
    if [[ -n "$TMUX" ]]; then
      local current_session=$(tmux display-message -p '#S' 2>/dev/null)
      if [[ -n "$current_session" ]]; then
        suggestions+=("$current_session:Current tmux session")
      fi
    fi

    # Smart project name suggestion
    local project_name=$(get_project_name)
    local current_dir=$(basename "$PWD")

    # Only add if different from current session
    if [[ -z "$current_session" || "$project_name" != "$current_session" ]]; then
      suggestions+=("$project_name:Smart project name")
    fi

    # Current directory name (if different from project name and session)
    if [[ "$current_dir" != "$project_name" && "$current_dir" != "$current_session" ]]; then
      suggestions+=("$current_dir:Current directory name")
    fi

    # Add git repo name if different from all above
    if is_project_type "git"; then
      local git_name=""
      local remote_url=$(git remote get-url origin 2>/dev/null)
      if [[ -n "$remote_url" ]]; then
        # Extract repo name from git remote
        if [[ "$remote_url" =~ github\.com[:/]([^/]+)/([^/\.]+) ]]; then
          git_name="${match[2]}"
        elif [[ "$remote_url" =~ gitlab\.com[:/]([^/]+)/([^/\.]+) ]]; then
          git_name="${match[2]}"
        elif [[ "$remote_url" =~ bitbucket\.org[:/]([^/]+)/([^/\.]+) ]]; then
          git_name="${match[2]}"
        else
          git_name=$(basename "$remote_url" .git 2>/dev/null)
        fi
      else
        # Fallback to git root directory name
        local git_root=$(git rev-parse --show-toplevel 2>/dev/null)
        [[ -n "$git_root" ]] && git_name=$(basename "$git_root")
      fi

      # Only add if different from all previous suggestions
      if [[ -n "$git_name" && "$git_name" != "$project_name" && "$git_name" != "$current_dir" && "$git_name" != "$current_session" ]]; then
        suggestions+=("$git_name:Git repository name")
      fi
    fi

    _describe 'session name' suggestions
  fi
}

# Register the completion
compdef _tmux_save_named_enhanced_completion tmux-save-named-session

_tmux_layout_completion() {
  local -a layouts
  local layout_dir="$HOME/.config/tmux/layouts"

  if [[ -d "$layout_dir" ]]; then
    for layout in "$layout_dir"/*.sh; do
      if [[ -f "$layout" ]]; then
        local name=$(basename "$layout" .sh)
        case "$name" in
          etl_layout) layouts+=("etl:ETL Development - 6 windows (dev, git, explore, db, monitor, test)") ;;
          analysis_layout) layouts+=("analysis:Data Analysis - 4 windows for exploratory data analysis") ;;
          *) layouts+=("$(basename "$layout" .sh):Custom layout") ;;
        esac
      fi
    done
  fi

  _describe 'tmux layouts' layouts
}

# ============================================================================
# FZF ENHANCED FUNCTIONS (fzf-enhancements.sh integration)
# ============================================================================

# Completion for fnb (find notebooks)
_fnb_completion() {
  local -a notebooks
  if command -v fd >/dev/null; then
    notebooks=($(fd -e ipynb --type f 2>/dev/null | head -20))
  else
    notebooks=($(find . -name "*.ipynb" -type f 2>/dev/null | head -20))
  fi

  # Add useful info about notebooks
  local -a enhanced_notebooks
  for notebook in $notebooks; do
    if [[ -f "$notebook" ]]; then
      local size=$(ls -lh "$notebook" 2>/dev/null | awk '{print $5}' || echo "unknown")
      enhanced_notebooks+=("$notebook:$size")
    fi
  done

  _describe 'jupyter notebooks' enhanced_notebooks
}

# Completion for fdata (find data files)
_fdata_completion() {
  local -a data_files
  if command -v fd >/dev/null; then
    data_files=($(fd -e csv -e tsv -e jsonl -e ndjson -e json -e yaml -e yml -e parquet -e avro -e orc -e feather -e xlsx -e xls -e pkl -e pickle -e joblib -e h5 -e hdf5 -e pt -e pth -e onnx --type f 2>/dev/null | head -20))
  else
    data_files=($(find . \( -name "*.csv" -o -name "*.json" -o -name "*.parquet" -o -name "*.pkl" -o -name "*.h5" \) -type f 2>/dev/null | head -20))
  fi

  # Add file size info
  local -a enhanced_files
  for file in $data_files; do
    if [[ -f "$file" ]]; then
      local size=$(ls -lh "$file" 2>/dev/null | awk '{print $5}' || echo "unknown")
      enhanced_files+=("$file:$size")
    fi
  done

  _describe 'data files' enhanced_files
}

# Completion for fgit (find git repositories)
_fgit_completion() {
  local -a git_repos
  if command -v fd >/dev/null; then
    git_repos=($(fd --type d --hidden -g ".git" --max-depth 3 2>/dev/null | sed 's|/.git$||' | head -20))
  else
    git_repos=($(find . -type d -name ".git" -maxdepth 3 2>/dev/null | sed 's|/.git$||' | head -20))
  fi

  # Add branch info
  local -a enhanced_repos
  for repo in $git_repos; do
    if [[ -d "$repo/.git" ]]; then
      local branch=$(cd "$repo" && git branch --show-current 2>/dev/null || echo "unknown")
      enhanced_repos+=("$repo:on $branch")
    fi
  done

  _describe 'git repositories' enhanced_repos
}

# Completion for ff (find files)
_ff_completion() {
  local -a files
  if command -v fd >/dev/null; then
    files=($(fd --type f -e py -e ipynb -e sql -e csv -e json -e yaml -e yml -e md -e sh -e toml -e txt -e js -e go -e rs -e c -e cpp -e scala -e log -e env -e ini -e conf -e cfg -e dockerfile -e properties -e gitignore -e dockerignore -e lock -e makefile 2>/dev/null | head -20))
  else
    files=($(find . \( -name "*.py" -o -name "*.sql" -o -name "*.json" -o -name "*.yaml" -o -name "*.md" \) -type f 2>/dev/null | head -20))
  fi
  _describe 'development files' files
}

# ============================================================================
# GIT ENHANCEMENTS COMPLETIONS (git-enhancements.sh integration)
# ============================================================================

# Completion for gci (interactive commit) - no args needed, but we can suggest commit types
_gci_completion() {
  if [[ $CURRENT -eq 2 ]]; then
    local -a commit_types
    commit_types=(
      'data:Data ingestion, cleaning, transformation, validation'
      'pipeline:ETL/ELT pipelines, workflows, orchestration'
      'model:Model training, architecture, hyperparameters, inference'
      'experiment:ML experiments, A/B tests, model comparisons'
      'deploy:Deployment, infrastructure, K8s, Docker, CI/CD'
      'config:Configuration, environment variables, settings'
      'monitor:Monitoring, logging, alerts, observability'
      'feat:New feature or functionality'
      'fix:Bug fix or error resolution'
      'perf:Performance optimization, speed improvements'
      'test:Testing, validation, quality checks'
      'analysis:Data analysis, EDA, insights, investigations'
      'viz:Visualizations, dashboards, plots, reports'
      'refactor:Code restructuring, cleanup, organization'
      'docs:Documentation, README, comments, guides'
      'style:Code formatting, linting, style fixes'
      'chore:Dependencies, build tools, maintenance tasks'
    )
    _describe 'commit types (for reference - gci is interactive)' commit_types
  fi
}

# ============================================================================
# CONTEXT-AWARE COMPLETIONS
# ============================================================================
smart-project() {
  if [[ $# -eq 0 ]]; then
    # No arguments - show help/available commands
    echo "🎯 Smart Project Command Center"
    echo "=============================="
    echo "Usage: smart-project <command>"
    echo ""
    echo "💡 Use TAB completion to see available commands for this project"
    echo "Example: smart-project <TAB>"
    echo ""
    echo "📁 Current project: $(get_project_name)"
    echo "🏷️  Project types:"
    is_project_type "python" && echo "  ✅ Python"
    is_project_type "data" && echo "  ✅ Data" 
    is_project_type "jupyter" && echo "  ✅ Jupyter"
    is_project_type "git" && echo "  ✅ Git"
    is_project_type "docker" && echo "  ✅ Docker"
    return
  fi
  
  # Execute the command passed as arguments
  "$@"
}

# Enhanced smart project completion - context-aware command center
_smart_project_completion() {
  local -a context_commands
  local project_name=$(get_project_name)
  
  # ==========================================================================
  # PROJECT STATUS & INFO
  # ==========================================================================
  context_commands+=("project-info:🔍 Show project: $project_name")
  
  # ==========================================================================
  # ENVIRONMENT MANAGEMENT (if Python project)
  # ==========================================================================
  if is_project_type "python"; then
    # Check current environment status
    if [[ -n "$VIRTUAL_ENV" ]]; then
      local current_env=$(basename "$VIRTUAL_ENV")
      context_commands+=("vd:🔴 Deactivate $current_env")
      context_commands+=("vs:🔄 Sync requirements.txt")
    elif [[ -n "$CONDA_DEFAULT_ENV" && "$CONDA_DEFAULT_ENV" != "base" ]]; then
      context_commands+=("vd:🔴 Deactivate $CONDA_DEFAULT_ENV")
    else
      context_commands+=("vp:🎯 Activate project environment")
      context_commands+=("va:🐍 Choose virtual environment")
      context_commands+=("vc:⚡ Create new environment")
    fi
  fi
  
  # ==========================================================================
  # JUPYTER & NOTEBOOKS (if Jupyter project)
  # ==========================================================================
  if is_project_type "jupyter"; then
    context_commands+=("jupyter-smart:📓 Start Jupyter Lab")
    context_commands+=("tmux-jupyter-auto:📊 Jupyter in tmux window")
    context_commands+=("fnb:🔍 Browse notebooks")
    
    # Check for specific notebook types
    if [[ -d "notebooks" ]]; then
      context_commands+=("fdir notebooks:📁 Browse notebooks folder")
    fi
  fi
  
  # ==========================================================================
  # DATA OPERATIONS (if data project)  
  # ==========================================================================
  if is_project_type "data"; then
    context_commands+=("fdata:📊 Browse data files")
    
    # Specific data operations based on what's present
    if [[ -d "data" ]]; then
      context_commands+=("fdir data:📁 Browse data folder")
    fi
    if [[ -f *.csv(N) ]]; then
      context_commands+=("csv-preview:📋 Preview CSV files")
    fi
    if [[ -f *.parquet(N) ]]; then
      context_commands+=("parquet-info:💾 Inspect Parquet files")
    fi
  fi
  
  # ==========================================================================
  # GIT OPERATIONS (if git project)
  # ==========================================================================
  if is_project_type "git"; then
    # Check git status and suggest accordingly
    local git_status=$(git status --porcelain 2>/dev/null)
    if [[ -n "$git_status" ]]; then
      # Uncommitted changes
      if is_project_type "data" || is_project_type "jupyter"; then
        context_commands+=("gstds:📊 Git status (data science view)")
      else
        context_commands+=("gst:📋 Git status")
      fi
      context_commands+=("gci:💬 Interactive commit")
      context_commands+=("fga:➕ Interactive add")
      context_commands+=("fgd:🔍 Interactive diff")
    else
      # Clean working directory
      context_commands+=("git-pull:📥 Pull updates")
      context_commands+=("git-branch:🌿 Manage branches")
    fi
    
    # Always available git commands
    context_commands+=("fgit:🌳 Browse repositories")
    if command -v lazygit >/dev/null; then
      context_commands+=("lazygit:🚀 Full git interface")
    fi
  fi
  
  # ==========================================================================
  # PROJECT-SPECIFIC WORKFLOWS
  # ==========================================================================
  
  # Data Science workflows
  if is_project_type "jupyter" && is_project_type "data"; then
    context_commands+=("analysis-layout:📊 Data analysis tmux layout")
    if [[ -f "requirements.txt" ]]; then
      context_commands+=("profile-env:📈 Profile current environment")
    fi
  fi
  
  # Data Engineering workflows  
  if is_project_type "python" && is_project_type "data" && ! is_project_type "jupyter"; then
    context_commands+=("etl-layout:🔧 ETL development tmux layout")
    if [[ -f "dvc.yaml" ]] || [[ -f ".dvc" ]]; then
      context_commands+=("dvc-status:📦 DVC pipeline status")
    fi
  fi
  
  # Docker workflows
  if is_project_type "docker"; then
    if [[ -f "docker-compose.yml" ]] || [[ -f "docker-compose.yaml" ]]; then
      context_commands+=("docker-up:🐳 Start containers")
      context_commands+=("docker-logs:📜 View container logs")
    fi
    if [[ -f "Dockerfile" ]]; then
      context_commands+=("docker-build:🔨 Build container")
    fi
  fi
  
  # ==========================================================================
  # DEVELOPMENT TOOLS (always available)
  # ==========================================================================
  context_commands+=("ff:📄 Find files")
  context_commands+=("fdir:📁 Browse directories")
  context_commands+=("frg:🔍 Live grep search")
  
  # ==========================================================================
  # SESSION MANAGEMENT
  # ==========================================================================
  if [[ -n "$TMUX" ]]; then
    local current_session=$(tmux display-message -p '#S' 2>/dev/null)
    context_commands+=("tmux-save:💾 Save session as $project_name")
  else
    context_commands+=("tmux-new:📺 Create tmux session")
  fi
  
  # ==========================================================================
  # SYSTEM & MONITORING (if complex project)
  # ==========================================================================
  if is_project_type "docker" || is_project_type "data"; then
    context_commands+=("fproc:⚙️ Browse processes")
    if [[ -n "$VIRTUAL_ENV" ]] || [[ -n "$CONDA_DEFAULT_ENV" ]]; then
      context_commands+=("show-python-info:🐍 Python environment info")
    fi
  fi
  
  # Describe commands with project context
  local description="commands for $project_name"
  _describe "$description" context_commands
}

# Helper functions for the commands suggested above
csv-preview() {
  if command -v bat >/dev/null; then
    find . -name "*.csv" -type f | head -5 | while read file; do
      echo "📊 $file"
      head -10 "$file" | bat --language csv
      echo ""
    done
  else
    find . -name "*.csv" -type f | head -5 | while read file; do
      echo "📊 $file"
      head -10 "$file"
      echo ""
    done
  fi
}

parquet-info() {
  find . -name "*.parquet" -type f | head -5 | while read file; do
    echo "💾 $file"
    ls -lh "$file"
    echo ""
  done
}

profile-env() {
  echo "🐍 Python Environment Profile"
  echo "============================="
  python --version
  pip --version
  echo ""
  echo "📦 Installed packages: $(pip list | wc -l)"
  echo "📊 Environment: ${VIRTUAL_ENV:-${CONDA_DEFAULT_ENV:-system}}"
  if [[ -f "requirements.txt" ]]; then
    echo "📋 Requirements file: $(wc -l < requirements.txt) packages"
  fi
}

# ============================================================================
# REGISTER COMPLETIONS
# ============================================================================

# Virtual environment management (virtualenv.sh)
compdef _va_completion va
compdef _vc_completion vc
compdef _vr_completion vr

# Jupyter tools (jupyter-smart)
compdef _jupyter_smart_completion jupyter-smart

# Tmux session management scripts
compdef _tmux_session_completion tmux-session-restorer
compdef _tmux_save_named_completion tmux-save-named-session
compdef _tmux_layout_completion tmux-layout

# FZF enhanced functions (fzf-enhancements.sh)
compdef _fnb_completion fnb
compdef _fdata_completion fdata
compdef _fgit_completion fgit
compdef _ff_completion ff

# Git enhancements (git-enhancements.sh)
compdef _gci_completion gci

# Context-aware completions for common tools
compdef _smart_project_completion smart_project

# ============================================================================
# COMPLETION ENHANCEMENTS FOR EXISTING TOOLS
# ============================================================================

# Enhanced completion for your custom aliases
compdef _tmux_session_completion tmux-new
compdef _jupyter_smart_completion js # If you alias jupyter-smart to js

# Python environment aware completions for tools that should check env status
_python_env_completion() {
  if [[ -n "$VIRTUAL_ENV" ]] || [[ -n "$CONDA_DEFAULT_ENV" ]]; then
    local -a python_commands
    python_commands=(
      'python:Python interpreter'
      'pip:Package installer'
      'pytest:Run tests'
      'black:Format code'
      'flake8:Lint code'
      'ipython:Enhanced REPL'
      'ptpython:Even better REPL'
    )
    _describe 'python tools' python_commands
  else
    _describe 'activate environment first' 'va:Activate virtual environment' 'vp:Project environment'
  fi
}

# Completion function for tmux-new-quick
_tmux_layout_completion() {
  local -a layouts
  layouts=(
    'basic:Simple single window setup'
    'ml_training:Model development & monitoring'
    'etl:ETL/Data Engineering pipeline'
    'analysis:Data Science with Jupyter'
    'database:SQL development & querying'
    'developer:Python general development'
    'docker:Container development'
    'git:Version control focused'
  )
  
  _describe 'tmux layouts' layouts
}

# Register completion for the new functions
compdef _tmux_layout_completion tmux-new-quick
compdef _tmux_layout_completion tmux-dev
compdef _tmux_layout_completion tmux-data
compdef _tmux_layout_completion tmux-ml
compdef _tmux_layout_completion tmux-db
compdef _tmux_layout_completion tmux-git
compdef _tmux_layout_completion tmux-docker
