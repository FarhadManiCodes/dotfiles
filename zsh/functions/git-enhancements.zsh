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

# Print the branch line + ahead/behind vs upstream (assumes inside a git repo).
_git_branch_header() {
  local cyan='\033[36m' yellow='\033[33m' reset='\033[0m'
  local branch=$(git branch --show-current 2>/dev/null)
  local upstream=$(git rev-parse --abbrev-ref @{u} 2>/dev/null)

  if [[ -n "$upstream" ]]; then
    local behind=$(git rev-list --count HEAD..@{u} 2>/dev/null || echo "0")
    local ahead=$(git rev-list --count @{u}..HEAD 2>/dev/null || echo "0")
    printf "🌳 Branch: ${cyan}%s${reset} → ${cyan}%s${reset}\n" "$branch" "$upstream"
    [[ "$ahead" -gt 0 ]] && printf "   📈 ${yellow}%s commits ahead${reset}\n" "$ahead"
    [[ "$behind" -gt 0 ]] && printf "   📉 ${yellow}%s commits behind${reset}\n" "$behind"
  else
    printf "🌳 Branch: ${cyan}%s${reset} (no upstream)\n" "$branch"
  fi
}

# Simple, fast git status for frequent command line use
gst() {
  # Check if in git repo
  if ! git rev-parse --git-dir >/dev/null 2>&1; then
    echo "❌ Not a git repository"
    return 1
  fi

  # Colors (matching git's default scheme)
  local green='\033[32m'
  local red='\033[31m'
  local yellow='\033[33m'
  local reset='\033[0m'

  echo "📊 Git Status"
  _git_branch_header

  echo ""

  # Show files with git-style colors
  local modified=$(git diff --name-only 2>/dev/null)
  local staged=$(git diff --cached --name-only 2>/dev/null)
  local untracked=$(git ls-files --others --exclude-standard 2>/dev/null)

  if [[ -n "$staged" ]]; then
    printf "${green}✅ Staged files:${reset}\n"
    echo "$staged" | while read -r file; do
      printf "  ${green}%s${reset}\n" "$file"
    done
    echo ""
  fi

  if [[ -n "$modified" ]]; then
    printf "${red}📝 Modified files:${reset}\n"
    echo "$modified" | while read -r file; do
      printf "  ${red}%s${reset}\n" "$file"
    done
    echo ""
  fi

  if [[ -n "$untracked" ]]; then
    printf "${yellow}❓ Untracked files:${reset}\n"
    echo "$untracked" | head -5 | while read -r file; do
      printf "  ${yellow}%s${reset}\n" "$file"
    done
    [[ $(echo "$untracked" | wc -l) -gt 5 ]] && printf "  ${yellow}... and $(($(echo "$untracked" | wc -l) - 5)) more${reset}\n"
    echo ""
  fi

  if [[ -z "$staged" ]] && [[ -z "$modified" ]] && [[ -z "$untracked" ]]; then
    printf "${green}✨ Working directory clean${reset}\n"
  fi
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
