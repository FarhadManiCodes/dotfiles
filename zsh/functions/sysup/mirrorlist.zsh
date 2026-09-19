# Runs before the update — see docs/architecture/mirrorlist.md for why, and
# for the age/validity/threshold reasoning. Reports only; re-ranking is
# bash/mirrorlist-rank.
#
#   $1  days that count as stale   (default 90)
#   $2  mirrorlist to inspect      (default /etc/pacman.d/mirrorlist)
#
# `_sysup_mirrorlist_check 1` rehearses the whole warning against the real
# file without waiting a season. sysup passes neither.
_sysup_mirrorlist_check() {
  local max_age=${1:-90} ml=${2:-/etc/pacman.d/mirrorlist}
  if [[ ! -r $ml ]]; then
    echo "   $ml unreadable — not checked"
    return 0
  fi

  local age servers
  age=$(( ( $(date +%s) - $(stat -Lc %Y "$ml") ) / 86400 ))
  servers=$(grep -c '^[[:space:]]*Server[[:space:]]*=' "$ml")

  if (( servers == 0 )); then
    echo "   ⚠ no active Server line — pacman has no mirror to use"
    return 0
  fi
  local stale=0
  if (( age > max_age )); then
    echo "   ⚠ last re-ranked ${age} days ago (${servers} servers)"
    stale=1
  else
    echo "   ${servers} servers, last re-ranked ${age} days ago"
  fi

  command -v jq >/dev/null 2>&1 || { echo "   jq missing — mirror validity NOT checked"; return 0 }
  local report
  if ! report=$(curl -fsS --max-time 8 https://archlinux.org/mirrors/status/json/ 2>/dev/null) ||
     [[ -z $report ]]; then
    echo "   archlinux.org unreachable — mirror validity NOT checked"
    return 0
  fi

  # Strip $repo/os/$arch so Server lines match Arch's per-mirror base urls.
  # Threshold reasoning (0.95 completion, 86400s delay) is in
  # docs/architecture/mirrorlist.md.
  local -a urls
  urls=(${(f)"$(sed -n 's/^[[:space:]]*Server[[:space:]]*=[[:space:]]*//p' "$ml" | sed 's/\$repo.*//')"})

  local problems
  problems=$(print -r -- "$report" | jq -r --args '
    (.urls | INDEX(.url)) as $m
    | $ARGS.positional[] as $u
    | ($m[$u]) as $e
    | if   $e == null                    then "\($u) — no longer on the Arch mirror list"
      elif ($e.active | not)             then "\($u) — marked inactive by Arch"
      elif ($e.completion_pct // 0) < 0.95 then "\($u) — failed \((((1 - ($e.completion_pct // 0)) * 96)|round)) of the last 96 mirror checks"
      elif ($e.delay // 0) > 86400       then "\($u) — \((($e.delay // 0)/3600)|floor) h behind upstream"
      else empty end' -- $urls)

  if [[ -n $problems ]]; then
    local -a bad=(${(f)problems})
    echo "   ⚠ ${#bad} of ${servers} mirrors need attention:"
    printf '        %s\n' "${bad[@]}"
  else
    echo "   all ${servers} still listed, active and in sync"
  fi

  # Offer the fix rather than printing it (docs/architecture/mirrorlist.md).
  # Real measurement (downloads from every candidate), so never automatic.
  (( stale )) || [[ -n $problems ]] || return 0
  if [[ $ml != /etc/pacman.d/mirrorlist ]]; then
    echo "        fix: mirrorlist-rank --install   (not offered — this was a copy, not the live list)"
    return 0
  fi
  if ! command -v mirrorlist-rank >/dev/null 2>&1; then
    echo "        fix: mirrorlist-rank --install   (not on PATH — see bash/mirrorlist-rank)"
    return 0
  fi
  if [[ ! -t 0 ]]; then
    echo "        fix: mirrorlist-rank --install"
    return 0
  fi
  local reply=""
  read -q "reply?   re-rank now? it times every candidate mirror, about 20 s [y/N] " || true
  echo
  if [[ $reply == y ]]; then
    mirrorlist-rank --install
  else
    echo "        left alone — 'mirrorlist-rank' ranks and reports what would change"
    echo "        without writing anything; add --install to apply it"
  fi
  return 0
}
