# sysup - full system + tooling update
#
# Order: pacman/AUR (paru) -> uv tools -> Claude Code -> editor/shell plugins ->
# container images -> fwupd metadata (if stale).
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

  echo "==> Editor & shell plugins"
  _sysup_plugins

  echo "==> Container images (podman)"
  _sysup_podman_images

  echo "==> Firmware metadata (fwupd)"
  _sysup_fwupd_refresh_if_stale

  echo "==> sysup done"
}

# Three plugin ecosystems, each with its own updater and none of them automatic, so they simply
# never ran: the tmux clones sat at 2023-2024 against upstreams pushed in 2026. Missing plugins
# fail silently (.zshrc guards each source with [[ -f ]], vim just lacks the feature), so nothing
# ever surfaced the staleness. Failures here are reported but never fatal -- a plugin repo being
# unreachable must not stop a system update.
_sysup_plugins() {
  local zsh_updater="${XDG_CONFIG_HOME:-$HOME/.config}/zsh/update-plugins.sh"
  if [[ -x "$zsh_updater" ]]; then
    "$zsh_updater" || echo "   ⚠ zsh plugins: some failed"
  else
    echo "   zsh: $zsh_updater not found — skipping"
  fi

  # tpm's own bin/update_plugins works without a running server (its header says so),
  # so this does not need a tmux session attached.
  local tpm="${XDG_CONFIG_HOME:-$HOME/.config}/tmux/plugins/tpm/bin/update_plugins"
  if [[ -x "$tpm" ]]; then
    echo "   tmux plugins..."
    "$tpm" all >/dev/null || echo "   ⚠ tmux plugins: some failed"
  else
    echo "   tmux: tpm not installed — skipping"
  fi

  # vim-plug needs a terminal: `vim +PlugUpdate +qall` exits 1 with no tty (verified),
  # 0 with one. sysup is always interactive -- paru prompts -- so this is fine here, but
  # it is why the step fails if sysup is ever driven from a script or timer.
  if command -v vim >/dev/null 2>&1 && [[ -f "$HOME/.vim/autoload/plug.vim" ]]; then
    echo "   vim plugins..."
    vim +PlugUpdate +qall >/dev/null 2>&1 || echo "   ⚠ vim plugins: PlugUpdate failed"
  else
    echo "   vim: vim-plug not installed — skipping"
  fi
}

# Quadlet units deliberately carry no AutoUpdate= — an unattended postgres major bump needs
# pg_upgrade and would fail against an older data directory. But nothing else refreshes these
# images either, so without this step a container silently runs whatever was pulled the day it
# was created. Tags here pin the major version, so a pull only ever brings minor/patch updates.
# Restarts the owning systemd unit rather than the container, since Quadlet owns the lifecycle.
_sysup_podman_images() {
  command -v podman >/dev/null 2>&1 || { echo "   podman not installed — skipping"; return 0; }

  local img before after unit changed=0
  for img in ${(f)"$(podman ps --format '{{.Image}}' 2>/dev/null | sort -u)"}; do
    [[ -n $img ]] || continue
    before=$(podman image inspect "$img" --format '{{.Digest}}' 2>/dev/null)
    podman pull -q "$img" >/dev/null 2>&1 || { echo "   $img: pull failed"; continue; }
    after=$(podman image inspect "$img" --format '{{.Digest}}' 2>/dev/null)
    if [[ $before != $after ]]; then
      echo "   $img: updated"
      changed=1
    else
      echo "   $img: current"
    fi
  done

  (( changed )) || return 0

  # Restart every running Quadlet-generated unit so the new layers are actually in use;
  # a pull alone changes nothing until the container is recreated.
  for unit in ${(f)"$(systemctl --user list-units --state=running --no-legend --no-pager 2>/dev/null | awk '{print $1}')"}; do
    [[ -f ${XDG_CONFIG_HOME:-$HOME/.config}/containers/systemd/${unit%.service}.container ]] || continue
    echo "   restarting $unit"
    systemctl --user restart "$unit"
  done
}

# fwupd's lvfs metadata is timestamped by its own cache file; refresh only if
# it's missing or older than ~3 months, so sysup doesn't prompt for sudo every run.
_sysup_fwupd_refresh_if_stale() {
  local meta="/var/lib/fwupd/metadata/lvfs/firmware.xml.zst"
  if [[ ! -f "$meta" ]] || [[ -n $(find "$meta" -mtime +90 2>/dev/null) ]]; then
    echo "   last refresh >3 months ago (or never) — running sudo fwupdmgr refresh"
    sudo fwupdmgr refresh
  else
    echo "   refreshed within the last 3 months, skipping"
  fi
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


