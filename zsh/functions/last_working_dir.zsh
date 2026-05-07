# Last Working Directory - Minimal with filtering

# 1. Setup File Path
typeset -g LWD_FILE="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/lwd"
[[ -d "${LWD_FILE:h}" ]] || mkdir -p "${LWD_FILE:h}"

# 2. Filter Function
# Returns 0 (true) if we should SKIP saving.
# Returns 1 (false) if we should SAVE.
_should_skip_lwd() {
  # Safe fallback for TMPDIR if it is unset
  local tmp="${TMPDIR:-/tmp}"

  case "$PWD" in
    # System & Root directories
    /|/proc|/proc/*|/sys|/sys/*|/dev|/dev/*|/run|/run/*) return 0 ;;

    # Temporary directories (Using safe variable expansion)
    /tmp|/tmp/*|/var/tmp|/var/tmp/*|"$tmp"|"$tmp"/*) return 0 ;;

    # Home specific: Skip Home, Downloads, and Cache
    "$HOME"|"$HOME/Downloads"|"$HOME/.cache"|"$HOME/.cache"*) return 0 ;;

    # Optional: Skip git directories inside .git folders (rare but annoying)
    */.git/*) return 0 ;;
  esac

  return 1
}

# 3. Auto-restore on shell start
# Only restore if we are currently at $HOME (prevents overriding 'zsh /path/to/folder')
if [[ -r "$LWD_FILE" && "$PWD" == "$HOME" ]]; then
  local d="$(<"$LWD_FILE")"
  # Check if directory actually exists before jumping
  [[ -d "$d" ]] && builtin cd -q "$d"
fi

# 4. Save Logic
# We define a function to handle the save to keep hooks clean
_save_lwd() {
  _should_skip_lwd || print -rn "$PWD" >| "$LWD_FILE"
}

# 5. Hooks
# Use zshexit to save only when closing the terminal (Recommended)
add-zsh-hook zshexit _save_lwd

# Use chpwd to save on every directory change (Aggressive)
# CAUTION: If you have multiple tabs, the last tab you clicked in wins.
add-zsh-hook chpwd _save_lwd
