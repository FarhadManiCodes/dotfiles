#!/bin/bash
# ============================================================================
# Clean Last Working Directory - Just the essentials
# ~/dotfiles/zsh/productivity/last-working-dir.sh
# ============================================================================

# Cache directory setup
ZSH_CACHE_DIR="${ZSH_CACHE_DIR:-${XDG_CACHE_HOME:-$HOME/.cache}}"
[[ ! -d "$ZSH_CACHE_DIR" ]] && mkdir -p "$ZSH_CACHE_DIR"

# Auto-save directory changes (with filtering)
autoload -U add-zsh-hook
add-zsh-hook chpwd chpwd_last_working_dir

chpwd_last_working_dir() {
  [[ "$ZSH_SUBSHELL" -eq 0 ]] || return 0

  # Skip unwanted directories
  case "$PWD" in
    # Root and core system directories
    / | /proc | /proc/* | /sys | /sys/* | /dev | /dev/* | /run | /run/*) return 0 ;;
    # System binaries and libraries
    /boot | /boot/* | /lib | /lib/* | /lib32 | /lib32/* | /lib64 | /lib64/* | /sbin | /sbin/*) return 0 ;;
    # Snap packages and recovery
    /snap | /snap/* | /lost+found | /lost+found/*) return 0 ;;
    # Temporary directories
    /tmp | /tmp/* | /var/tmp | /var/tmp/*) return 0 ;;
    # User directories that change frequently
    "$HOME" | "$HOME/Downloads" | "$HOME/.cache" | "$HOME/.cache"*) return 0 ;;
  esac

  local cache_file="$ZSH_CACHE_DIR/last-working-dir${SSH_USER:+.$SSH_USER}"
  builtin echo -E "$PWD" >|"$cache_file"
}

# Jump to saved directory
lwd() {
  local cache_file="$ZSH_CACHE_DIR/last-working-dir${SSH_USER:+.$SSH_USER}"
  [[ -r "$cache_file" ]] && cd "$(<"$cache_file")"
}
