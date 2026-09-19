# shellcheck shell=bash
# User configs installed as links should retain their intended repo targets.
# Root copies, generated files and optional installs have separate rules. Two
# common failures:
#
#   - A branch switch removes a file the other branch has, leaving a dangling
#     link. That happened on 2026-09-03: ~/.ssh/config dangled and ssh quietly
#     fell back to AddKeysToAgent false.
#   - A program rewrites its config by writing a temp file and renaming it over
#     the original, which REPLACES the symlink with a regular file. The config
#     then silently stops being the repo's.
check_symlink_integrity() {
  hdr "Symlink integrity"
  sbad=0
  declare -A dangling_seen=()
  roots=()
  for root in "${XDG_CONFIG_HOME:-$HOME/.config}" ~/.local/bin ~/.local/share/applications ~/.ssh ~/.claude/skills ~/.agents/skills; do
    [[ -d $root ]] && roots+=("$root")
  done
  # One traversal. The old decorative link count required a second traversal
  # and a readlink subprocess for every link, without adding a correctness check.
  if ((${#roots[@]})); then
    if dangling=$(find "${roots[@]}" -maxdepth 4 -xtype l 2>/dev/null); then
      while IFS= read -r link; do
        [[ -z $link ]] && continue
        warn "dangling symlink: ${link/#$HOME/\~}"; sbad=1
        dangling_seen["$link"]=1
      done <<<"$dangling"
    else
      warn "symlink scan incomplete — cannot confirm integrity"; sbad=1
    fi
  else
    skip "no installed config directories to scan"; sbad=1
  fi
  for link in ~/.zshrc ~/.zshenv ~/.vimrc ~/.duckdbrc; do
    if [[ -L $link && ! -e $link ]]; then
      warn "dangling symlink: ${link/#$HOME/\~}"; sbad=1
      dangling_seen["$link"]=1
    fi
  done

  # Explicit installation mappings, kept in sync with install.sh. An arbitrary
  # tracked file is not necessarily installed. In particular, never treat docs,
  # generated state, root copies or Spotify's local app.toml as expected links.
  config_home=${XDG_CONFIG_HOME:-$HOME/.config}
  # -c core.fsmonitor=false: a read-only audit must not start a background daemon as
  # a side effect. Redundant while fsmonitor is off globally (git/config), and kept
  # so this holds whatever that file says later.
  if tracked=$(git -c core.fsmonitor=false -C "$df_dir" ls-files 2>/dev/null); then
    while IFS= read -r rel; do
      [[ -z $rel ]] && continue
      expected=$df_dir/$rel
      case $rel in
        zsh/.zshrc|zsh/.zshenv) livef=$HOME/${rel##*/} ;;
        duckdb/.duckdbrc) livef=$HOME/.duckdbrc ;;
        ssh/config) livef=$HOME/.ssh/config ;;
        nvim) livef=$config_home/nvim ;;
        vim/vimrc) livef=$config_home/vim; expected=$df_dir/vim ;;
        zsh/functions/sysup/*.zsh)
          # Not individually symlinked: sysup.zsh resolves these itself via
          # ${0:A:h}, straight through its own symlink to the real checkout.
          continue ;;
        bash/config-drift.d/*.sh)
          # Not individually symlinked either: install.sh's helper-script loop
          # symlinks config-drift.d/ as one directory (same as nvim above), so
          # each file inside is reached through that, never its own link.
          continue ;;
        bash/*) livef=$HOME/.local/bin/${rel#bash/} ;;
        applications/*.desktop) livef=$HOME/.local/share/applications/${rel##*/} ;;
        ptpython/config.py|ipython/profile_default/ipython_config.py|ipython/profile_default/startup/*.py|systemd/user/*.service|systemd/user/*.timer)
          livef=$HOME/.config/$rel ;;
        pcmanfm-qt/settings.conf|pcmanfm-qt/bookmarks.xml)
          livef=$config_home/pcmanfm-qt/default/${rel##*/} ;;
        foliate/themes/*.json)
          livef=$config_home/com.github.johnfactotum.Foliate/themes/${rel##*/} ;;
        containers/*.container|containers/*.network)
          livef=$config_home/containers/systemd/${rel##*/} ;;
        xdg/user-dirs.dirs) livef=$config_home/user-dirs.dirs ;;
        skills/*/SKILL.md)
          # Linked into both agent trees during Codex coexistence (see
          # docs/codex-migration.md). Only the Claude side is asserted here --
          # checking one target per repo file is what this loop is shaped for,
          # and the ~/.agents/skills root above still catches a dangling link
          # there. Installing only one half is the failure this pair guards.
          expected=${expected%/SKILL.md}
          livef=$HOME/.claude/skills/${expected##*/} ;;
        firefox/userChrome.css)
          # Optional: same profile selection as install.sh; do not require Firefox
          # to have been launched. Ambiguous profiles cannot establish one target.
          profiles=$HOME/.mozilla/firefox/profiles.ini
          [[ -e $profiles ]] || continue
          if ! profile=$(awk -F= '/^\[Install/{in_install=1} in_install && /^Default=/{print $2; in_install=0}' "$profiles" 2>/dev/null); then
            warn "cannot read Firefox profile mapping — link not checked"; sbad=1
            continue
          fi
          [[ -n $profile ]] || continue
          if [[ $profile == *$'\n'* ]]; then
            warn "multiple Firefox default profiles — link mapping needs review"; sbad=1
            continue
          fi
          livef=$HOME/.mozilla/firefox/$profile/chrome/userChrome.css ;;
        zsh/aliases|zsh/helpers.zsh|zsh/generate-completions.sh|zsh/update-plugins.sh|\
        zsh/functions/*.zsh|tmux/tmux.conf|tmux/layouts/*.sh|niri/config.kdl|\
        environment.d/defaults.conf|environment.d/wayland.conf|paru/paru.conf|swaylock/config|\
        glow/glow.yml|mpv/mpv.conf|yt-dlp/config|cmus/rc|direnv/direnvrc|uv/uv.toml|gh/config.yml|\
        neocmakelsp/config.toml|mako/config|vifm/vifmrc|vifm/colors/catppuccin-mocha.vifm|\
        vifm/colors/zenburn-rich.vifm|tridactyl/tridactylrc|fuzzel/fuzzel.ini|bat/config|\
        btop/btop.conf|starship.toml|foot/foot.ini|git/config|git/ignore|lazygit/config.yml|\
        zathura/zathurarc|sioyek/prefs_user.config|sioyek/keys_user.config|vimb/config|\
        clangd/config.yaml|spotify-player/theme.toml|handlr/handlr.toml|ccache/ccache.conf|wob/wob.ini|\
        latexmk/latexmkrc|mimeapps.list|papis/config|containers/containers.conf|\
        containers/storage.conf)
          livef=$config_home/$rel ;;
        *) continue ;;
      esac
      if [[ ! -e $expected ]]; then
        warn "expected repo source unavailable: $rel"; sbad=1
      elif [[ -L $livef ]]; then
        if [[ ! -e $livef ]]; then
          [[ -n ${dangling_seen[$livef]:-} ]] || warn "dangling symlink: ${livef/#$HOME/\~}"
          sbad=1
        elif [[ ! $livef -ef $expected ]]; then
          warn "wrong symlink target: ${livef/#$HOME/\~} (expected $rel)"; sbad=1
        fi
      elif [[ -e $livef ]]; then
        warn "detached (not a symlink): ${livef/#$HOME/\~}"; sbad=1
      else
        warn "missing expected symlink: ${livef/#$HOME/\~}"; sbad=1
      fi
    done <<<"$tracked"
  else
    warn "cannot list tracked files — expected links not checked"; sbad=1
  fi

  ((sbad)) || ok "expected config links match; no dangling links found in scanned paths"
}
