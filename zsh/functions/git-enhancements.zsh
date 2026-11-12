# Enhanced Git Shell Integration for Data Science
# ~/dotfiles/zsh/functions/git-enhancements.zsh

# ============================================================================
# INTERACTIVE COMMIT WITH DATA SCIENCE TYPES
# ============================================================================

gci() {
  # Define commit types with descriptions (optimized for data engineering/MLOps)
  local types=(
    # Most common for data engineering
    "data:Data ingestion, cleaning, transformation, validation"
    "pipeline:ETL/ELT pipelines, workflows, orchestration"
    "model:Model training, architecture, hyperparameters, inference"
    "experiment:ML experiments, A/B tests, model comparisons"

    # Infrastructure & deployment
    "deploy:Deployment, infrastructure, K8s, Docker, CI/CD"
    "config:Configuration, environment variables, settings"
    "monitor:Monitoring, logging, alerts, observability"

    # Development essentials
    "feat:New feature or functionality"
    "fix:Bug fix or error resolution"
    "perf:Performance optimization, speed improvements"
    "test:Testing, validation, quality checks"

    # Analysis & visualization
    "analysis:Data analysis, EDA, insights, investigations"
    "viz:Visualizations, dashboards, plots, reports"

    # Code quality
    "refactor:Code restructuring, cleanup, organization"
    "docs:Documentation, README, comments, guides"
    "style:Code formatting, linting, style fixes"
    "chore:Dependencies, build tools, maintenance tasks"
  )

  # Use fzf to select commit type
  local selected_type=$(printf '%s\n' "${types[@]}" | fzf --prompt="Select commit type: " --height=50% | cut -d: -f1)

  if [[ -z "$selected_type" ]]; then
    echo "❌ Commit cancelled"
    return 1
  fi

  # Prompt for optional scope
  echo -n "📝 Optional scope (component/dataset/module): "
  read -r scope

  # Prompt for description
  echo -n "📝 Commit message: "
  read -r message

  if [[ -z "$message" ]]; then
    echo "❌ Commit message required"
    return 1
  fi

  # Format the commit message
  local commit_msg
  if [[ -n "$scope" ]]; then
    commit_msg="${selected_type}(${scope}): ${message}"
  else
    commit_msg="${selected_type}: ${message}"
  fi

  # Show the formatted message and confirm
  echo ""
  echo "🔍 Commit message:"
  echo "   $commit_msg"
  echo ""
  echo -n "✅ Commit with this message? [Y/n]: "
  read -r confirm

  if [[ $confirm =~ ^[Nn]$ ]]; then
    echo "❌ Commit cancelled"
    return 1
  fi

  git commit -m "$commit_msg"
}

# ============================================================================
# ENHANCED GIT STATUS FUNCTIONS
# ============================================================================

# git status without the hint lines or the branch lines: the branch, its
# upstream and whether it is level with it. Starship shows the branch and the
# ahead/behind counts, not the upstream; "the upstream is gone" stays. On a
# terminal, colors and columns are forced on with its width passed in, because
# git cannot see it through the pipe. --no-ahead-behind leaves a single "Your
# branch" line. git prints these lines uncolored unless color.status.header is
# set. pipefail returns git's failure, not awk's.
gst() {
  setopt local_options pipefail
  local -a tty=()
  [[ -t 1 ]] && tty=(-c color.status=always -c column.status=always)
  COLUMNS=$COLUMNS git -c advice.statusHints=false "${tty[@]}" \
    status --no-ahead-behind "$@" \
    | awk '
      /^(On branch |Your branch is up to date |Your branch and .* refer to different commits)/ { next }
      !seen && /^$/ { next }
      { seen = 1; print }'
}

# Custom gitignore generator (replicating the 'gi' command)
function gi() {
  curl -sLw "\n" --max-time 10 https://www.toptal.com/developers/gitignore/api/$@
}
# ============================================================================
# ALIASES - Git Workflow Shortcuts
# ============================================================================

# Git add aliases (from oh-my-zsh git plugin)
alias ga='git add'
alias gaa='git add --all'
alias gapa='git add --patch'
alias gav='git add --verbose'

# Git commit aliases (from oh-my-zsh git plugin)
alias gc='git commit --verbose'
alias gca='git commit --verbose --all'
alias gcam='git commit --all --message'
alias gcmsg='git commit --message'
alias gcf='git config --list'

# Git log aliases (from oh-my-zsh git plugin)
alias glo='git log --oneline --decorate'
alias glog='git log --oneline --decorate --graph'
alias gloga='git log --oneline --decorate --graph --all'
alias glol='git log --graph --pretty="%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ar) %C(bold blue)<%an>%Creset"'
alias glola='git log --graph --pretty="%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ar) %C(bold blue)<%an>%Creset" --all'
alias glols='git log --graph --pretty="%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ar) %C(bold blue)<%an>%Creset" --stat'

# Enhanced git log aliases (your custom ones)
alias gl='git lg'   # Pretty git log (your custom format)
alias gld='git lgd' # Detailed git log with files (your custom format)

# Git utility aliases
alias gdvc='git dvc-status' # Combined git + DVC status
alias ginfo='git info'      # Quick repo info

# Git navigation aliases
alias gco='git checkout'
alias gcb='git checkout -b'

# Experiment management aliases
alias gexp='git exp-start' # Start new experiment branch
alias gexpl='git exp-list' # List experiment branches
