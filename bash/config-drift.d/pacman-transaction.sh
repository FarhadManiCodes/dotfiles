#!/bin/bash
# shellcheck disable=SC2154  # issues: set by config-drift, which sources this file
# mkinitcpio runs from a PostTransaction hook. When it fails it prints the error
# into the middle of pacman's output and does NOT fail the transaction, so the
# only sign is a line you scrolled past -- and you find out at the next boot.
# That has already happened here once: 2025-11-20, `==> ERROR: file not found:
# '/etc/vconsole.conf'` during the original archinstall, followed by "the image
# may not be complete".
#
# /var/log/pacman.log is 0644 root:root, so this needs no root -- and unlike an
# update transcript it is persistent and covers transactions run outside sysup.
check_pacman_transaction() {
  local block=$1 when line message warned=$issues
  # Each preset build stays open until mkinitcpio answers it with a success or a
  # deliberate skip: counting per transaction would let one kernel's success hide
  # the other's failure. The pacman hook must also end in a success once it has
  # printed anything; a run that selects no preset prints nothing and is fine.
  local build_open=0 unanswered=0 in_hook=0 hook_printed=0 hook_built=0
  when=${block%%]*}
  when=${when#\[}
  while IFS= read -r line; do
    case $line in
      *"running '90-mkinitcpio-install.hook'"*) in_hook=1 ;;
      *"[ALPM] running '"*) in_hook=0 ;;
      *'[ALPM-SCRIPTLET]'*) ((in_hook == 0)) || hook_printed=1 ;;
    esac
    case $line in
      *'==> Building image'*)
        ((build_open == 0)) || unanswered=1
        build_open=1
        ;;
      *'Initcpio image generation successful'*)
        build_open=0
        ((in_hook == 0)) || hook_built=1
        ;;
      *'No image or UKI specified. Skipping image'*) build_open=0 ;;
    esac
    if [[ $line == *'[ALPM-SCRIPTLET]'* &&
      ($line == *'==> ERROR'* || $line == *'errors were encountered'* ||
      $line == *'is empty or does not contain any presets'*) ]]; then
      message=${line#*\[ALPM-SCRIPTLET\] }
      warn "scriptlet error in transaction ${when}: ${message:0:80}"
    fi
  done <<<"$block"
  if [[ $block != *'[ALPM] transaction completed'* ]]; then
    warn "pacman transaction has no completion record (${when})"
  fi
  if ((unanswered || build_open)); then
    warn "an initramfs build never reported success (${when}) — check before rebooting"
  elif ((hook_printed && ! hook_built)); then
    warn "mkinitcpio hook ran and no image reported success (${when}) — check before rebooting"
  fi
  # Several transactions share one section, so each answers for its own.
  ((issues > warned)) || ok "clean (${when})"
}

# A log stamp is device:inode:bytes: which file the log was, and its size then.
# Prints the log's stamp now, only while it is still the file stamp $1 names and
# has not shrunk since.
log_grown_from() {
  local now
  now=$(stat -Lc '%d:%i:%s' "$plog" 2>/dev/null) || return 1
  [[ ${now%:*} == "${1%:*}" ]] || return 1
  ((${now##*:} >= ${1##*:})) || return 1
  printf '%s\n' "$now"
}

# What was written to the log after stamp $1 (tail counts bytes from 1).
log_written_after() {
  tail -c "+$((${1##*:} + 1))" "$plog" 2>/dev/null
}

# Standalone: inspect the last transaction. sysup supplies a device:inode:bytes
# boundary captured before paru, so every new transaction is checked separately.
check_last_pacman_transaction() {
  if [[ -n ${pacman_since:-} ]]; then
    hdr "Pacman transactions since update started"
  else
    hdr "Last pacman transaction"
  fi
  plog=/var/log/pacman.log
  pacman_since=${pacman_since:-}
  if [[ -n $pacman_since ]]; then
    if [[ $pacman_since == unavailable ]]; then
      warn "pacman log boundary unavailable — update transactions not checked"
    elif ! current=$(log_grown_from "$pacman_since"); then
      warn "pacman log replaced, truncated or unavailable — update coverage incomplete"
    elif ! block=$(log_written_after "$pacman_since"); then
      warn "$plog is not readable — update transactions not checked"
    else
      transaction=''
      for_check=0
      while IFS= read -r line; do
        if [[ $line == *'[ALPM] transaction started'* ]]; then
          [[ -z $transaction ]] || check_pacman_transaction "$transaction"
          transaction=''
          for_check=1
        fi
        ((for_check)) && transaction+="$line"$'\n'
      done <<<"$block"
      if [[ -n $transaction ]]; then
        check_pacman_transaction "$transaction"
      else
        ok "no new ALPM transaction recorded since update started"
      fi
      if ! log_grown_from "$current" >/dev/null; then
        warn "pacman log changed during read — update coverage incomplete"
      fi
    fi
  elif ! block=$(awk '
    /\[ALPM\] transaction started/ {block=""; found=1}
    found {block=block $0 ORS}
    END {printf "%s", block}
  ' "$plog" 2>/dev/null); then
    warn "$plog is not readable"
  elif [[ -z $block ]]; then
    ok "no transaction recorded yet"
  else
    check_pacman_transaction "$block"
  fi
}
