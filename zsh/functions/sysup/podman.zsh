# Quadlet units deliberately carry no AutoUpdate= — a postgres major bump needs pg_upgrade.
# Invoked only by `sysup --podman-images`. Read installed Quadlets, including stopped ones:
# an on-demand service has no entry in `podman ps` and would otherwise never be updated.
# Restart only running units whose image changed; Quadlet owns the lifecycle.
_sysup_podman_images() {
  command -v podman >/dev/null 2>&1 || { echo "   podman not installed"; return 1; }

  local quadlet_dir="${XDG_CONFIG_HOME:-$HOME/.config}/containers/systemd"
  local -a quadlets
  quadlets=("$quadlet_dir"/*.container(N))
  (( ${#quadlets} )) || { echo "   no installed Quadlet containers"; return 0; }

  local -A seen changed
  local quadlet img before after unit state failed=0
  for quadlet in $quadlets; do
    img=$(awk '/^[[:space:]]*Image[[:space:]]*=/ {
      sub(/^[^=]*=/, ""); sub(/^[[:space:]]*/, ""); sub(/[[:space:]]*$/, ""); print; exit
    }' "$quadlet") || { echo "   ${quadlet:t}: cannot read Image="; failed=1; continue; }
    [[ -n $img ]] || continue
    [[ -z ${seen[$img]-} ]] || continue
    seen[$img]=1

    before=$(podman image inspect "$img" --format '{{.Id}}' 2>/dev/null)
    podman pull -q "$img" >/dev/null 2>&1 || { echo "   $img: pull failed"; failed=1; continue; }
    after=$(podman image inspect "$img" --format '{{.Id}}' 2>/dev/null)
    [[ -n $after ]] || { echo "   $img: cannot inspect pulled image"; failed=1; continue; }
    if [[ $before != $after ]]; then
      echo "   $img: updated"
      changed[$img]=1
    else
      echo "   $img: current"
    fi
  done

  for quadlet in $quadlets; do
    img=$(awk '/^[[:space:]]*Image[[:space:]]*=/ {
      sub(/^[^=]*=/, ""); sub(/^[[:space:]]*/, ""); sub(/[[:space:]]*$/, ""); print; exit
    }' "$quadlet") || { failed=1; continue; }
    [[ -n $img && -n ${changed[$img]-} ]] || continue
    unit="${quadlet:t:r}.service"
    state=$(systemctl --user show "$unit" -p ActiveState --value 2>/dev/null) || {
      echo "   $unit: cannot read service state"
      failed=1
      continue
    }
    [[ $state == active ]] || continue
    echo "   restarting $unit"
    systemctl --user restart "$unit" || failed=1
  done
  return $failed
}
