#!/bin/bash
# install-root.sh — system configs that live outside $HOME and need root.
# Kept separate so the main install.sh never needs sudo.
#
#   Usage:  sudo bash install-root.sh
#   Run it AFTER install.sh.

set -e

if [ "$(id -u)" -ne 0 ]; then
  echo "This installs root-owned files. Run it with sudo:" >&2
  echo "  sudo bash install-root.sh" >&2
  exit 1
fi

# Resolve DOTFILES for the invoking user (HOME is /root under sudo).
if [ -n "${SUDO_USER}" ]; then
  user_home="$(getent passwd "${SUDO_USER}" | cut -d: -f6)"
  : "${DOTFILES:=${user_home}/dotfiles}"
else
  : "${DOTFILES:=${HOME}/dotfiles}"
fi

echo "🔐 Installing system (root) configs from ${DOTFILES}..."

# --- /etc/pam.d/swaylock : fingerprint + password unlock for the lock screen ---
# Copied, never symlinked: a PAM auth file must not point at a user-writable path.
if ! cmp -s "${DOTFILES}/pam/swaylock" /etc/pam.d/swaylock 2>/dev/null; then
  [ -f /etc/pam.d/swaylock ] && cp -a /etc/pam.d/swaylock /etc/pam.d/swaylock.bak
  install -m 0644 -o root -g root "${DOTFILES}/pam/swaylock" /etc/pam.d/swaylock
  echo "  /etc/pam.d/swaylock installed (previous saved as .bak)"
else
  echo "  /etc/pam.d/swaylock already up to date"
fi

# --- /usr/lib/systemd/system-sleep/* : suspend/resume hooks ---
# Must be executable (0755). System-sleep scripts run as root on suspend/resume.
#   restart-swayidle — heal swayidle after resume
#   fix-wifi.sh      — cycle ath11k_pci around suspend; the QCNFA765 does not
#                      reliably come back without it. Load-bearing: without this
#                      hook WiFi is dead after every resume until a manual reload.
for hook in restart-swayidle fix-wifi.sh; do
  sleep_hook="/usr/lib/systemd/system-sleep/${hook}"
  if ! cmp -s "${DOTFILES}/system-sleep/${hook}" "$sleep_hook" 2>/dev/null; then
    install -D -m 0755 -o root -g root "${DOTFILES}/system-sleep/${hook}" "$sleep_hook"
    echo "  ${sleep_hook} installed"
  else
    echo "  ${sleep_hook} already up to date"
  fi
done

# --- /etc/sysctl.d/99-performance.conf : kernel tunables ---
# Copied like the rest: sysctl.d reads at boot, before $HOME is guaranteed mounted.
if ! cmp -s "${DOTFILES}/sysctl/99-performance.conf" /etc/sysctl.d/99-performance.conf 2>/dev/null; then
  install -D -m 0644 -o root -g root \
    "${DOTFILES}/sysctl/99-performance.conf" /etc/sysctl.d/99-performance.conf
  sysctl --system >/dev/null
  echo "  /etc/sysctl.d/99-performance.conf installed and applied"
else
  echo "  /etc/sysctl.d/99-performance.conf already up to date"
fi

# --- /var/lib/docker : podman's graphroot, on the @docker subvolume ---
# fstab mounts @docker here root-owned, but podman runs rootless and cannot use a graphroot it
# does not own. Without this a fresh install silently falls back to ~/.local/share/containers,
# putting image layers on @home — the thing @docker exists to prevent. The directory name is
# legacy: Docker was removed 2026-09-02, the subvolume was kept.
if [ -d /var/lib/docker ]; then
  target_user="${SUDO_USER:-root}"
  if [ "$(stat -c '%U' /var/lib/docker)" != "$target_user" ]; then
    chown "${target_user}:${target_user}" /var/lib/docker
    chmod 700 /var/lib/docker
    echo "  /var/lib/docker handed to ${target_user} (podman graphroot)"
  else
    echo "  /var/lib/docker already owned by ${target_user}"
  fi
fi

echo "✅ Root configs installed"
