# sysup - full system + tooling update
#
# Order: pacman/AUR (paru) -> uv tools -> Claude Code.
#
# No npm step: there are no user npm globals, and system node/npm are pacman
# packages already covered by paru -Syu above.

sysup() {
  echo "==> System & AUR (paru -Syu)"
  paru -Syu || { echo "!! paru failed — stopping sysup"; return 1; }

  echo "==> uv tools"
  uv tool upgrade --all

  echo "==> Claude Code"
  claude update
  _sysup_prune_claude_versions

  echo "==> sysup done"
}

# Keep only the current Claude version plus the single newest older one. The
# native updater only prunes its own *.tmp.* partial downloads, stale locks, and
# orphaned staging dirs (tengu_native_staging_cleanup) — it never removes
# superseded ~223 MB release binaries, so they pile up in
# ~/.local/share/claude/versions.
_sysup_prune_claude_versions() {
  local dir="$HOME/.local/share/claude/versions"
  [[ -d "$dir" ]] || return 0

  local current=$(readlink -f "$HOME/.local/bin/claude")
  current=${current:t}

  # Only completed release binaries (e.g. 2.1.185), newest first. Skip the
  # native updater's *.tmp.* partials — counting those made every run report a
  # prune even when nothing changed, and they clean themselves up.
  local -a versions=("${(@M)${(@f)$(command ls -t "$dir")}:#<->.<->.<->}")

  # Keep the current version, plus the newest of the rest (one old fallback).
  local -a keep=("$current")
  local v
  for v in $versions; do
    [[ "$v" == "$current" ]] && continue
    keep+=("$v")
    break
  done

  local removed=0
  for v in $versions; do
    (( ${keep[(Ie)$v]} )) && continue
    rm -rf "$dir/$v" && (( removed++ ))
  done

  (( removed )) && echo "   pruned ${removed} old Claude version(s); kept ${(j:, :)keep}"
  return 0
}


