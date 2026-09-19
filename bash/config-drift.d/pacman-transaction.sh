# shellcheck shell=bash
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
  local block=$1 when tbad=0 line message
  when=${block%%]*}; when=${when#\[}
  while IFS= read -r line; do
    if [[ $line == *'[ALPM-SCRIPTLET]'* &&
          ( $line == *'==> ERROR'* || $line == *'errors were encountered'* ) ]]; then
      message=${line#*\[ALPM-SCRIPTLET\] }
      warn "scriptlet error in transaction ${when}: ${message:0:80}"; tbad=1
    fi
  done <<<"$block"
  if [[ $block != *'[ALPM] transaction completed'* ]]; then
    warn "pacman transaction has no completion record (${when})"; tbad=1
  fi
  if [[ ( $block == *'Updating linux initcpios'* || $block == *'==> Building'* ) &&
        $block != *'Initcpio image generation successful'* ]]; then
    warn "initramfs was rebuilt but never reported success (${when}) — check before rebooting"; tbad=1
  fi
  ((tbad)) || ok "clean (${when})"
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
    elif ! current=$(stat -Lc '%d:%i:%s' "$plog" 2>/dev/null) ||\
         [[ ${current%:*} != "${pacman_since%:*}" ]] ||\
         (( ${current##*:} < ${pacman_since##*:} )); then
      warn "pacman log replaced, truncated or unavailable — update coverage incomplete"
    elif ! block=$(tail -c "+$(( ${pacman_since##*:} + 1 ))" "$plog" 2>/dev/null); then
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
      if ! after=$(stat -Lc '%d:%i:%s' "$plog" 2>/dev/null) ||\
         [[ ${after%:*} != "${current%:*}" ]] || (( ${after##*:} < ${current##*:} )); then
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
