#!/bin/bash
# ============================================================================
# Smart Last Working Directory (Oh My Zsh Replacement)
# ~/dotfiles/zsh/productivity/last-working-dir.sh
# ============================================================================

# Configuration
export LAST_WORKING_DIR_ENABLED=true
export LAST_WORKING_DIR_FILE="$HOME/.last_working_dir"

# =============================================================================
# CORE FUNCTIONS
# =============================================================================

# Smart directory saving - only save meaningful directories
smart_save_directory() {
  # Only save if feature is enabled
  [[ "$LAST_WORKING_DIR_ENABLED" != "true" ]] && return

  # Only save in interactive shells
  [[ ! -o interactive ]] && return

  # Don't save in tmux sessions (you have tmux session restoration)
  [[ -n "$TMUX" ]] && return

  # Don't save temporary or system directories
  case "$PWD" in
    /tmp/* | /var/* | /proc/* | /sys/* | /dev/* | /run/*) return ;;
    "$HOME/Downloads"* | "$HOME/.cache"* | "$HOME/.local/share/Trash"*) return ;;
    "$HOME/.config/local"*) return ;;
  esac

  # Don't save if we're in home directory (let user start fresh)
  [[ "$PWD" == "$HOME" ]] && return

  # Only save if we've been in this directory for a bit (avoid rapid changes)
  local now=$(date +%s)
  local last_save_time=0
  if [[ -f "$LAST_WORKING_DIR_FILE.time" ]]; then
    last_save_time=$(cat "$LAST_WORKING_DIR_FILE.time" 2>/dev/null || echo 0)
  fi

  # Wait at least 30 seconds between saves (avoid rapid directory changes)
  if ((now - last_save_time < 30)); then
    return
  fi

  # Save the directory and timestamp
  echo "$PWD" >"$LAST_WORKING_DIR_FILE"
  echo "$now" >"$LAST_WORKING_DIR_FILE.time"
}

# Smart directory restoration - only when it makes sense
smart_restore_directory() {
  # Only restore if feature is enabled
  [[ "$LAST_WORKING_DIR_ENABLED" != "true" ]] && return

  # Only restore in interactive shells
  [[ ! -o interactive ]] && return

  # Don't restore in tmux sessions (let tmux handle restoration)
  [[ -n "$TMUX" ]] && return

  # Don't restore if we're in SSH session (be conservative)
  [[ -n "$SSH_CONNECTION" ]] && return

  # Don't restore if we're not starting in $HOME
  [[ "$PWD" != "$HOME" ]] && return

  # Don't restore if file doesn't exist or is empty
  [[ ! -f "$LAST_WORKING_DIR_FILE" ]] && return
  [[ ! -s "$LAST_WORKING_DIR_FILE" ]] && return

  local last_dir
  last_dir=$(cat "$LAST_WORKING_DIR_FILE" 2>/dev/null)

  # Validate the directory still exists and is accessible
  [[ ! -d "$last_dir" ]] && return
  [[ ! -r "$last_dir" ]] && return

  # Don't restore to the same directory we're already in
  [[ "$last_dir" == "$PWD" ]] && return

  # Don't restore to home directory (redundant)
  [[ "$last_dir" == "$HOME" ]] && return

  # Don't restore if the saved directory is more than 7 days old
  if [[ -f "$LAST_WORKING_DIR_FILE.time" ]]; then
    local save_time=$(cat "$LAST_WORKING_DIR_FILE.time" 2>/dev/null || echo 0)
    local now=$(date +%s)
    local age=$((now - save_time))
    # 7 days = 604800 seconds
    if ((age > 604800)); then
      return
    fi
  fi

  # Restore the directory
  if cd "$last_dir" 2>/dev/null; then
    echo "🔄 Restored last working directory: $(basename "$last_dir")"

    # Show useful context about the restored directory
    local context_shown=false

    # Python project detection
    if [[ -f "requirements.txt" ]] || [[ -f "pyproject.toml" ]] || [[ -f "environment.yml" ]]; then
      echo "🐍 Python project detected"
      context_shown=true
    fi

    # Git repository detection
    if git rev-parse --git-dir >/dev/null 2>&1; then
      local branch=$(git branch --show-current 2>/dev/null)
      echo "🌳 Git repository: ${branch:-unknown}"
      context_shown=true
    fi

    # Data science project detection
    if [[ -d "data" ]] && [[ -d "notebooks" ]]; then
      echo "📊 Data science project structure detected"
      context_shown=true
    fi

    # Show working directory if no specific context found
    if [[ "$context_shown" != "true" ]]; then
      echo "📁 Working in: $last_dir"
    fi

    # Note: Your auto_activate_venv function will automatically handle
    # virtual environment activation when we change to this directory
  else
    # If cd failed, remove the invalid saved directory
    rm -f "$LAST_WORKING_DIR_FILE" "$LAST_WORKING_DIR_FILE.time"
  fi
}

# =============================================================================
# MANAGEMENT COMMANDS
# =============================================================================

# Show status and configuration
lwd_status() {
  echo "📁 Last Working Directory Status"
  echo "================================"
  echo "Enabled: $LAST_WORKING_DIR_ENABLED"
  echo "Current: $PWD"
  echo ""

  if [[ -f "$LAST_WORKING_DIR_FILE" ]]; then
    local last_dir=$(cat "$LAST_WORKING_DIR_FILE" 2>/dev/null)
    local save_time="unknown"
    local age_info=""

    if [[ -f "$LAST_WORKING_DIR_FILE.time" ]]; then
      local timestamp=$(cat "$LAST_WORKING_DIR_FILE.time" 2>/dev/null)
      if [[ -n "$timestamp" ]]; then
        save_time=$(date -d "@$timestamp" 2>/dev/null || date -r "$timestamp" 2>/dev/null || echo "unknown")
        local now=$(date +%s)
        local age=$((now - timestamp))
        if ((age < 3600)); then
          age_info=" ($((age / 60)) minutes ago)"
        elif ((age < 86400)); then
          age_info=" ($((age / 3600)) hours ago)"
        else
          age_info=" ($((age / 86400)) days ago)"
        fi
      fi
    fi

    echo "Saved: $last_dir"
    echo "When: $save_time$age_info"

    if [[ ! -d "$last_dir" ]]; then
      echo "⚠️  Saved directory no longer exists"
    elif [[ ! -r "$last_dir" ]]; then
      echo "⚠️  Saved directory not accessible"
    fi
  else
    echo "Saved: None"
  fi

  echo ""
  echo "Context:"
  echo "  In tmux: ${TMUX:+Yes}${TMUX:-No}"
  echo "  In SSH: ${SSH_CONNECTION:+Yes}${SSH_CONNECTION:-No}"
  echo "  Will restore on startup: $([[ -z "$TMUX" && -z "$SSH_CONNECTION" && "$PWD" == "$HOME" && -f "$LAST_WORKING_DIR_FILE" ]] && echo "Yes" || echo "No")"
}

# Toggle feature on/off
lwd_toggle() {
  if [[ "$LAST_WORKING_DIR_ENABLED" == "true" ]]; then
    export LAST_WORKING_DIR_ENABLED=false
    echo "📁 Last working directory disabled"
  else
    export LAST_WORKING_DIR_ENABLED=true
    echo "📁 Last working directory enabled"
    # Save current directory if we're enabling
    smart_save_directory
  fi
}

# Clear saved directory
lwd_clear() {
  rm -f "$LAST_WORKING_DIR_FILE" "$LAST_WORKING_DIR_FILE.time"
  echo "📁 Last working directory cleared"
}

# Manually jump to last working directory
lwd_goto() {
  if [[ -f "$LAST_WORKING_DIR_FILE" ]]; then
    local last_dir=$(cat "$LAST_WORKING_DIR_FILE" 2>/dev/null)
    if [[ -d "$last_dir" ]]; then
      cd "$last_dir"
      echo "📁 Jumped to last working directory: $(basename "$last_dir")"
      # Show the same context info as restoration
      if git rev-parse --git-dir >/dev/null 2>&1; then
        local branch=$(git branch --show-current 2>/dev/null)
        echo "🌳 Git repository: ${branch:-unknown}"
      fi
    else
      echo "❌ Last working directory no longer exists: $last_dir"
      lwd_clear
    fi
  else
    echo "❌ No last working directory saved"
  fi
}

# Force save current directory (useful for manual control)
lwd_save() {
  if [[ "$PWD" == "$HOME" ]]; then
    echo "⚠️  Not saving home directory"
    return 1
  fi

  echo "$PWD" >"$LAST_WORKING_DIR_FILE"
  echo "$(date +%s)" >"$LAST_WORKING_DIR_FILE.time"
  echo "📁 Saved current directory: $(basename "$PWD")"
}

# =============================================================================
# ZSH INTEGRATION
# =============================================================================

# Hook into directory changes (replaces the simple chpwd from your existing setup)
if [[ -n "$ZSH_VERSION" ]]; then
  # For zsh, we can replace the existing chpwd function
  function chpwd() {
    smart_save_directory
  }
fi

# =============================================================================
# ALIASES
# =============================================================================
alias lwd='lwd_status'
alias lwd-toggle='lwd_toggle'
alias lwd-clear='lwd_clear'
alias lwd-goto='lwd_goto'
alias lwd-save='lwd_save'

# =============================================================================
# INITIALIZATION
# =============================================================================

# Auto-restore on script load (when shell starts)
smart_restore_directory

# Debug function (can be removed in production)
lwd_debug() {
  echo "🔧 Last Working Directory Debug"
  echo "==============================="
  echo "LAST_WORKING_DIR_ENABLED: $LAST_WORKING_DIR_ENABLED"
  echo "LAST_WORKING_DIR_FILE: $LAST_WORKING_DIR_FILE"
  echo "Current PWD: $PWD"
  echo "In TMUX: ${TMUX:+Yes}${TMUX:-No}"
  echo "In SSH: ${SSH_CONNECTION:+Yes}${SSH_CONNECTION:-No}"
  echo "Interactive: $([[ -o interactive ]] && echo "Yes" || echo "No")"
  echo ""
  echo "Files:"
  ls -la "$LAST_WORKING_DIR_FILE"* 2>/dev/null || echo "  No saved files"
}
