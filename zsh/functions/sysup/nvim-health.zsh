# `:checkhealth` after the plugin sync — see docs/architecture/neovim.md for
# why, and for the errors-vs-warnings reporting rule. Costs ~2.9s headless.
_sysup_nvim_health() {
  command -v nvim >/dev/null 2>&1 || { echo "   nvim not installed — skipping"; return 0 }

  local state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/sysup"
  mkdir -p "$state_dir" 2>/dev/null || return 0
  local report="$state_dir/nvim-health.txt"
  local seen="$state_dir/nvim-health-warnings"

  # `+w!` writes the health buffer; nvim exits 0 even when checks fail, so the
  # report itself is the only signal -- an empty file means checkhealth did not run.
  nvim --headless "+checkhealth" "+w! $report" +qa >/dev/null 2>&1
  if [[ ! -s $report ]]; then
    echo "   ⚠ checkhealth did not produce a report — run :checkhealth by hand"
    return 0
  fi

  # Severity markers are emoji (✅/⚠️/❌) which are awkward to match portably, so key
  # on the word after them. The section name comes from the line under each ==== rule.
  local -a errors warnings
  local prog='/^=+$/{getline s; sub(/:.*$/,"",s); next}
             $0 ~ "^- [^ ]+ " sev " " {sub("^- [^ ]+ " sev " ",""); print s ": " $0}'
  errors=("${(@f)$(awk -v sev=ERROR   "$prog" "$report")}")
  warnings=("${(@f)$(awk -v sev=WARNING "$prog" "$report")}")
  errors=(${errors:#})
  warnings=(${warnings:#})

  local n_err=${#errors} n_warn=${#warnings}

  if (( n_err )); then
    echo "   ✗ ${n_err} error(s):"
    printf '       %s\n' "${errors[@]}"
  fi

  # Compare the warning set with the last run, not the count: a warning that is
  # replaced by a different one keeps the count identical.
  local current previous=""
  current=$(printf '%s\n' "${warnings[@]}" | sort)
  [[ -f $seen ]] && previous=$(<"$seen")

  if [[ $current != $previous ]]; then
    if (( n_warn )); then
      echo "   ${n_warn} warning(s), changed since the last run:"
      printf '       %s\n' "${(@f)current}"
    else
      echo "   warnings cleared — none left"
    fi
    print -r -- "$current" > "$seen"
  elif (( n_warn )); then
    echo "   ${n_warn} warning(s), unchanged — see $report"
  fi

  (( n_err || n_warn )) || echo "   healthy — no errors or warnings"
  return 0
}
