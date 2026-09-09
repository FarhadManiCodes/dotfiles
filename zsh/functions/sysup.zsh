# sysup - full system + tooling update
#
# Order: pacman/AUR (paru) -> uv tools -> Claude Code -> editor/shell plugins ->
# nvim :checkhealth -> container images -> fwupd metadata (if stale) -> config-drift.
#
# No npm step: there are no user npm globals, and system node/npm are pacman
# packages already covered by paru -Syu above.

sysup() {
  # Hold off suspend for the duration. swayidle measures INPUT idleness, not CPU,
  # so an unattended update looks idle: on battery it locks at 5min and suspends
  # at 15 (timeout 900 in swayidle.service). A paru -Syu that builds anything
  # from the AUR passes that easily, and suspending mid-transaction drops every
  # download in flight.
  #
  # An unprivileged sleep:idle block inhibitor is enough here -- verified, no
  # sudo needed, despite the equivalent upstream script reaching for pkexec. The
  # trap releases it however this returns, including Ctrl-C and an early failure.
  # Silencing the job chatter takes BOTH of the lines below, which is not
  # obvious: an interactive zsh announces a background job twice, and each
  # message has a different off switch.
  #   "[3] 3273"                        at launch -- printed only when MONITOR
  #                                     is on, so no_monitor suppresses it
  #   "[3] + terminated systemd-inhibit" when the trap fires -- printed for jobs
  #                                     in the table, so disown suppresses it
  # no_monitor alone leaves the second (local_options restores MONITOR on
  # return, and the job is still in the table); disown alone leaves the first.
  # Neither is cosmetic-only: both bracket every sysup with what reads like an
  # error and is not one. disown removes the table entry, not the process -- the
  # pid stays valid, so the trap still reaps it.
  # One run at a time. paru is covered by pacman's own db.lck, but the uv, plugin,
  # podman and Claude-prune steps would happily race a second sysup in another
  # terminal. flock on a runtime-dir file, released when the fd closes.
  #
  # If the lock file cannot be opened at all, this runs anyway -- deliberately.
  # Refusing would turn an exotic filesystem problem (a full or missing
  # $XDG_RUNTIME_DIR tmpfs) into "sysup will not run", which is worse than one
  # unprotected run. But it must not be silent: without the warning the guard
  # short-circuits and the run looks identical to a locked one.
  #
  # _lockfd must be cleared first, not just on failure. It is a global, and zsh
  # sets an fd variable to 0 when that descriptor is closed -- so the second
  # sysup in one shell starts with a stale _lockfd=0 that a failed open leaves
  # untouched. Without this line that reads as "lock held" and flocks fd 0,
  # which is stdin.
  local _lock="${XDG_RUNTIME_DIR:-/tmp}/sysup.lock"
  _lockfd=""
  exec {_lockfd}>"$_lock" 2>/dev/null || _lockfd=""
  if [[ -z $_lockfd ]]; then
    echo "!! could not open $_lock — continuing WITHOUT the concurrency lock"
  elif ! flock -n $_lockfd; then
    echo "!! another sysup is already running — stopping"
    exec {_lockfd}>&-
    return 1
  fi

  local _inhibit_pid=""
  if command -v systemd-inhibit >/dev/null 2>&1; then
    setopt local_options no_monitor
    # The inhibitor MUST NOT inherit the lock descriptor. It is backgrounded and
    # outlives the step that starts it, so an inherited fd would hold the lock
    # after this function returns -- blocking every later sysup with no visible
    # cause. {_lockfd}>&- closes it in the child only.
    systemd-inhibit --what=sleep:idle --who=sysup \
      --why="System update in progress" --mode=block sleep infinity {_lockfd}>&- &
    _inhibit_pid=$!
    disown 2>/dev/null
    trap "kill $_inhibit_pid 2>/dev/null; exec {_lockfd}>&-" EXIT INT TERM
  else
    trap "exec {_lockfd}>&-" EXIT INT TERM
  fi

  echo "==> System & AUR (paru -Syu)"
  # Keep a byte boundary, not a timestamp: several ALPM transactions can share
  # a second, and paru may run more than one transaction in a single invocation.
  local _pacman_boundary _paru_status=0
  _pacman_boundary=$(stat -Lc '%d:%i:%s' /var/log/pacman.log 2>/dev/null) || _pacman_boundary=unavailable
  paru -Syu || _paru_status=$?
  if (( _paru_status )); then
    echo "!! paru failed — checking transaction diagnostics before stopping sysup"
    _sysup_pacnew --pacman-since "$_pacman_boundary" || :
    return "$_paru_status"
  fi

  echo "==> uv tools"
  uv tool upgrade --all

  echo "==> Claude Code"
  claude update
  _sysup_prune_claude_versions

  echo "==> Editor & shell plugins"
  _sysup_plugins

  echo "==> Neovim health"
  _sysup_nvim_health

  echo "==> Container images (podman)"
  _sysup_podman_images

  echo "==> Firmware metadata (fwupd)"
  _sysup_fwupd_refresh_if_stale

  echo "==> Config drift"
  _sysup_pacnew --pacman-since "$_pacman_boundary"

  echo "==> sysup done"
}

# A package upgrade that finds a config you have modified writes its new version alongside as
# a .pacnew and says nothing further. Nothing else here looks for them, so they accumulate
# silently: on 2026-09-04 there were nine, the oldest from 2026-05-16 -- nearly four months of
# running old config while upstream had moved on. Every one belonged to a file this repo had
# just spent an afternoon triaging (tlp.conf, locale.gen, mkinitcpio.conf, ly/config.ini,
# bluetooth/main.conf), which is precisely how that kind of drift stays invisible.
#
# Reports only. Merging a .pacnew is a judgement call about which side of each hunk to keep,
# and `pacdiff` is the tool for it -- doing that unattended inside an update would be a good
# way to lose a deliberate setting. --output prints without touching anything and needs no root.
# Runs after the update, so it reports the state the update just produced: a
# package that shipped a .pacnew, or a plugin whose new version stopped honouring
# an option. bash/config-drift holds the checks and the reasoning for each.
_sysup_pacnew() {
  if [[ -x "$HOME/.local/bin/config-drift" ]]; then
    "$HOME/.local/bin/config-drift" "$@"
  else
    echo "   config-drift not found — skipping"
  fi
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

  # nvim was missing from this loop until 2026-09-04, so its 37 plugins had been frozen since
  # 25 July -- lazy.nvim itself pinned nine months back -- with nothing to say so. Same silent
  # shape as the tmux clones that sat at 2023-2024.
  #
  # Unlike the three above, lazy.nvim is LOCKFILE-based: `Lazy! sync` rewrites
  # nvim/lazy-lock.json, and that file lives in the nvim *submodule*, a separate repo. So this
  # step alone can leave another git tree dirty. Saying so is the whole point -- an unexplained
  # modified submodule found days later is worse than a line of output now.
  if command -v nvim >/dev/null 2>&1; then
    local lock="${DOTFILES:-$HOME/dotfiles}/nvim/lazy-lock.json"
    # sha256, NOT mtime: lazy rewrites the lockfile "wb" unconditionally on every
    # sync (manage/lock.lua), so an mtime test would announce a change after every
    # single sysup and train you to ignore the message.
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



# `:checkhealth` after the plugin sync, because a sync is exactly when nvim breaks:
# a plugin drops a dependency, an API it used gets deprecated, a treesitter parser
# goes out of step with the ABI. None of that fails the sync -- `Lazy! sync` reports
# success and the editor just quietly does less, which is the same silent shape as
# the stale plugins and the .pacnew backlog.
#
# Costs ~2.9s headless, so it runs every time rather than on a schedule.
#
# ERRORs are always listed: they are real breakage. WARNINGs are only listed when
# the SET of them changes, because most are permanent and not actionable -- today
# blink.cmp explains that some sources are enabled dynamically, and jupytext.nvim
# calls a vim.validate form deprecated for Nvim 1.0. Printing those every single
# run is how a warning becomes wallpaper; the count still shows, so a new one is
# visible without the noise. Same reasoning as the lazy-lock sha256 comparison
# above, and the same trap config-drift avoids.
_sysup_nvim_health() {
  command -v nvim >/dev/null 2>&1 || { echo "   nvim not installed — skipping"; return 0 }

  local state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/sysup"
  mkdir -p "$state_dir" 2>/dev/null || return 0
  local report="$state_dir/nvim-health.txt"
  local seen="$state_dir/nvim-health-warnings"

  # `+w!` writes the health buffer; nvim exits 0 even when checks fail, so the
  # report itself is the only signal -- an empty file means checkhealth did not run.
  nvim --headless "+checkhealth" "+w! $report" +qa >/dev/null 2>&1
  if [[ ! -s $report ]]; then
    echo "   ⚠ checkhealth did not produce a report — run :checkhealth by hand"
    return 0
  fi

  # Severity markers are emoji (✅/⚠️/❌) which are awkward to match portably, so key
  # on the word after them. The section name comes from the line under each ==== rule.
  local -a errors warnings
  local prog='/^=+$/{getline s; sub(/:.*$/,"",s); next}
             $0 ~ "^- [^ ]+ " sev " " {sub("^- [^ ]+ " sev " ",""); print s ": " $0}'
  errors=("${(@f)$(awk -v sev=ERROR   "$prog" "$report")}")
  warnings=("${(@f)$(awk -v sev=WARNING "$prog" "$report")}")
  errors=(${errors:#})
  warnings=(${warnings:#})

  local n_err=${#errors} n_warn=${#warnings}

  if (( n_err )); then
    echo "   ✗ ${n_err} error(s):"
    printf '       %s\n' "${errors[@]}"
  fi

  # Compare the warning set with the last run, not the count: a warning that is
  # replaced by a different one keeps the count identical.
  local current previous=""
  current=$(printf '%s\n' "${warnings[@]}" | sort)
  [[ -f $seen ]] && previous=$(<"$seen")

  if [[ $current != $previous ]]; then
    if (( n_warn )); then
      echo "   ${n_warn} warning(s), changed since the last run:"
      printf '       %s\n' "${(@f)current}"
    else
      echo "   warnings cleared — none left"
    fi
    print -r -- "$current" > "$seen"
  elif (( n_warn )); then
    echo "   ${n_warn} warning(s), unchanged — see $report"
  fi

  (( n_err || n_warn )) || echo "   healthy — no errors or warnings"
  return 0
}
