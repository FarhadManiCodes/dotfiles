# shellcheck shell=bash
# Two sweeps that used to be prose in etc/README.md, which is why `pacman -Qkk`
# was only ever run against `nftables` for four months. Prose does not run.
#
# Both diff against a tracked baseline rather than reporting a count. The counts
# move on their own -- the unowned set was 183 on 2026-09-04 and 172 two days
# later -- so a count is noise and only "a path nobody has decided about" is a
# finding.
#
# The ca-certificates trees are excluded, not listed: update-ca-trust rewrites
# all 131 of them wholesale, and a baseline that churns on every ca-certificates
# update is a warning you stop reading.
check_baseline() {   # $1 label, $2 baseline, $3 observed paths, $4 complete (0/1)
  local label=$1 base=$2 observed=$3 complete=$4 baseline changes line
  local -a added=() removed=()
  if ! baseline=$(awk '/^\// {print}' "$base" 2>/dev/null | sort -u); then
    warn "${base#"$df_dir"/} is unreadable — baseline not compared"
    etc_base=1; return
  fi
  # Sort each side once; one comm computes both additions and removals.
  observed=$(printf '%s\n' "$observed" | awk 'NF' | sort -u)
  changes=$(comm -3 <(printf '%s\n' "$observed" | awk 'NF') <(printf '%s\n' "$baseline" | awk 'NF'))
  while IFS= read -r line; do
    [[ -z $line ]] && continue
    if [[ $line == $'\t'* ]]; then
      removed+=("${line#$'\t'}")
    else
      added+=("$line")
    fi
  done <<<"$changes"
  if ((${#added[@]})); then
    warn "$label: ${#added[@]} path(s) not in ${base#"$df_dir"/} — decide and add them"
    printf '       + %s\n' "${added[@]}"
    etc_base=1
  fi
  if ((complete && ${#removed[@]})); then
    printf '   \033[34m--\033[0m  %s: %s baseline path(s) no longer present\n' \
      "$label" "${#removed[@]}"
    ((verbose)) && printf '       - %s\n' "${removed[@]}"
  fi
}

check_etc_baselines() {
  hdr "/etc against its baselines"
  etc_base=0
  # Keep producer exit statuses: process substitutions would hide pacman failures.
  # find may return a partial view of /etc as a normal user; additions are still
  # useful, but absence from that view is not evidence that a file was removed.
  #
  # That partial view is permanent, not a transient failure: this runs without
  # root by design, so the root-only directories are always invisible. Name them,
  # because the set includes sudoers.d, polkit-1/rules.d and system-connections --
  # "scan incomplete" does not tell you an unowned file could be hiding there.
  etc_complete=1
  etc_files=$(find /etc -type f 2>/dev/null) || etc_complete=0
  if package_files=$(pacman -Qlq 2>/dev/null) && [[ -n $package_files ]]; then
    unowned=$(comm -23 <(printf '%s\n' "$etc_files" | sort -u) \
        <(printf '%s\n' "$package_files" | sort -u) | \
        awk '!/^\/etc\/ca-certificates\/(extracted|trust-source)\// && NF')
    if (( ! etc_complete )); then
      mapfile -t unreadable < <(find /etc -type d \
          \( ! -readable -o ! -executable \) 2>/dev/null | sort)
      if ((${#unreadable[@]})); then
        skip "unowned: ${#unreadable[@]} root-only dir(s) not scanned (no root) — additions elsewhere still checked; -v lists them"
        ((verbose)) && printf '       ~ %s\n' "${unreadable[@]}"
      else
        skip "unowned: /etc scan incomplete — checking additions only"
      fi
      etc_base=1
    fi
    check_baseline "unowned" "$df_dir/etc/unowned.txt" "$unowned" "$etc_complete"
  else
    warn "pacman file inventory failed or was empty — unowned files not compared"; etc_base=1
  fi

  # -Qii compares backup-file content, not -Qkk's metadata. Unreadable files
  # remain outside its coverage; do not infer removals from their absence.
  if package_info=$(pacman -Qii 2>/dev/null) && [[ -n $package_info ]]; then
    modified=$(awk '/ \[modified\]$/ {sub(/^[^\/]*/, ""); sub(/ \[modified\]$/, ""); print}' \
        <<<"$package_info")
    check_baseline "modified" "$df_dir/etc/modified.txt" "$modified" 0
  else
    warn "pacman backup inventory failed or was empty — modified files not compared"; etc_base=1
  fi

  ((etc_base)) || ok "no new paths in the visible /etc inventories (unreadable files excluded)"
}
