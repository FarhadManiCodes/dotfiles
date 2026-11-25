#!/bin/bash
# shellcheck disable=SC2154  # verbose: set by config-drift, which sources this file
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
check_baseline() { # $1 label, $2 baseline, $3 observed paths, $4 complete (0/1)
  local label=$1 base=$2 observed=$3 complete=$4 changes line
  local -a added=() removed=()
  # One pass: baseline paths from the file, observed paths from stdin, sorted
  # "+path" (new) and "-path" (gone) lines out. gawk's exit status reports an
  # unreadable baseline. ARGIND and sorted_in are gawk-only.
  if ! changes=$(gawk '
      ARGIND == 1 { if (/^\//) base[$0]; next }
      NF { seen[$0] }
      END {
        PROCINFO["sorted_in"] = "@ind_str_asc"
        for (p in seen) if (!(p in base)) print "+" p
        for (p in base) if (!(p in seen)) print "-" p
      }' "$base" - 2>/dev/null <<<"$observed"); then
    warn "${base#"$df_dir"/} is unreadable — baseline not compared"
    return
  fi
  while IFS= read -r line; do
    case $line in
      +*) added+=("${line:1}") ;;
      -*) removed+=("${line:1}") ;;
    esac
  done <<<"$changes"
  if ((${#added[@]})); then
    warn "$label: ${#added[@]} path(s) not in ${base#"$df_dir"/} — decide and add them"
    printf '       + %s\n' "${added[@]}"
  fi
  if ((complete && ${#removed[@]})); then
    note "$label: ${#removed[@]} baseline path(s) no longer present"
    ((verbose)) && printf '       - %s\n' "${removed[@]}"
  fi
}

check_etc_baselines() {
  local scan line etc_complete=1 etc_files='' package_files unowned package_info modified
  local -a unreadable=()
  hdr "/etc against its baselines"
  # One walk of /etc. This runs without root by design, so the root-only
  # directories are always invisible: find prunes them and names them ("d "),
  # because the set includes sudoers.d, polkit-1/rules.d and system-connections --
  # a bare "scan incomplete" would not tell you an unowned file could hide there.
  # With them pruned, a failing find means something else went wrong. Either way
  # the view is partial: additions are still useful, but absence from it is not
  # evidence that a file was removed.
  scan=$(find /etc -type d \( ! -readable -o ! -executable \) -printf 'd %p\n' -prune \
    -o -type f -printf 'f %p\n' 2>/dev/null) || etc_complete=0
  while IFS= read -r line; do
    case $line in
      'd '*) unreadable+=("${line:2}") ;;
      'f '*) etc_files+=${line:2}$'\n' ;;
    esac
  done <<<"$scan"
  if package_files=$(pacman -Qlq 2>/dev/null) && [[ -n $package_files ]]; then
    if ((! etc_complete)); then
      warn "unowned: /etc scan failed, cause unknown — checking additions only"
    fi
    if ((${#unreadable[@]})); then
      etc_complete=0
      skip "unowned: ${#unreadable[@]} root-only dir(s) not scanned — other additions still checked; -v lists them"
      ((verbose)) && printf '       ~ %s\n' "${unreadable[@]}" | sort
    fi
    # The package list (fd 3) is the owned set; unowned = /etc files not in it.
    if unowned=$(gawk '
        ARGIND == 1 { if (/^\/etc\//) owned[$0]; next }
        NF && !($0 in owned) && !/^\/etc\/ca-certificates\/(extracted|trust-source)\//
      ' /dev/fd/3 - 3<<<"$package_files" <<<"$etc_files"); then
      check_baseline "unowned" "$df_dir/etc/unowned.txt" "$unowned" "$etc_complete"
    else
      warn "unowned: comparison failed — unowned files not compared"
    fi
  else
    warn "pacman file inventory failed or was empty — unowned files not compared"
  fi

  # -Qii compares backup-file content, not -Qkk's metadata. Unreadable files
  # remain outside its coverage; do not infer removals from their absence.
  if package_info=$(pacman -Qii 2>/dev/null) && [[ -n $package_info ]]; then
    modified=$(awk '/ \[modified\]$/ {sub(/^[^\/]*/, ""); sub(/ \[modified\]$/, ""); print}' \
      <<<"$package_info")
    check_baseline "modified" "$df_dir/etc/modified.txt" "$modified" 0
  else
    warn "pacman backup inventory failed or was empty — modified files not compared"
  fi

  pass -p "no new paths in the visible /etc inventories (unreadable files excluded)"
}
