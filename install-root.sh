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

echo "✅ Root configs installed"
