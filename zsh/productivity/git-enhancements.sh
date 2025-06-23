#!/bin/bash
# Enhanced Git Shell Integration for Data Science
# ~/dotfiles/zsh/git-enhancements.sh

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
  local selected_type=$(printf '%s\n' "${types[@]}" | fzf --prompt="Select commit type: " --height=~50% | cut -d: -f1)

  if [ -z "$selected_type" ]; then
    echo "❌ Commit cancelled"
    return 1
  fi

  # Prompt for optional scope
  echo -n "📝 Optional scope (component/dataset/module): "
  read -r scope

  # Prompt for description
  echo -n "📝 Commit message: "
  read -r message

  if [ -z "$message" ]; then
    echo "❌ Commit message required"
    return 1
  fi

  # Format the commit message
  local commit_msg
  if [ -n "$scope" ]; then
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
  local cyan='\033[36m'
  local reset='\033[0m'

  # Branch info with ahead/behind status
  local branch=$(git branch --show-current 2>/dev/null)
  local upstream=$(git rev-parse --abbrev-ref @{u} 2>/dev/null)

  echo "📊 Git Status"
  if [ -n "$upstream" ]; then
    local ahead=$(git rev-list --count HEAD..@{u} 2>/dev/null || echo "0")
    local behind=$(git rev-list --count @{u}..HEAD 2>/dev/null || echo "0")
    printf "🌳 Branch: ${cyan}%s${reset} → ${cyan}%s${reset}\n" "$branch" "$upstream"
    [ "$ahead" -gt 0 ] && printf "   📈 ${yellow}%s ahead${reset}\n" "$ahead"
    [ "$behind" -gt 0 ] && printf "   📉 ${yellow}%s behind${reset}\n" "$behind"
  else
    printf "🌳 Branch: ${cyan}%s${reset} (no upstream)\n" "$branch"
  fi

  echo ""

  # Show files with git-style colors
  local modified=$(git diff --name-only 2>/dev/null)
  local staged=$(git diff --cached --name-only 2>/dev/null)
  local untracked=$(git ls-files --others --exclude-standard 2>/dev/null)

  if [ -n "$staged" ]; then
    printf "${green}✅ Staged files:${reset}\n"
    echo "$staged" | while read -r file; do
      printf "  ${green}%s${reset}\n" "$file"
    done
    echo ""
  fi

  if [ -n "$modified" ]; then
    printf "${red}📝 Modified files:${reset}\n"
    echo "$modified" | while read -r file; do
      printf "  ${red}%s${reset}\n" "$file"
    done
    echo ""
  fi

  if [ -n "$untracked" ]; then
    printf "${yellow}❓ Untracked files:${reset}\n"
    echo "$untracked" | head -5 | while read -r file; do
      printf "  ${yellow}%s${reset}\n" "$file"
    done
    [ $(echo "$untracked" | wc -l) -gt 5 ] && printf "  ${yellow}... and $(($(echo "$untracked" | wc -l) - 5)) more${reset}\n"
    echo ""
  fi

  if [ -z "$staged" ] && [ -z "$modified" ] && [ -z "$untracked" ]; then
    printf "${green}✨ Working directory clean${reset}\n"
  fi
}

# Function to colorize files based on git status
_colorize_git_files() {
  local files="$1"
  local green='\033[32m'
  local red='\033[31m'
  local yellow='\033[33m'
  local magenta='\033[35m'
  local reset='\033[0m'

  echo "$files" | while IFS= read -r line; do
    if [ -n "$line" ]; then
      local git_status="${line:0:2}"
      case "$git_status" in
        "A " | "M " | "R " | "C ") printf "  ${green}%s${reset}\n" "$line" ;; # Staged
        " M" | " D" | " R" | " C") printf "  ${red}%s${reset}\n" "$line" ;;   # Modified
        "MM" | "AM" | "RM") printf "  ${yellow}%s${reset}\n" "$line" ;;       # Mixed
        "??") printf "  ${red}%s${reset}\n" "$line" ;;                        # Untracked
        "!!") printf "  ${magenta}%s${reset}\n" "$line" ;;                    # Ignored
        *) printf "  %s\n" "$line" ;;                                         # Default
      esac
    fi
  done
}

# Data Science specialized git status (categorized by file type)
gstds() {
  echo "📊 Git Status - Data Science View"
  echo "=================================="
  echo ""

  # Check if in git repo
  if ! git rev-parse --git-dir >/dev/null 2>&1; then
    echo "❌ Not a git repository"
    return 1
  fi

  # Colors (matching git's default scheme)
  local green='\033[32m'
  local red='\033[31m'
  local yellow='\033[33m'
  local cyan='\033[36m'
  local blue='\033[34m'
  local magenta='\033[35m'
  local reset='\033[0m'

  # Branch info
  local branch=$(git branch --show-current 2>/dev/null)
  local upstream=$(git rev-parse --abbrev-ref @{u} 2>/dev/null)

  if [ -n "$upstream" ]; then
    local ahead=$(git rev-list --count HEAD..@{u} 2>/dev/null || echo "0")
    local behind=$(git rev-list --count @{u}..HEAD 2>/dev/null || echo "0")
    printf "🌳 Branch: ${cyan}%s${reset} → ${cyan}%s${reset}\n" "$branch" "$upstream"
    [ "$ahead" -gt 0 ] && printf "   📈 ${yellow}%s commits ahead${reset}\n" "$ahead"
    [ "$behind" -gt 0 ] && printf "   📉 ${yellow}%s commits behind${reset}\n" "$behind"
  else
    printf "🌳 Branch: ${cyan}%s${reset} (no upstream)\n" "$branch"
  fi

  echo ""

  # Get all changed files
  local all_files=$(git status --porcelain 2>/dev/null)

  if [ -z "$all_files" ]; then
    echo -e "${green}✨ Working directory clean${reset}"
    echo ""
  else
    # Categorize files by type
    local code_files=$(echo "$all_files" | grep -E '\.(py|scala|sql|sh|yaml|yml|toml|r|R)$')
    local data_files=$(echo "$all_files" | grep -E '\.(csv|parquet|json|jsonl|pkl|pickle|h5|hdf5|xlsx|xls|tsv|avro|orc)$')
    local notebook_files=$(echo "$all_files" | grep -E '\.ipynb$')
    local config_files=$(echo "$all_files" | grep -E '(config|requirements|environment|Dockerfile|\.env|\.ini|\.conf|dvc\.yaml|dvc\.lock|params\.yaml|metrics\.yaml)')
    local model_files=$(echo "$all_files" | grep -E '\.(pt|pth|h5|pkl|joblib|onnx|pb|tflite)$')
    local doc_files=$(echo "$all_files" | grep -E '\.(md|rst|txt|pdf)$')
    local other_files=$(echo "$all_files" | grep -vE '\.(py|scala|sql|sh|yaml|yml|toml|r|R|csv|parquet|json|jsonl|pkl|pickle|h5|hdf5|xlsx|xls|tsv|avro|orc|ipynb|pt|pth|joblib|onnx|pb|tflite|md|rst|txt|pdf)$|(config|requirements|environment|Dockerfile|\.env|\.ini|\.conf|dvc\.|params\.|metrics\.)')

    if [ -n "$code_files" ]; then
      echo -e "${blue}💻 Code files:${reset}"
      _colorize_git_files "$code_files"
    fi
    if [ -n "$model_files" ]; then
      echo -e "${magenta}🤖 Model files:${reset}"
      _colorize_git_files "$model_files"
    fi
    if [ -n "$data_files" ]; then
      echo -e "${cyan}📊 Data files:${reset}"
      _colorize_git_files "$data_files"
    fi
    if [ -n "$notebook_files" ]; then
      echo -e "${yellow}📓 Notebooks:${reset}"
      _colorize_git_files "$notebook_files"
    fi
    if [ -n "$config_files" ]; then
      echo -e "${blue}⚙️  Config files:${reset}"
      _colorize_git_files "$config_files"
    fi
    if [ -n "$doc_files" ]; then
      echo -e "${reset}📄 Documentation:${reset}"
      _colorize_git_files "$doc_files"
    fi
    if [ -n "$other_files" ]; then
      echo -e "${reset}📁 Other files:${reset}"
      _colorize_git_files "$other_files"
    fi
    echo ""
  fi

  # DVC status if available
  if command -v dvc >/dev/null 2>&1 && [ -f "dvc.yaml" ]; then
    echo -e "${cyan}📦 DVC Status:${reset}"
    dvc status 2>/dev/null || echo "  No DVC changes"
    echo ""
  fi

  # Environment info
  if [ -n "$VIRTUAL_ENV" ]; then
    echo -e "${green}🐍 Environment: $(basename "$VIRTUAL_ENV")${reset}"
  elif [ -n "$CONDA_DEFAULT_ENV" ]; then
    echo -e "${green}🐍 Environment: $CONDA_DEFAULT_ENV${reset}"
  fi
}

# ============================================================================
# ALIASES - Git Workflow Shortcuts
# ============================================================================

# Enhanced git status aliases
alias gs='gst'     # Simple, fast git status
alias gsds='gstds' # Data science git status (detailed, categorized)

# Git add aliases (from oh-my-zsh git plugin)
alias ga='git add'
alias gaa='git add --all'
alias gapa='git add --patch'
alias gau='git add --update'
alias gav='git add --verbose'

# Git commit aliases (from oh-my-zsh git plugin)
alias gc='git commit --verbose'
alias gca='git commit --verbose --all'
alias gcam='git commit --all --message'
alias gcmsg='git commit --message'
alias gcs='git commit --gpg-sign'
alias gcss='git commit --gpg-sign --signoff'
alias gcsm='git commit --signoff --message'
alias gcf='git config --list'

# Git diff aliases (from oh-my-zsh git plugin)
alias gd='git diff'
alias gdca='git diff --cached'
alias gdcw='git diff --cached --word-diff'
alias gds='git diff --staged'
alias gdw='git diff --word-diff'
alias gdup='git diff @{upstream}'

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
alias gp='git push'
alias gpu='git pull'

# Experiment management aliases
alias gexp='git exp-start' # Start new experiment branch
alias gexpl='git exp-list' # List experiment branches

# ============================================================================
# FUNCTIONS - Advanced Git Operations
# ============================================================================

# Git diff with viewer (from oh-my-zsh git plugin)
gdv() {
  git diff -w "$@" | view -
}

# Git describe tags
gdct() {
  git describe --tags $(git rev-list --tags --max-count=1)
}
