#!/bin/zsh

# activate OSC-133 for foot
autoload -Uz add-zsh-hook

function foot_cmd_start() {
    printf '\e]133;C\e\\'
}

function foot_cmd_end() {
    printf '\e]133;D\e\\'
}
# Function to save the last command
save_last_command() {
    # Save the command to a file that foot can read
    echo "$1" > ~/.zsh_last_command
}

# Hook to run before each command
add-zsh-hook preexec save_last_command
add-zsh-hook preexec foot_cmd_start
add-zsh-hook precmd foot_cmd_end

# =============================================================================
# SIMPLE SCRIPTS.SH - Always load everything with direnv support
# =============================================================================

# Early exit for non-interactive shells
[[ $- != *i* ]] && return

# =============================================================================
# ENVIRONMENT CHECK
# =============================================================================

if [[ -z "$DOTFILES" ]]; then
  if [[ -d "$HOME/dotfiles" ]]; then
    export DOTFILES="$HOME/dotfiles"
  else
    echo "❌ Cannot find dotfiles directory!" >&2
    return 1
  fi
fi

if [[ ! -d "$DOTFILES" ]]; then
  echo "❌ DOTFILES directory doesn't exist: $DOTFILES" >&2
  return 1
fi

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

# Safe sourcing function
safe_source() {
  local file="$1"
  local description="${2:-script}"

  [[ ! -f "$file" ]] && return 1
  [[ ! -r "$file" ]] && return 1

  if ! (source "$file") >/dev/null 2>&1; then
    echo "❌ Syntax error in $file" >&2
    return 1
  fi

  if source "$file"; then
    return 0
  else
    echo "❌ Failed to source: $description" >&2
    return 1
  fi
}

# =============================================================================
# BASIC SETUP
# =============================================================================

[[ -f "$HOME/.cargo/env" ]] && source "$HOME/.cargo/env"

# =============================================================================
# DIRENV SETUP (before virtualenv loading)
# =============================================================================

if command -v direnv >/dev/null 2>&1; then
  eval "$(direnv hook zsh)"

  # Centralized venv helper
  use_venv() {
    local venv_name=${1:-$(basename $PWD)}
    local venv_path="$HOME/.central_venvs/$venv_name"

    if [ ! -d "$venv_path" ]; then
      echo "Creating new venv: $venv_name"
      python -m venv "$venv_path"
    fi

    echo "source $venv_path/bin/activate" >.envrc
    direnv allow
  }
fi

# =============================================================================
# FZF CONFIGURATION
# =============================================================================

if command -v fzf >/dev/null 2>&1; then
  source <(fzf --zsh) 2>/dev/null

  export FZF_DEFAULT_OPTS='
    --height 60%
    --layout=reverse
    --border=rounded
    --info=inline
    --prompt="❯ "
    --pointer="❯"
    --marker="❯"
    --preview-window=right:50%:hidden
    --bind="ctrl-p:toggle-preview"
    --bind="alt-p:toggle-preview"
    --bind="?:toggle-preview"
    --bind="ctrl-u:preview-page-up,ctrl-d:preview-page-down"
    --bind="ctrl-f:page-down,ctrl-b:page-up"
    --tiebreak=end
    --ansi
    --color=fg:#abb2bf,bg:#282c34,hl:#61afef
    --color=fg+:#ffffff,bg+:#3e4451,hl+:#61afef
    --color=info:#e5c07b,prompt:#61afef,pointer:#e06c75
    --color=marker:#98c379,spinner:#e5c07b,header:#c678dd'
fi

# =============================================================================
# LOAD ALL SCRIPTS
# =============================================================================

# 0. get project info
safe_source "$DOTFILES/zsh/productivity/project-detection.sh" "project detection" || echo "❌ Project detection failed"

# 1. Last Working Directory
safe_source "$DOTFILES/zsh/productivity/last-working-dir.sh" "last working directory" || echo "❌ Last working directory failed"
# Auto-restore if in HOME
if [[ "$PWD" == "$HOME" ]] && type lwd >/dev/null 2>&1; then
  lwd 2>/dev/null
fi

# 2. Git Enhancements
safe_source "$DOTFILES/zsh/productivity/git-enhancements.sh" "git enhancements" || echo "❌ Git enhancements failed"

# 3. Virtual Environment Management
safe_source "$DOTFILES/zsh/productivity/virtualenv.sh" "virtual environment management" || echo "❌ Virtual environment management failed"

# 4. FZF Enhancements
if command -v fzf >/dev/null 2>&1; then
  safe_source "$DOTFILES/zsh/productivity/fzf-enhancements.sh" "FZF enhancements" || echo "❌ FZF enhancements failed"
fi

# 5. Zoxide
if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init zsh)"
fi

# 6. Custom Completions
safe_source "$DOTFILES/zsh/productivity/completions.sh" "custom completions" || echo "❌ Custom completions failed"
# 7. tmux smart start
safe_source "$DOTFILES/zsh/productivity/tmux_smart_start.sh" "tmux smart start" || echo "❌ Tmux smart start failed"
# 8. duckdb
safe_source "$DOTFILES/zsh/productivity/duckdb.sh" "duckdb" || echo "❌ DuckDB start failed"
# =============================================================================
# UTILITY COMMANDS
# =============================================================================

# Show what's loaded and working
loading_status() {
  echo "📊 Dotfiles Status:"
  echo "  DOTFILES: $DOTFILES"
  echo "  Direnv: $(command -v direnv >/dev/null 2>&1 && echo "✅" || echo "❌")"
  echo "  Git enhancements: $(type gst >/dev/null 2>&1 && echo "✅" || echo "❌")"
  echo "  Git (data science): $(type gstds >/dev/null 2>&1 && echo "✅" || echo "❌")"
  echo "  Virtual env: $(type va >/dev/null 2>&1 && echo "✅" || echo "❌")"
  echo "  use_venv helper: $(type use_venv >/dev/null 2>&1 && echo "✅" || echo "❌")"
  echo "  FZF functions: $(type fnb >/dev/null 2>&1 && echo "✅" || echo "❌")"
  echo "  Last working dir: $(type lwd >/dev/null 2>&1 && echo "✅" || echo "❌")"
  echo "  Zoxide: $(type z >/dev/null 2>&1 && echo "✅" || echo "❌")"

  # Environment info
  if [[ -n "$VIRTUAL_ENV" ]]; then
    echo "  Active venv: $(basename "$VIRTUAL_ENV")"
  fi

  if [[ -n "$DIRENV_DIR" ]]; then
    echo "  Direnv active: $(basename "$DIRENV_DIR")"
  fi

  if git rev-parse --git-dir >/dev/null 2>&1; then
    echo "  Git repo: $(basename "$(git rev-parse --show-toplevel)" 2>/dev/null)"
  fi

  # Show central venvs
  if [[ -d "$HOME/.central_venvs" ]]; then
    local venv_count=$(ls -1 "$HOME/.central_venvs" 2>/dev/null | wc -l)
    echo "  Central venvs: $venv_count environments"
  fi
}

# Aliases
alias status='loading_status'

function gemmit() {
  # Configuration - can be overridden via environment variables
  local editor="${GEMMIT_EDITOR:-${EDITOR:-vim}}"
  local skip_lint="${GEMMIT_SKIP_LINT:-false}"
  local auto_commit="${GEMMIT_AUTO_COMMIT:-false}"

  # Check if we're in a git repository
  if ! git rev-parse --git-dir &>/dev/null; then
    echo "❌ Not in a git repository."
    return 1
  fi

  # Check if gemini CLI is available
  if ! command -v gemini &>/dev/null; then
    echo "❌ Gemini CLI not found. Install it with:"
    echo "   npm install -g @google/gemini-cli"
    echo "   Or run: npx @google/gemini-cli"
    return 1
  fi

  # Check for staged changes
  local staged_diff
  staged_diff=$(git diff --cached)
  if [[ -z "$staged_diff" ]]; then
    echo "❌ No staged changes to create a commit for."
    echo "💡 Tip: Use 'git add' to stage your changes first."
    return 1
  fi

  # Show what's being committed
  echo "📝 Staged changes:"
  git diff --cached --name-status | sed 's/^/  /'
  echo ""

  # Build prompt with better context
  local files_changed
  files_changed=$(git diff --cached --name-only | wc -l | tr -d ' ')
  local prompt="Based on the following git diff, please generate a high-quality commit message. The message should follow best practices: it must be human-readable for easy understanding and machine-readable by adhering to the Conventional Commits specification.

Context: This commit affects $files_changed file(s).

Guidelines:
- Start with a type (e.g., feat, fix, docs, style, refactor, test, chore)
- Provide a concise summary line (50 chars or less)
- Optionally, include a more detailed body explaining the 'what' and 'why'
- Do not include any text or explanations other than the commit message itself

Here is the diff:
$staged_diff"

  echo "🤖 Asking Gemini for a commit message suggestion..."
  local suggestion

  # Try using the --prompt flag first (more reliable)
  if suggestion=$(gemini --prompt "$prompt" 2>/dev/null); then
    echo "✅ Got suggestion using --prompt flag"
  # Fallback to piping (in case --prompt doesn't work in some versions)
  elif suggestion=$(echo "$prompt" | gemini 2>/dev/null); then
    echo "✅ Got suggestion using pipe"
  else
    echo "⚠️ Gemini CLI did not return a suggestion."
    echo "💡 Make sure you're authenticated: run 'gemini' and sign in first"
    read "manual?Would you like to write the commit message manually? (y/N): "
    if [[ "$manual" != "y" && "$manual" != "Y" ]]; then
      echo "❌ Aborting."
      return 1
    fi
    suggestion="# Enter your commit message above this line
# 
# Please enter the commit message for your changes. Lines starting
# with '#' will be ignored, and an empty message aborts the commit."
  fi

  # Create secure temporary file
  local tmpfile
  tmpfile=$(mktemp -t gemmit-XXXXXXXX)
  chmod 600 "$tmpfile"
  trap 'rm -f "$tmpfile"' EXIT HUP INT TERM

  # Prepare commit message file
  echo "$suggestion" >"$tmpfile"
  echo "" >>"$tmpfile"
  echo "# Staged changes:" >>"$tmpfile"
  git diff --cached --name-status | sed 's/^/# /' >>"$tmpfile"
  echo "# " >>"$tmpfile"
  echo "# Lines starting with '#' will be ignored" >>"$tmpfile"

  # Open editor (with fallback)
  if ! command -v "$editor" &>/dev/null; then
    echo "⚠️ Editor '$editor' not found, falling back to vim"
    editor="vim"
  fi

  "$editor" "$tmpfile"
  local edit_result=$?

  if [[ $edit_result -ne 0 ]]; then
    echo "❌ Editor exited with error code $edit_result. Aborting."
    return 1
  fi

  # Remove comments and empty lines from the end
  sed -i.bak '/^#/d; /^[[:space:]]*$/d' "$tmpfile" && rm -f "$tmpfile.bak"

  if [[ ! -s "$tmpfile" ]]; then
    echo "🚫 Commit aborted: message file is empty."
    return 1
  fi

  # Show the final message
  echo ""
  echo "📋 Final commit message:"
  cat "$tmpfile" | sed 's/^/  /'
  echo ""

  # Run commitlint if not skipped
  if [[ "$skip_lint" != "true" ]] && command -v npx &>/dev/null; then
    if ! npx commitlint --edit "$tmpfile" 2>/dev/null; then
      echo "❌ Commit message failed commitlint checks."
      read "confirm_invalid?Do you want to commit anyway? (y/N): "
      if [[ "$confirm_invalid" != "y" && "$confirm_invalid" != "Y" ]]; then
        echo "❌ Commit aborted due to lint errors."
        return 1
      fi
    else
      echo "✅ Commit message passed lint checks."
    fi
  fi

  # Final confirmation (unless auto-commit is enabled)
  if [[ "$auto_commit" != "true" ]]; then
    read "confirm?Do you want to commit this message? (y/N): "
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
      echo "❌ Commit aborted by user."
      return 1
    fi
  fi

  # Commit with the message
  if git commit -F "$tmpfile"; then
    echo "✅ Commit successful!"

    # Optional: show the commit
    echo ""
    echo "📊 Commit details:"
    git show --stat HEAD
  else
    echo "❌ Git commit failed!"
    return 1
  fi
}

# Enhanced alias with help
alias ggc='gemmit'
alias ggc-help='echo "gemmit usage:
  Environment variables:
    GEMMIT_EDITOR=code       # Use VS Code instead of vim
    GEMMIT_SKIP_LINT=true    # Skip commitlint validation
    GEMMIT_AUTO_COMMIT=true  # Skip final confirmation
  
  Prerequisites:
    - Install Gemini CLI: npm install -g @google/gemini-cli
    - Authenticate: run \"gemini\" and sign in with Google account
  
  Examples:
    ggc                      # Normal usage
    GEMMIT_EDITOR=code ggc   # Use VS Code
    GEMMIT_SKIP_LINT=true ggc # Skip linting"'

safe_source "$DOTFILES/zsh/productivity/llama.sh" "llama" || echo "❌ llama.sh failed"
