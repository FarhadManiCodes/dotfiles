# shellcheck shell=bash
# shellcheck disable=SC2088  # "~" in messages is display text, never expanded
# The custom sioyek build (sioyek/README.md) is outside pacman, so nothing tells
# you when a system update leaves it behind. On 2026-10-08 qt6-base went 6.11 ->
# 6.12 and every PDF opened blank: Qt 6.12's applicationDirPath() stopped
# resolving the ~/.local/bin/sioyek symlink, so sioyek looked for shaders/ and
# prefs.config in ~/.local/bin. Two checks guard against that class of failure:
#
#   - ~/.local/bin/sioyek must be the exec wrapper install.sh writes, not a link.
#   - The binary's qt_version_tag (the Qt minor it was compiled against) must
#     match the installed qt6-base. A minor bump is when Qt changes behaviour;
#     rebuild with the recipe in ~/Installs/sioyek/UPDATING.md.
check_sioyek_build() {
  hdr "Custom sioyek build"
  local bin=${XDG_DATA_HOME:-$HOME/.local/share}/sioyek/sioyek
  local launcher=$HOME/.local/bin/sioyek built installed ybad=0
  if [[ ! -x $bin ]]; then
    skip "not built (${bin/#$HOME/\~} missing)"; return
  fi
  if [[ -L $launcher ]]; then
    warn "~/.local/bin/sioyek is a symlink — sioyek then finds no shaders and renders blank pages; rerun install.sh"; ybad=1
  elif [[ ! -x $launcher ]] || ! grep -qF "exec \"$bin\"" "$launcher" 2>/dev/null; then
    warn "~/.local/bin/sioyek is missing or not the exec wrapper — rerun install.sh"; ybad=1
  fi
  built=$(readelf --dyn-syms -W "$bin" 2>/dev/null | grep -om1 'qt_version_tag@Qt_[0-9.]*')
  built=${built#*@Qt_}
  installed=$(pacman -Q qt6-base 2>/dev/null | awk '{split($2, v, "."); print v[1] "." v[2]}')
  if [[ -z $built || -z $installed ]]; then
    skip "Qt version not compared (readelf or pacman gave nothing)"; return
  fi
  if [[ $built != "$installed" ]]; then
    warn "sioyek built against Qt $built but qt6-base is $installed — rebuild (~/Installs/sioyek/UPDATING.md)"; ybad=1
  fi
  ((ybad)) || ok "wrapper in place; built against the installed Qt $installed"
}
