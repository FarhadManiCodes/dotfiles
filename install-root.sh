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
#   unblock-fuse     — release tasks wedged in an unanswered FUSE request, which
#                      the freezer cannot freeze and SIGKILL cannot reach. Without
#                      it one stuck process on an rclone mount turns a lid-close
#                      into an all-night suspend-retry storm (2026-09-02).
for hook in unblock-fuse; do
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

# --- etc/ : the tree mirroring /etc, installed path-for-path ---
# Everything under etc/ lands at the same path below /etc. These are files owned
# by no package (except nftables.conf, see etc/README.md) and hand-written, which
# makes each one a rebuild hazard: a fresh install silently comes up without it.
# That trap has now caught fix-wifi.sh, 99-performance.conf, the zsh plugin list
# and zram-generator.conf, so the fix here is a loop rather than another block.
#
# 0644 root:root throughout -- none of these is an executable, and the one
# directory that runs what it finds (system-sleep) is handled separately above.
if [ -d "${DOTFILES}/etc" ]; then
  find "${DOTFILES}/etc" -type f ! -name README.md | while read -r src; do
    dest="/etc${src#${DOTFILES}/etc}"
    if ! cmp -s "$src" "$dest" 2>/dev/null; then
      install -D -m 0644 -o root -g root "$src" "$dest"
      echo "  ${dest} installed"
    else
      echo "  ${dest} already up to date"
    fi
  done
fi

# --- /etc/systemd/zram-generator.conf : compressed swap in RAM ---
# Copied, not symlinked: read at boot by systemd's generator, before $HOME is
# guaranteed. This is the only swap on the machine, and the file is owned by no
# package -- without it a fresh install silently comes up with no swap.
if ! cmp -s "${DOTFILES}/zram/zram-generator.conf" /etc/systemd/zram-generator.conf 2>/dev/null; then
  install -D -m 0644 -o root -g root \
    "${DOTFILES}/zram/zram-generator.conf" /etc/systemd/zram-generator.conf
  echo "  /etc/systemd/zram-generator.conf installed (active after reboot)"
else
  echo "  /etc/systemd/zram-generator.conf already up to date"
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

# --- verify: installed but inert? ---
# `cmp` compares content, never permissions, so a copied executable that has lost
# its +x reports "already up to date" forever while systemd-sleep silently skips
# it -- systemd only runs executables. That is the same shape as the
# restart-swayidle hook, which sat installed and dead through 1002 resumes.
#
# This warns rather than repairs on purpose: a hook is sometimes made
# non-executable deliberately, to disable it without deleting it (that is how
# fix-wifi.sh was held out of the way while it was being tested). Silently
# re-enabling would overrule a decision the operator made on purpose. Say so and
# let them choose.
for f in /usr/lib/systemd/system-sleep/*; do
  [ -e "$f" ] || continue
  case "${f##*/}" in tlp) continue ;; esac   # package-owned, not ours
  if [ ! -x "$f" ]; then
    echo "  ⚠ $f is NOT executable — systemd-sleep will skip it."
    echo "    Deliberate? leave it. Otherwise: sudo chmod +x $f"
  fi
done

echo "✅ Root configs installed"
