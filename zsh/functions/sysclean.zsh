# sysclean - smart system and cache cleanup
#
# Usage:
#   sysclean        # Safe routine cleanup (keeps rollback packages & active caches)
#   sysclean --all  # Deep aggressive cleanup (wipes uv/ccache/web caches & old rollbacks)
#   sysclean -a     # Same as --all
#
# Step 3 removes packages and is not gated by --all, so pacman is left to prompt.

sysclean() {
  local all=false
  if [[ "$1" == "-a" || "$1" == "--all" ]]; then
    all=true
    echo "==> Running DEEP AGGRESSIVE system cleanup (--all)"
  else
    echo "==> Running SAFE routine system cleanup (use 'sysclean -a' for deep wipe)"
  fi

  # 1. Claude CLI old versions
  echo "==> 1. Claude CLI versions"
  if type _sysup_prune_claude_versions >/dev/null 2>&1; then
    _sysup_prune_claude_versions
  elif [[ -f ~/.config/zsh/functions/sysup.zsh ]]; then
    source ~/.config/zsh/functions/sysup.zsh && _sysup_prune_claude_versions
  fi

  # 2. Pacman / Paru download cache & partials
  echo "==> 2. Pacman / Paru download cache"
  # Clean partial downloads first so paccache/pacman don't fail on fd errors
  sudo rm -f /var/cache/pacman/pkg/download-* /var/cache/pacman/pkg/*.part 2>/dev/null

  if command -v paccache >/dev/null 2>&1; then
    if [[ "$all" == true ]]; then
      echo "   Keeping only 1 latest installed version of each package..."
      sudo paccache -rk1
      echo "   Removing all uninstalled package archives..."
      sudo paccache -ruk0
    else
      echo "   Keeping 2 latest versions of installed packages (for rollback safety)..."
      sudo paccache -rk2
      echo "   Keeping 1 version of uninstalled packages..."
      sudo paccache -ruk1
    fi
  else
    # Fallback if pacman-contrib is ever removed; paccache can keep N versions.
    if [[ "$all" == true ]]; then
      sudo pacman -Scc
    else
      sudo pacman -Sc
    fi
  fi

  # 3. Orphaned dependencies
  #
  # `pacman -Qtdq` means "installed as a dependency, no longer required" -- not
  # "unwanted". Removing the postgresql server put postgresql-libs, which owns
  # psql, on this list. Hence the prompt, and -Rs rather than -Rns (-n is
  # --nosave: it deletes config files instead of leaving .pacsave).
  echo "==> 3. Orphaned system packages"
  local -a orphans
  orphans=($(pacman -Qtdq 2>/dev/null))
  if (( ${#orphans[@]} )); then
    echo "   ${#orphans[@]} orphaned package(s): ${orphans[*]}"
    sudo pacman -Rs "${orphans[@]}"
  else
    echo "   No orphaned packages found."
  fi

  # 4. Python uv cache
  echo "==> 4. Python uv cache"
  if command -v uv >/dev/null 2>&1; then
    if [[ "$all" == true ]]; then
      echo "   Clearing entire uv wheel/download cache..."
      uv cache clean
    else
      echo "   Pruning dangling/unreferenced uv cache entries..."
      uv cache prune
    fi
  fi

  # 5. Node npm cache
  echo "==> 5. Node npm cache"
  if command -v npm >/dev/null 2>&1; then
    npm cache clean --force 2>/dev/null && echo "   npm cache cleaned." || true
  fi

  # 6. C/C++ compiler cache (ccache)
  echo "==> 6. C/C++ compiler cache (ccache)"
  if command -v ccache >/dev/null 2>&1; then
    if [[ "$all" == true ]]; then
      ccache -C && echo "   ccache completely cleared."
    else
      ccache -c && echo "   ccache trimmed to configured max size."
    fi
  fi

  # 7. Systemd Core Dumps & Journal Logs
  echo "==> 7. System logs & crash dumps"
  if [[ -d /var/lib/systemd/coredump ]]; then
    sudo rm -rf /var/lib/systemd/coredump/* 2>/dev/null
    echo "   Systemd coredumps cleared."
  fi
  # 2 months, not 2 weeks: the journal is ~24 MB and journald already caps
  # itself, so short retention destroys diagnostic history to reclaim nothing.
  if command -v journalctl >/dev/null 2>&1; then
    sudo journalctl --vacuum-time=2months >/dev/null 2>&1
    echo "   Systemd journal logs older than 2 months cleaned."
  fi

  # 8. Claude Code orphaned file-history (undo snapshots for deleted sessions)
  echo "==> 8. Claude Code orphaned file-history"
  local claude_hist="$HOME/.claude/file-history"
  local claude_proj="$HOME/.claude/projects"
  if [[ -d "$claude_hist" && -d "$claude_proj" ]]; then
    local -A _live
    local f
    for f in "$claude_proj"/**/*.jsonl(N); do
      _live[${f:t:r}]=1
    done
    local d removed=0
    for d in "$claude_hist"/*(N/); do
      [[ -z ${_live[${d:t}]} ]] && rm -rf -- "$d" && (( removed++ ))
    done
    echo "   Removed $removed orphaned file-history dir(s)."
  else
    echo "   No Claude file-history to check."
  fi

  # 9. Browser web caches (only on --all)
  if [[ "$all" == true ]]; then
    echo "==> 9. Browser web content cache"
    if [[ -d ~/.cache/mozilla/firefox ]]; then
      rm -rf ~/.cache/mozilla/firefox/*/cache2/* 2>/dev/null
      echo "   Firefox web asset cache cleared."
    fi
  fi

  echo "==> sysclean done"
}
