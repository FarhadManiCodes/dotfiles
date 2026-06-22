# sysup - full system + tooling update
#
# Order: pacman/AUR (paru) -> mirror llama.cpp-vulkan PKGBUILD backup -> uv
# tools -> Claude Code.
#
# No npm step: there are no user npm globals, and system node/npm are pacman
# packages already covered by paru -Syu above.
#
# The backup step runs right after paru because that's when paru's SaveChanges
# rebases the local llama.cpp-vulkan patch onto the new upstream version; we
# mirror the result into dotfiles so a cache wipe / fresh machine can't lose the
# patch (see dotfiles/aur/llama.cpp-vulkan/README.md).

sysup() {
  echo "==> System & AUR (paru -Syu)"
  paru -Syu || { echo "!! paru failed — stopping sysup"; return 1; }

  echo "==> llama.cpp-vulkan PKGBUILD backup"
  _sysup_sync_llama_pkgbuild

  echo "==> uv tools"
  uv tool upgrade --all

  echo "==> Claude Code"
  claude update
  _sysup_prune_claude_versions

  echo "==> sysup done"
}

# Keep only the current Claude version plus the single newest older one. The
# native installer drops a new ~223 MB binary per update and never prunes the
# superseded ones, so they pile up in ~/.local/share/claude/versions.
_sysup_prune_claude_versions() {
  local dir="$HOME/.local/share/claude/versions"
  [[ -d "$dir" ]] || return 0

  local current=$(readlink -f "$HOME/.local/bin/claude")
  current=${current:t}

  # Keep the current version, plus the newest of the rest (one old fallback).
  local -a versions=("${(@f)$(ls -t "$dir")}") keep=("$current")
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
}

# Mirror the rebased PKGBUILD from the paru cache clone into the tracked dotfiles
# backup. Idempotent: only copies when changed, and reports what it did.
_sysup_sync_llama_pkgbuild() {
  local clone="$HOME/.cache/paru/clone/llama.cpp-vulkan"
  local dest="${DOTFILES:-$HOME/dotfiles}/aur/llama.cpp-vulkan"

  if [[ ! -f "$clone/PKGBUILD" || ! -d "$dest" ]]; then
    echo "   skipped (clone or dotfiles backup not found)"
    return 0
  fi

  local ver
  ver=$(grep '^pkgver=' "$clone/PKGBUILD" | cut -d= -f2)

  if diff -q "$clone/PKGBUILD" "$dest/PKGBUILD" >/dev/null 2>&1; then
    echo "   up to date (${ver}) — backup unchanged"
  else
    cp "$clone/PKGBUILD" "$dest/PKGBUILD"
    git -C "$clone" show HEAD -- PKGBUILD > "$dest/no-webui.patch" 2>/dev/null
    echo "   updated backup -> ${ver}  (review & commit in dotfiles)"
  fi
}
