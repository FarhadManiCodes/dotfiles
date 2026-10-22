# sysup - full system + tooling update
#
# Order: mirrorlist -> pacman/AUR (paru) -> uv tools -> bgutil -> yts -> Cargo tools -> Herdr ->
# Claude Code ->
# editor/shell plugins -> nvim :checkhealth -> fwupd metadata (if stale) ->
# config-drift. `--podman-images` adds container image updates after nvim health;
# `--test-tools` adds my own tools' test suites against the newest dependencies after uv.
#
# No global npm update: system node/npm are covered by paru. The bgutil step
# rebuilds only the local yt-dlp token helper, using its release's lockfile.
#
# Steps live one-per-file in sysup/, sourced below by $0's own resolved
# directory -- zsh sets $0 to the currently-sourcing file even nested inside a
# function, so this works whether sysup.zsh is reached through install.sh's
# symlink or sourced directly (as the tests do).
_sysup_module_dir="${0:A:h}/sysup"
for _sysup_module in bgutil yts herdr tool-tests mirrorlist nvim-health plugins claude-prune podman; do
  source "$_sysup_module_dir/$_sysup_module.zsh"
done
unset _sysup_module_dir _sysup_module

# Failures sysup continues past are recorded in the caller's _sysup_notes (zsh dynamic scope)
# and repeated last, where the scrolled-away middle of a long run cannot hide them.
_sysup_flush_notes() {
  (( ${#_sysup_notes} )) && printf '!! %s\n' "${_sysup_notes[@]}"
  return 0
}

sysup() {
  local _include_podman_images=0 _test_tools=0 _arg
  local -a _sysup_notes=()
  local _herdr_reason="${XDG_RUNTIME_DIR:-/tmp}/sysup-herdr-reason.$$"
  for _arg in "$@"; do
    case $_arg in
      --podman-images) _include_podman_images=1 ;;
      --test-tools) _test_tools=1 ;;
      -h|--help)
        print 'Usage: sysup [--podman-images] [--test-tools]'
        print '  --podman-images  update installed Quadlet images; restart only running units'
        print '  --test-tools     run my uv tools'"'"' test suites against the newest dependencies'
        return 0 ;;
      *)
        print -u2 "sysup: unknown option: $_arg"
        print -u2 'Usage: sysup [--podman-images] [--test-tools]'
        return 2 ;;
    esac
  done

  # A closed terminal must only detach the client, leaving the update alive.
  # shpool exports this in its sessions, so keep sysup does not nest sessions.
  if [[ -z ${SHPOOL_SESSION_NAME:-} ]]; then
    if ! (( $+functions[keep] )); then
      print -u2 'sysup: shpool/keep is required; install shpool and reload ~/.zshrc'
      return 1
    fi
    keep sysup "$@"
    return $?
  fi

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
    trap "kill $_inhibit_pid 2>/dev/null; rm -f -- ${(q)_herdr_reason}; exec {_lockfd}>&-" EXIT INT TERM
  else
    trap "rm -f -- ${(q)_herdr_reason}; exec {_lockfd}>&-" EXIT INT TERM
  fi

  echo "==> Mirrorlist"
  _sysup_mirrorlist_check

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
  echo "    Installed tools:"
  uv tool list --show-version-specifiers || {
    _sysup_notes+=("could not list uv tools (exit $?); see the output above")
    echo "!! ${_sysup_notes[-1]} — continuing sysup"
  }
  echo "    Checking for updates..."
  local _uv_status=0
  uv tool upgrade --all || _uv_status=$?
  if (( _uv_status )); then
    _sysup_notes+=("uv tool upgrade failed (exit $_uv_status); tools, including yt-dlp and its token helper, may be outdated or mismatched; see the output above")
    echo "!! ${_sysup_notes[-1]} — continuing sysup"
  else
    echo "    All uv tools checked"
  fi

  if (( _test_tools )); then
    echo "==> Own tools: tests against the newest dependencies"
    _sysup_tool_tests
  fi

  echo "==> yt-dlp token helper (bgutil)"
  _sysup_bgutil || {
    echo "!! bgutil update failed; yt-dlp/helper may still be mismatched — stopping sysup"
    _sysup_flush_notes
    return 1
  }

  echo "==> yts (local app)"
  _sysup_yts || echo "!! yts install failed — continuing sysup"

  echo "==> Cargo tools"
  cargo install-update --all || {
    echo "!! Cargo tool update failed — stopping sysup"
    _sysup_flush_notes
    return 1
  }
  echo "    All Cargo tools checked"

  echo "==> Herdr (Cargo stable release)"
  local _herdr_status=0 _herdr_note
  rm -f -- "$_herdr_reason"
  HERDR_CARGO_REASON_FILE=$_herdr_reason _sysup_herdr || _herdr_status=$?
  if (( _herdr_status )); then
    _herdr_note="Herdr update failed (exit $_herdr_status): $(cat -- "$_herdr_reason" 2>/dev/null)"
    [[ -s $_herdr_reason ]] || _herdr_note="Herdr update failed (exit $_herdr_status); see the output above"
    _sysup_notes+=("$_herdr_note")
    echo "!! $_herdr_note — continuing sysup"
  fi

  echo "==> Claude Code"
  claude update
  _sysup_prune_claude_versions

  echo "==> Editor & shell plugins"
  _sysup_plugins

  echo "==> Neovim health"
  _sysup_nvim_health

  local _podman_status=0
  if (( _include_podman_images )); then
    echo "==> Container images (podman)"
    _sysup_podman_images || {
      _podman_status=$?
      echo "!! container image update failed — continuing to post-update checks"
    }
  fi

  echo "==> Firmware metadata (fwupd)"
  _sysup_fwupd_refresh_if_stale

  echo "==> Config drift"
  _sysup_pacnew --pacman-since "$_pacman_boundary"

  _sysup_flush_notes
  if (( _podman_status || ${#_sysup_notes} )); then
    echo "==> sysup finished with warnings"
    return "$(( _podman_status ? _podman_status : 1 ))"
  fi
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
