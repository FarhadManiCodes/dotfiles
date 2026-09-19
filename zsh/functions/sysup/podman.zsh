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
