# sysup - full system + tooling update
#
# Order: pacman/AUR (paru) -> mirror llama.cpp-vulkan PKGBUILD backup -> uv
# tools -> global npm packages -> Claude Code.
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

  echo "==> npm globals"
  if npm outdated -g --parseable 2>/dev/null | grep -q .; then
    npm update -g
  else
    echo "   nothing to update"
  fi

  echo "==> Claude Code"
  claude update

  echo "==> sysup done"
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
