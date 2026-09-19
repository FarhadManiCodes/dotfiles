#!/bin/bash
# Updated install.sh for XDG-compliant zsh setup
# provide default values for environment variable if not defined
: "${XDG_CONFIG_HOME:=${HOME}/.config}"
: "${DOTFILES:=${HOME}/dotfiles}"
: "${XDG_DATA_HOME:=${HOME}/.local/share}"

# Symlink every file matching one or more globs into a directory (created if
# missing). The destination is the last argument. A glob with no matches
# stays literal, hence the existence check.
link_glob() {
  local dest=${*: -1}
  mkdir -p "$dest"
  for file in "${@:1:$#-1}"; do
    [ -e "$file" ] || continue
    ln -sf "$file" "$dest/"
  done
}

echo "🚀 Installing dotfiles..."

# =========== vim ===============
echo "Setting up Vim..."

# Bootstrap ~/.vimrc to redirect vim to the XDG config location
cat > "${HOME}/.vimrc" << 'VIMRC'
" XDG Base Directory Specification compliance
" This file sources the actual vimrc from ~/.config/vim/vimrc
let $MYVIMRC = expand('~/.config/vim/vimrc')
if filereadable($MYVIMRC)
    source $MYVIMRC
else
    echoerr "Could not find vimrc at ~/.config/vim/vimrc"
endif
VIMRC

# Symlink entire vim config directory. This is the first section to write into
# XDG_CONFIG_HOME, so create it here — on a genuinely fresh machine ~/.config
# does not exist yet and this symlink silently failed.
mkdir -p "${XDG_CONFIG_HOME}"
ln -snf "${DOTFILES}/vim" "${XDG_CONFIG_HOME}/vim"
echo "Vim configured"

# ============ zsh ==============================
echo "🐚 Setting up Zsh..."
mkdir -p "${HOME}/.config/zsh"
ln -sf "${DOTFILES}/zsh/.zshenv" "${HOME}/.zshenv"
ln -sf "${DOTFILES}/zsh/.zshrc" "${HOME}/.zshrc"

mkdir -p "${XDG_CONFIG_HOME}/zsh/functions"
ln -sf "${DOTFILES}/zsh/aliases"               "${XDG_CONFIG_HOME}/zsh/aliases"
ln -sf "${DOTFILES}/zsh/helpers.zsh"           "${XDG_CONFIG_HOME}/zsh/helpers.zsh"
ln -sf "${DOTFILES}/zsh/generate-completions.sh" "${XDG_CONFIG_HOME}/zsh/generate-completions.sh"
ln -sf "${DOTFILES}/zsh/update-plugins.sh"    "${XDG_CONFIG_HOME}/zsh/update-plugins.sh"

link_glob "${DOTFILES}/zsh/functions/"*.zsh "${XDG_CONFIG_HOME}/zsh/functions"

# Completions — generate if tools are available
mkdir -p "${XDG_CONFIG_HOME}/zsh/completions"
command -v gh      >/dev/null 2>&1 && gh completion -s zsh      > "${XDG_CONFIG_HOME}/zsh/completions/_gh"      2>/dev/null || true
command -v uv      >/dev/null 2>&1 && uv  generate-shell-completion zsh > "${XDG_CONFIG_HOME}/zsh/completions/_uv" 2>/dev/null || true
command -v podman  >/dev/null 2>&1 && podman completion zsh      > "${XDG_CONFIG_HOME}/zsh/completions/_podman"  2>/dev/null || true

echo "Zsh configured"

# ============ tmux ==============================
echo "🖥️  Setting up Tmux..."
mkdir -p "$XDG_CONFIG_HOME/tmux"
ln -sf "${DOTFILES}/tmux/tmux.conf" "${XDG_CONFIG_HOME}/tmux/tmux.conf"
link_glob "${DOTFILES}/tmux/layouts/"*.sh "${XDG_CONFIG_HOME}/tmux/layouts"
echo "✅ Tmux configured"

# ============ nvim ==============================
echo "Setting up Neovim..."
git submodule update --init --recursive
rm -rf "${XDG_CONFIG_HOME}/nvim"
ln -snf "${DOTFILES}/nvim" "${XDG_CONFIG_HOME}/nvim"
echo "Neovim configured"

# ============ ipython ==============================
# IPYTHONDIR is set to ~/.config/ipython in zsh/.zshenv, so the profile lives
# here rather than in ~/.ipython. history.sqlite is deliberately not tracked --
# it is state, and it is the only other thing in the profile.
echo "🐍 Setting up ipython..."
mkdir -p "${XDG_CONFIG_HOME}/ipython/profile_default/startup"
ln -sf "${DOTFILES}/ipython/profile_default/ipython_config.py" \
       "${XDG_CONFIG_HOME}/ipython/profile_default/ipython_config.py"
link_glob "${DOTFILES}"/ipython/profile_default/startup/*.py "${XDG_CONFIG_HOME}/ipython/profile_default/startup"
echo "✅ ipython configured"

# ============ single-file app configs ==============================
# Everything below has one file (or a small fixed set) at the same relative
# path in the repo and under XDG_CONFIG_HOME — nothing here needs anything
# beyond mkdir + ln, so it is a data list instead of one stanza per app.
# Apps that need extra logic (a template, a glob, a non-default target) keep
# their own section below this loop.
echo "Setting up single-file app configs..."
simple_configs=(
  ptpython/config.py
  niri/config.kdl
  environment.d/defaults.conf
  environment.d/wayland.conf
  paru/paru.conf
  # NOTE: /etc/pam.d/swaylock (fingerprint + password unlock) is root-owned
  # and installed separately by install-root.sh.
  swaylock/config
  glow/glow.yml
  mpv/mpv.conf
  yt-dlp/config
  cmus/rc
  direnv/direnvrc
  uv/uv.toml
  gh/config.yml
  # ripgrep-all is not configured here: rga writes its own config.jsonc (and
  # schema) on first run, and every adapter we want is enabled by default.
  #
  # neocmakelsp: the trailing "-" in its [format] args is load-bearing --
  # gersemi with no file operand exits 0 printing nothing, which neocmakelsp
  # applies as a successful empty format and blanks the buffer. See the
  # comments in the file itself.
  neocmakelsp/config.toml
  mako/config
  vifm/vifmrc
  vifm/colors/catppuccin-mocha.vifm
  vifm/colors/zenburn-rich.vifm
  tridactyl/tridactylrc
  fuzzel/fuzzel.ini
  bat/config
  btop/btop.conf
  starship.toml
  foot/foot.ini
  git/config
  git/ignore
  lazygit/config.yml
  zathura/zathurarc
  sioyek/prefs_user.config
  sioyek/keys_user.config
  vimb/config
  clangd/config.yaml
  spotify-player/theme.toml
  handlr/handlr.toml
  ccache/ccache.conf
  # GTK appearance is not configured here: the xdg-desktop-portal Settings
  # interface overrides gtk-{3,4}.0/settings.ini for every key it serves
  # (font-name, gtk-theme, icon-theme, cursor-theme). Use dconf instead.
  wob/wob.ini
  latexmk/latexmkrc
  mimeapps.list
  papis/config
)
for rel in "${simple_configs[@]}"; do
  mkdir -p "${XDG_CONFIG_HOME}/$(dirname "$rel")"
  ln -sf "${DOTFILES}/${rel}" "${XDG_CONFIG_HOME}/${rel}"
  echo "  $rel"
done
echo "Single-file app configs installed"

# git/config.local is per-machine identity, never overwritten once created.
if [[ ! -f "${XDG_CONFIG_HOME}/git/config.local" ]]; then
    cat > "${XDG_CONFIG_HOME}/git/config.local" << 'GITLOCAL'
[user]
    name = Your Name
    email = you@example.com
GITLOCAL
    echo "Created git/config.local template -- fill in your name and email"
fi

# spotify-player/app.toml holds a per-machine client_id, never overwritten
# once created (unlike theme.toml above, which is a plain symlink).
if [[ ! -f "${XDG_CONFIG_HOME}/spotify-player/app.toml" ]]; then
    cp "${DOTFILES}/spotify-player/app.toml" "${XDG_CONFIG_HOME}/spotify-player/app.toml"
    echo "Created spotify-player/app.toml template -- fill in your client_id"
fi

# ============ pcmanfm-qt ==============================
echo "Setting up pcmanfm-qt..."
mkdir -p "${XDG_CONFIG_HOME}/pcmanfm-qt/default"
ln -sf "${DOTFILES}/pcmanfm-qt/settings.conf" "${XDG_CONFIG_HOME}/pcmanfm-qt/default/settings.conf"
ln -sf "${DOTFILES}/pcmanfm-qt/bookmarks.xml"  "${XDG_CONFIG_HOME}/pcmanfm-qt/default/bookmarks.xml"
echo "pcmanfm-qt configured"

# ============ foliate ==============================
echo "Setting up Foliate..."
link_glob "${DOTFILES}/foliate/themes/"*.json "${XDG_CONFIG_HOME}/com.github.johnfactotum.Foliate/themes"
dconf load /com/github/johnfactotum/Foliate/ < "${DOTFILES}/foliate/settings.dconf"
echo "Foliate configured"

# ============ xdg user dirs ==============================
echo "Setting up XDG user dirs..."
ln -sf "${DOTFILES}/xdg/user-dirs.dirs" "${XDG_CONFIG_HOME}/user-dirs.dirs"

# Create the folders ourselves instead of calling xdg-user-dirs-update: when a
# listed folder is missing it rewrites user-dirs.dirs via rename(), which
# replaces the symlink above with a plain file. Mask the login-time unit for
# the same reason — the file is ours, nothing else may write it.
(
  # shellcheck source=xdg/user-dirs.dirs
  . "${DOTFILES}/xdg/user-dirs.dirs"
  for var in $(compgen -A variable XDG_ | grep '_DIR$'); do
    mkdir -p "${!var}"
  done
)
systemctl --user mask xdg-user-dirs.service >/dev/null 2>&1
echo "XDG user dirs configured"

# ============ desktop files ==============================
echo "Setting up desktop files..."
link_glob "${DOTFILES}/applications/"*.desktop "${HOME}/.local/share/applications"
update-desktop-database "${HOME}/.local/share/applications/"
echo "Desktop files configured"

# ============ firefox ==============================
echo "Setting up Firefox userChrome..."
FIREFOX_PROFILE=$(awk -F= '/^\[Install/{in_install=1} in_install && /^Default=/{print $2; in_install=0}' "${HOME}/.mozilla/firefox/profiles.ini" 2>/dev/null)
if [[ -n "$FIREFOX_PROFILE" ]]; then
    CHROME_DIR="${HOME}/.mozilla/firefox/${FIREFOX_PROFILE}/chrome"
    mkdir -p "$CHROME_DIR"
    ln -sf "${DOTFILES}/firefox/userChrome.css" "${CHROME_DIR}/userChrome.css"
    echo "Firefox userChrome configured (profile: ${FIREFOX_PROFILE})"
else
    echo "Firefox default profile not found, skipping (install Firefox and run install.sh again)"
fi

# =========== duckdb ===============
echo "Setting up DuckDB..."
ln -sf "${DOTFILES}/duckdb/.duckdbrc" "${HOME}/.duckdbrc"
echo "DuckDB configured"

# No font step: the fonts in use (FiraCode Nerd Font, JetBrains Mono) come from
# packages. This used to copy 15MB of unreferenced Inconsolata/MesloLGS without
# running fc-cache, so fontconfig never saw them anyway.

# ============ audio directory ==============================
mkdir -p "${HOME}/Audio/Recordings"

# ============ helper scripts ==============================
echo "🛠️  Installing helper scripts..."
link_glob "${DOTFILES}/bash/"* "${HOME}/.local/bin"
echo "✅ Helper scripts installed"

# ============ ssh client config ===================================
# ~/.ssh must stay 0700 or ssh refuses to use it.
echo "🔑 Installing ssh config..."
mkdir -p "${HOME}/.ssh"
chmod 700 "${HOME}/.ssh"
ln -sf "${DOTFILES}/ssh/config" "${HOME}/.ssh/config"

# ============ podman (rootless containers) ========================
# Quadlet .container/.network files generate systemd user units at daemon-reload.
# No sudo anywhere: rootless podman is entirely user-scoped, which is the point.
echo "📦 Installing podman configs..."
mkdir -p "${XDG_CONFIG_HOME}/containers/systemd"
for conf in containers.conf storage.conf; do
  ln -sf "${DOTFILES}/containers/${conf}" "${XDG_CONFIG_HOME}/containers/${conf}"
done
link_glob "${DOTFILES}/containers/"*.container "${DOTFILES}/containers/"*.network "${XDG_CONFIG_HOME}/containers/systemd"

# ============ systemd user services ==============================
echo "⚙️  Installing systemd user services..."
link_glob "${DOTFILES}/systemd/user/"*.service "${DOTFILES}/systemd/user/"*.timer "${DOTFILES}/systemd/user/"*.socket "${HOME}/.config/systemd/user"
systemctl --user daemon-reload

# Enable explicitly rather than globbing (idempotent). A glob gets this wrong in
# two ways: `enable rclone@.service` fails because a template cannot be enabled,
# and the instances we actually mount are never enabled.
units_to_enable=(
  battery-watch.service
  mic-notify.service
  net-notify.service
  power-notify.service
  swayidle.service
  rclone@gdrive.service
  rclone@Dropbox.service
  # shpool is socket-activated: enabling the socket is enough, and avoids
  # keeping the daemon running until a client actually needs it.
  shpool.socket
  # The *user* podman socket, which docker-compose reaches via DOCKER_HOST
  # (see environment.d/defaults.conf). Without this a fresh install has
  # DOCKER_HOST pointing at a socket nothing ever creates, and compose fails
  # with no obvious cause. Never enable the system-wide podman.socket
  # instead — that one is root-owned.
  podman.socket
  # ssh-agent, so a passphrase-protected key is typed once an hour rather
  # than every push. Socket-activated: enabling the socket is enough, the
  # service starts on first use.
  ssh-agent.socket
)
for unit in "${units_to_enable[@]}"; do
  systemctl --user enable "$unit" 2>/dev/null || true
done
echo "✅ Systemd user services installed and enabled"

# ---------------------------------------------------------------- agent skills ----
# User-scoped rather than project-scoped on purpose. These are machine procedures --
# wanted when the laptop misbehaved, or while working in some other repository, from
# whatever directory you happen to be in. Project scope would silently fail to load
# anywhere outside ~/dotfiles, with nothing to say it had not loaded.
#
# The symlink is what makes a branch switch visible: on a branch without the skill this
# dangles, and config-drift reports it. Project scope would leave no trace at all.
#
# Linked into BOTH trees during the Codex coexistence period. docs/codex-migration.md
# names ~/.agents/skills as the Codex-side discovery path and says to keep the Claude
# links while both are in use; installing only one half is how a skill ends up working
# in one agent and silently missing in the other.
for agent_dir in "${HOME}/.claude/skills" "${HOME}/.agents/skills"; do
  mkdir -p "$agent_dir"
  for skill in "${DOTFILES}"/skills/*/; do
    [ -d "$skill" ] || continue
    ln -sfn "${skill%/}" "${agent_dir}/$(basename "$skill")"
  done
done
echo "✅ Agent skills linked into ~/.claude/skills and ~/.agents/skills"

echo ""
echo "🎉 Dotfiles installation complete!"
echo ""
echo "Next steps:"
echo "  1. Install zsh plugins: ~/.config/zsh/update-plugins.sh"
echo "  2. Restart your terminal or run: source ~/.zshrc"
echo "  3. Install Vim plugins: vim +PlugInstall +qall"
echo "  4. Install tmux plugins: Prefix + I (inside a tmux session)"
# pg.service cannot start without this secret, and the only symptom is a failed unit.
# Only prompt when it is actually missing, so a re-run of install.sh stays quiet.
if command -v podman >/dev/null 2>&1 && ! podman secret exists pg_password 2>/dev/null; then
  echo "  5. Create the Postgres password (pg.service will not start without it):"
  echo "       podman secret create pg_password -      # type it, then Ctrl-D"
fi
echo ""
echo "🔐 System (root) configs are installed separately:"
echo "  sudo bash install-root.sh   - e.g. /etc/pam.d/swaylock (lock-screen auth)"
