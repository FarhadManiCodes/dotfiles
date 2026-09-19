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

  # Unlike the three above, lazy.nvim is lockfile-based (docs/architecture/neovim.md)
  # — `Lazy! sync` rewrites nvim/lazy-lock.json in the nvim *submodule*, so this step
  # alone can leave another git tree dirty. Saying so is the point.
  if command -v nvim >/dev/null 2>&1; then
    local lock="${DOTFILES:-$HOME/dotfiles}/nvim/lazy-lock.json"
    # sha256, not mtime: lazy rewrites the lockfile unconditionally on every sync.
    local before="" after=""
    [[ -f $lock ]] && before=$(sha256sum "$lock" | cut -d' ' -f1)
    echo "   nvim plugins..."
    nvim --headless "+Lazy! sync" +qa >/dev/null 2>&1 || echo "   ⚠ nvim plugins: Lazy sync failed"
    if [[ -f $lock ]]; then
      after=$(sha256sum "$lock" | cut -d' ' -f1)
      if [[ $before != $after ]]; then
        echo "   ⚠ nvim/lazy-lock.json changed — review and commit it in the submodule:"
        echo "        git -C ${lock:h} diff lazy-lock.json"
        echo "     rollback if an update broke something:"
        echo "        git -C ${lock:h} checkout lazy-lock.json && nvim --headless '+Lazy! restore' +qa"
      fi
    fi
  else
    echo "   nvim: not installed — skipping"
  fi
}
