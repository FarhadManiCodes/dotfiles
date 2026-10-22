# Git installs are skipped by cargo install-update --all. Use the stable-tag
# helper and its recorded build recipe; update-only mode skips absent installs.
_sysup_herdr() (
  emulate -L zsh
  trap - EXIT INT TERM
  [[ -z ${_lockfd:-} ]] || exec {_lockfd}>&- # a leftover child must not keep sysup's lock held
  local helper=${1:-"${${(%):-%x}:A:h}/../../../bash/herdr-cargo"}
  bash "$helper" --update
)
