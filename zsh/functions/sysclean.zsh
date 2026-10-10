# sysclean - smart system and cache cleanup
#
# Usage:
#   sysclean        # Safe routine cleanup (keeps rollback packages & active caches)
#   sysclean --all  # Deep aggressive cleanup (wipes uv/ccache/web caches & old rollbacks)
#   sysclean -a     # Same as --all
#
# Step 3 removes packages and is not gated by --all, so pacman is left to prompt.

sysclean() {
  if [[ -z ${SHPOOL_SESSION_NAME:-} ]]; then
    if ! (( $+functions[keep] )); then
      print -u2 'sysclean: shpool/keep is required; install shpool and reload ~/.zshrc'
      return 1
    fi
    keep sysclean "$@"
    return $?
  fi

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
  # Clean partial downloads first so paccache/pacman don't fail on fd errors.
  #
  # (N) on each pattern, and an array rather than two words on an `rm` line:
  # zsh's NOMATCH aborts the whole command when *either* pattern has no match,
  # and the error escapes 2>/dev/null because globbing happens before the
  # redirection is applied. With 9 download-* files and no *.part -- the state
  # of this machine -- the bare form removed none of the nine. The directory is
  # 0755 root:root, so the glob itself needs no root; only the removal does.
  local -a partials=(/var/cache/pacman/pkg/download-*(N) /var/cache/pacman/pkg/*.part(N))
  if (( ${#partials} )); then
    # Pacman also leaves private download-* staging directories on interruption.
    if sudo rm -rf -- "${partials[@]}"; then
      echo "   Removed ${#partials} partial download(s)."
    else
      echo "   !! Failed to remove partial downloads — check sudo permissions."
    fi
  else
    echo "   No partial downloads to remove."
  fi

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
  elif ! pacman -Qq >/dev/null 2>&1; then
    echo "   !! Unable to query installed packages; orphan check skipped."
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
  #
  # Only on --all. npm has no prune equivalent, so the one thing available here
  # is a full wipe -- which is a deep-clean action, not a routine one, and the
  # step above draws exactly that line for uv (prune vs clean) and ccache
  # (-c vs -C). Wiping it on every run also undoes itself: the bgutil helper
  # rebuild in `sysup` runs `npm ci`, which then re-downloads the lot.
  echo "==> 5. Node npm cache"
  if ! command -v npm >/dev/null 2>&1; then
    :
  elif [[ "$all" == true ]]; then
    if npm cache clean --force 2>/dev/null; then
      echo "   npm cache cleaned."
    else
      echo "   !! npm cache clean failed — cache left as it was."
    fi
  else
    echo "   Kept (full wipe only on --all; npm has no prune)."
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
  # (N) and an array for the same reason as step 2: bare /…/coredump/* aborts
  # on an empty directory, which is its normal state, and the old unconditional
  # echo then claimed the dumps had been cleared.
  local -a dumps=(/var/lib/systemd/coredump/*(N))
  if (( ${#dumps} )); then
    sudo rm -rf -- "${dumps[@]}"
    echo "   Removed ${#dumps} coredump(s)."
  else
    echo "   No coredumps to clear."
  fi
  # 2 months, not 2 weeks: the journal is ~24 MB and journald already caps
  # itself, so short retention destroys diagnostic history to reclaim nothing.
  if command -v journalctl >/dev/null 2>&1; then
    local vac
    if vac=$(sudo journalctl --vacuum-time=2months 2>&1); then
      echo "   Systemd journal logs older than 2 months cleaned."
    else
      echo "   !! journal vacuum failed: ${vac##*$'\n'}"
    fi
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
    # No sessions found means the probe failed, not that every snapshot is
    # orphaned. Without this the loop below deletes the whole undo history in
    # one go -- and the layout it depends on (one <session-uuid>.jsonl per
    # file-history/<session-uuid>/) belongs to Claude Code, which is free to
    # change it. Refusing to act on an empty answer is the same rule the rest
    # of this repo's probes follow.
    if (( ${#_live} == 0 )); then
      echo "   !! no sessions found under ${claude_proj/#$HOME/~} — not pruning"
    else
      local d removed=0
      for d in "$claude_hist"/*(N/); do
        [[ -z ${_live[${d:t}]} ]] && rm -rf -- "$d" && (( removed++ ))
      done
      echo "   Removed $removed orphaned file-history dir(s)."
    fi
  else
    echo "   No Claude file-history to check."
  fi

  # 9. Codex CLI old releases
  echo "==> 9. Codex CLI old releases"
  _sysclean_prune_codex_releases

  # 10. Browser web caches (only on --all)
  if [[ "$all" == true ]]; then
    echo "==> 10. Browser web content cache"
    # (N) again: this one works today only because both profiles happen to have
    # a cache2/, and would abort the removal for both if either did not.
    local -a ffcache=(~/.cache/mozilla/firefox/*/cache2/*(N))
    if (( ${#ffcache} )); then
      rm -rf -- "${ffcache[@]}"
      echo "   Firefox web asset cache cleared (${#ffcache} entries)."
    else
      echo "   No Firefox web asset cache to clear."
    fi
  fi

  # 11. NVMe health -- the only step here that frees nothing
  echo "==> 11. NVMe health"
  _sysclean_nvme_health

  echo "==> sysclean done"
}

# Keep the selected Codex release and one completed fallback for each installer
# component. Both components have their own `current` symlink and release tree.
_sysclean_prune_codex_releases() {
  if ! command -v fuser >/dev/null 2>&1; then
    echo "   !! fuser unavailable — Codex releases not pruned"
    return 0
  fi

  local kind base dir current fallback candidate removed held current_name fallback_name detail
  local -a versions ordered
  for kind in standalone app-server-daemon; do
    base="$HOME/.codex/packages/$kind"
    dir="$base/releases"
    [[ -d $dir && ! -L $dir ]] || continue

    current=$(readlink -f -- "$base/current" 2>/dev/null)
    if [[ -z $current || ${current:h} != $dir || ! -x $current/bin/codex ]]; then
      echo "   !! $kind: current release missing or outside $dir — not pruning"
      continue
    fi

    # Only complete, version-named directories. Staging and partial downloads
    # belong to the installer, not this cleanup step.
    versions=("$dir"/<->.<->.<->-x86_64-unknown-linux-musl(N/))
    (( ${#versions} )) || { echo "   !! $kind: no complete releases found — not pruning"; continue; }
    if (( ${versions[(Ie)$current]} == 0 )); then
      echo "   !! $kind: current release has an unexpected name — not pruning"
      continue
    fi
    ordered=("${(@f)$(printf '%s\n' "${versions[@]}" | sort -Vr)}")

    fallback=""
    for candidate in "${ordered[@]}"; do
      [[ -L $candidate || ! -x $candidate/bin/codex || $candidate == $current ]] && continue
      fallback=$candidate
      break
    done

    removed=0 held=0
    for candidate in "${ordered[@]}"; do
      [[ -L $candidate || ! -x $candidate/bin/codex ]] && continue
      [[ $candidate == $current || $candidate == $fallback ]] && continue
      # An older Codex session may still execute this release. Preserve its
      # files until that process exits, then prune on a later sysclean run.
      if fuser -s "$candidate/bin/codex" "$candidate/bin/codex-code-mode-host" 2>/dev/null; then
        (( ++held ))
      elif rm -rf -- "$candidate"; then
        (( ++removed ))
      else
        echo "   !! $kind: could not remove ${candidate:t}"
      fi
    done
    current_name=${current:t}
    current_name=${current_name%%-*}
    if [[ -n $fallback ]]; then
      fallback_name=${fallback:t}
      fallback_name=${fallback_name%%-*}
    else
      fallback_name=none
    fi
    if (( removed )); then
      detail="removed $removed older release(s)"
    else
      detail="no older releases to remove"
    fi
    echo "   $kind: $detail; current $current_name, fallback $fallback_name"
    (( held )) && echo "   $kind: kept $held running older release(s) for a later cleanup"
  done
  return 0
}

# Disk health, deliberately hosted by the cleanup function.
#
# It needs root: smartctl cannot open an NVMe controller as a normal user
# (verified -- "Smartctl open device: /dev/nvme0 failed: Permission denied"), so
# the plain user timer that TODO §1 first proposed could never have worked.
# sysclean already holds a sudo credential from step 2, and sysup does not
# reliably -- its only sudo is the fwupd refresh, which runs at most quarterly.
# smartd was rejected in August for the same reason it still is: it is built for
# polling several ATA disks, not one NVMe, and would be a daemon where a command
# will do.
#
# Not gated to an interval, unlike the fwupd and mirrorlist checks. Those cost a
# network fetch or a root write, so skipping most runs is worth machinery; this
# costs milliseconds under a credential already granted, and a disk can go from
# healthy to failing well inside a quarter.
#
# `-H` alone is not enough, which is the one place this departs from TODO §1.
# It reports the drive's own pass/fail flag, and that flag is derived from
# critical_warning -- by the time it trips, the drive is already in trouble. The
# fields that move first come from the same log for free: wear, spare capacity
# against the vendor's own threshold, and media errors.
_sysclean_nvme_health() {
  command -v smartctl >/dev/null 2>&1 || { echo "   smartmontools not installed — skipping"; return 0 }
  command -v jq       >/dev/null 2>&1 || { echo "   jq not installed — skipping"; return 0 }

  # Controller devices, not namespaces: /dev/nvme0, not /dev/nvme0n1. (N) so an
  # absent device skips rather than passing the glob through literally.
  local -a devs=(/dev/nvme[0-9](N))
  (( ${#devs} )) || { echo "   no NVMe controller found — skipping"; return 0 }

  local dev json k v
  for dev in $devs; do
    if ! json=$(sudo smartctl -j -H -A "$dev" 2>/dev/null) || [[ -z $json ]]; then
      echo "   ⚠ $dev: smartctl produced no output — health NOT checked"
      continue
    fi

    local -A h=()
    while IFS='=' read -r k v; do h[$k]=$v; done < <(print -r -- "$json" | jq -r '
      .nvme_smart_health_information_log as $l | {
        passed:    .smart_status.passed,
        crit:      $l.critical_warning,
        spare:     $l.available_spare,
        spare_min: $l.available_spare_threshold,
        used:      $l.percentage_used,
        media:     $l.media_errors,
        temp:      $l.temperature,
        hours:     $l.power_on_hours
      } | to_entries[] | "\(.key)=\(.value)"')

    # Never let a missing or non-numeric field read as good news: an empty
    # answer here means the check did not run, not that the disk is fine.
    local f bad=0
    for f in crit spare spare_min used media temp hours; do
      [[ ${h[$f]} == <-> ]] || bad=1
    done
    [[ ${h[passed]} == (true|false) ]] || bad=1
    if (( bad )); then
      echo "   ⚠ $dev: smartctl output missing expected fields — health NOT checked"
      continue
    fi

    local -a problems=()
    [[ ${h[passed]} == true ]] || problems+=("SMART overall health self-assessment FAILED")
    # The JSON field is a decimal, so "0x${h[crit]}" mislabelled it: a
    # critical_warning of 16 printed as 0x16 when the flags are 0x10.
    (( h[crit] ))                  && problems+=("critical warning flags set ($(printf '0x%02x' ${h[crit]}))")
    (( h[spare] < h[spare_min] ))  && problems+=("spare capacity ${h[spare]}% is below the drive's own ${h[spare_min]}% threshold")
    (( h[used] >= 80 ))            && problems+=("${h[used]}% of rated write endurance used")
    (( h[media] ))                 && problems+=("${h[media]} media/data-integrity error(s)")

    if (( ${#problems} )); then
      echo "   ⚠ $dev needs attention:"
      printf '        %s\n' "${problems[@]}"
      echo "        full report: sudo smartctl -x $dev"
      echo "        a warning is only actionable with somewhere to restore from — see TODO §10 D"
    else
      echo "   $dev healthy — ${h[used]}% endurance used, ${h[spare]}% spare, ${h[temp]}°C, ${h[hours]} h powered on"
    fi
  done
  return 0
}
