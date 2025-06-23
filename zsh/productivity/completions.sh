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
  local project_name=$(basename "$PWD")
  envs+=("$project_name:suggested for current project")
  
  _describe 'virtual environments' envs
}

# Completion for vc (create environment)
_vc_completion() {
  if [[ $CURRENT -eq 2 ]]; then
    # Environment name
    local -a suggestions
    local project_name=$(basename "$PWD")
    suggestions+=("$project_name:environment for current project")
    suggestions+=("local:creates env named '$project_name'")
    _describe 'environment name' suggestions
  elif [[ $CURRENT -eq 3 ]]; then
    # Template
    local -a templates
    templates=(
      'basic:Basic development packages'
      'ds:Data Science stack (jupyter, pandas, etc.)'
      'de:Data Engineering stack (polars, duckdb, etc.)'
      'ml:Machine Learning stack'
      'none:No template, use requirements.txt'
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

_tmux_save_named_completion() {
  if [[ $CURRENT -eq 2 ]]; then
    # Suggest session name based on current context
    local -a suggestions
    
    # Current tmux session name
    if [[ -n "$TMUX" ]]; then
      local current_session=$(tmux display-message -p '#S' 2>/dev/null)
      if [[ -n "$current_session" ]]; then
        suggestions+=("$current_session:current tmux session")
      fi
    fi
    
    # Project-based name if get_project_name exists
    if type get_project_name >/dev/null 2>&1; then
      local project_info=$(get_project_name 2>/dev/null)
      local project_name="${project_info##*:}"
      if [[ -n "$project_name" ]]; then
        suggestions+=("$project_name:based on current project")
      fi
    fi
    
    # Directory-based name
    local dir_name=$(basename "$PWD")
    suggestions+=("$dir_name:based on current directory")
    
    _describe 'session name' suggestions
  fi
}

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

# Smart completion that adapts based on current directory context
_smart_project_completion() {
  local -a context_commands
  
  # Check project type and suggest relevant commands
  local has_python=false
  local has_data=false
  local has_git=false
  local has_jupyter=false
  
  [[ -f "requirements.txt" || -f "pyproject.toml" || -f "setup.py" ]] && has_python=true
  [[ -d "data" || -f *.csv(N) || -f *.parquet(N) || -f *.json(N) ]] && has_data=true
  [[ -d ".git" ]] && has_git=true
  [[ -d "notebooks" || -f *.ipynb(N) ]] && has_jupyter=true
  
  if $has_python; then
    context_commands+=(
      'va:Activate virtual environment'
      'vp:Project virtual environment'
      'vc:Create virtual environment'
    )
  fi
  
  if $has_jupyter; then
    context_commands+=(
      'jupyter-smart:Start Jupyter Lab'
      'tmux-jupyter-auto:Jupyter in tmux'
      'fnb:Browse notebooks'
    )
  fi
  
  if $has_data; then
    context_commands+=(
      'fdata:Browse data files'
    )
  fi
  
  if $has_git; then
    context_commands+=(
      'fgit:Browse git repositories'
      'gstds:Git status (data science view)'
      'gci:Interactive commit'
    )
  fi
  
  # Always available
  context_commands+=(
    'tmux-new:Create new tmux session'
    'ff:Find files'
  )
  
  _describe 'project commands' context_commands
}

# ============================================================================
# REGISTER COMPLETIONS
# ============================================================================

# Virtual environment management (virtualenv.sh)
compdef _va_completion va
compdef _vc_completion vc
compdef _vr_completion vr
compdef _vf_completion vf

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
compdef _smart_project_completion project-commands

# ============================================================================
# COMPLETION ENHANCEMENTS FOR EXISTING TOOLS
# ============================================================================

# Enhanced completion for your custom aliases
compdef _tmux_session_completion tmux-new
compdef _jupyter_smart_completion js  # If you alias jupyter-smart to js

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

