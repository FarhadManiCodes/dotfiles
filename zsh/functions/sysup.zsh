# sysup - full system + tooling update
#
# Order: mirrorlist -> pacman/AUR (paru) -> uv tools -> bgutil -> yts -> Cargo tools -> Herdr ->
# Claude Code ->
# editor/shell plugins -> nvim :checkhealth -> fwupd metadata (if stale) ->
# config-drift. `--podman-images` adds container image updates after nvim health;
# `--test-tools` adds my own tools' test suites against the newest dependencies after uv.
#
# Ctrl-C skips the running step; a second press, or one in paru once it began installing or in
# bgutil, stops the run (docs/architecture/zsh.md, "Ctrl-C in sysup").
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

zmodload zsh/datetime # EPOCHREALTIME, for the double Ctrl-C window

# Failures and skips are recorded in the caller's _sysup_notes (zsh dynamic scope) and repeated
# last, where the scrolled-away middle of a long run cannot hide them. Printing empties the list,
# so the cleanup of a stopped run can flush again without repeating anything.
_sysup_flush_notes() {
  (( ${#_sysup_notes} )) && printf '!! %s\n' "${_sysup_notes[@]}"
  _sysup_notes=()
  return 0
}

# Records a failure sysup continues past: _sysup_note STATUS MESSAGE. The command a Ctrl-C skipped
# fails too, but TRAPINT already recorded the skip, so a failure with that command's own status adds
# nothing (and clears the mark). A different status is a real failure and is recorded.
_sysup_note() {
  local _status=$1
  shift
  if (( _sysup_skipped && _status == _sysup_skipped )); then
    _sysup_skipped=0
    return 0
  fi
  _sysup_notes+=("$*")
  echo "!! $* — continuing sysup"
}

# Prints a step header and remembers it, for the Ctrl-C messages.
_sysup_header() {
  _sysup_step=$1
  _sysup_skipped=0
  echo "==> $1"
}

# Ctrl-C: where skipping would leave a half-done state, it stops sysup instead.
#   bgutil -- yt-dlp and its token helper would stay mismatched.
#   paru   -- once pacman logged "transaction started" (after the prompt, sudo and downloads)
#             packages may be half-installed, and later steps must not build on that. Before
#             that nothing was installed. An unreadable boundary or log, or a log rotated or
#             truncated since the run began (the recorded offset then means nothing), counts as
#             started.
_sysup_unsafe_to_skip() {
  case $_sysup_guard in
    bgutil) return 0 ;;
    paru)
      [[ $_pacman_boundary == *:*:* ]] || return 0
      local _now
      _now=$(stat -Lc '%d:%i:%s' /var/log/pacman.log 2>/dev/null) || return 0
      [[ ${_now%:*} == ${_pacman_boundary%:*} ]] && (( ${_now##*:} >= ${_pacman_boundary##*:} )) || return 0
      tail -c "+$(( ${_pacman_boundary##*:} + 1 ))" /var/log/pacman.log 2>/dev/null | grep -q 'transaction started'
      case "${pipestatus[1]}:${pipestatus[2]}" in
        0:0) return 0 ;; # started
        0:1) return 1 ;; # log read, nothing started
        *) return 0 ;;   # could not read the log (tail failed, or grep errored with 2)
      esac ;;
    *) return 1 ;;
  esac
}

sysup() {
  local _include_podman_images=0 _test_tools=0 _arg _sysup_step="" _sysup_guard="" _pacman_boundary="" _sysup_skipped=0
  local -F _last_int=0
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
  # always block releases it however this returns, including a stopped Ctrl-C and an early failure.
  # Silencing the job chatter takes BOTH of the lines below, which is not
  # obvious: an interactive zsh announces a background job twice, and each
  # message has a different off switch.
  #   "[3] 3273"                        at launch -- printed only when MONITOR
  #                                     is on, so no_monitor suppresses it
  #   "[3] + terminated systemd-inhibit" when the always block kills it -- printed for jobs
  #                                     in the table, so disown suppresses it
  # no_monitor alone leaves the second (local_options restores MONITOR on
  # return, and the job is still in the table); disown alone leaves the first.
  # Neither is cosmetic-only: both bracket every sysup with what reads like an
  # error and is not one. disown removes the table entry, not the process -- the
  # pid stays valid, so the always block can still kill it.
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
  # The descriptor is inherited by every child. The subshell steps (tool tests, bgutil, yts, Herdr)
  # close it, because a process they leave behind would keep the lock held after sysup returns; the
  # steps run directly in this shell do not, and none is known to leave a process behind.
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
    #
    # The cleanup below does not run when the shell is hung up or killed (shpool kill, SIGKILL):
    # measured, neither an EXIT trap nor a TRAPHUP function ran while a step was running. The
    # inhibitor still ends then, because the kernel hangs up the whole pty session when its leader
    # dies (tests/test_sysup_ctrl_c.py checks a SIGKILLed shell). Keep it in that session: a
    # setsid'd inhibitor would survive and block suspend until reboot.
    systemd-inhibit --what=sleep:idle --who=sysup \
      --why="System update in progress" --mode=block sleep infinity {_lockfd}>&- &
    _inhibit_pid=$!
    disown 2>/dev/null
  fi

  # Ctrl-C (see docs/architecture/zsh.md, "Ctrl-C in sysup"): the first press kills the running
  # command and sysup moves on; a second within 2 s, or a press where skipping is unsafe, stops it.
  # A TRAPINT function returning 128+2 aborts like an untrapped SIGINT; a `trap '...' INT` string
  # does not (measured). The abort skips an EXIT trap, hence the always block below.
  # $? on entry is the status of the command the key interrupted: non-zero when it was killed
  # (130) or exited on the signal, 0 when no command was running, e.g. in a pure-shell step.
  # A TRAPINT of the user's own is put back afterwards (a function is not covered by local_traps).
  local _user_trapint=""
  (( $+functions[TRAPINT] )) && _user_trapint=$functions[TRAPINT]
  TRAPINT() {
    local _rc=$?
    if _sysup_unsafe_to_skip; then
      echo; echo "!! Ctrl-C during ${_sysup_step}: skipping is unsafe — stopping sysup"
      return 130
    fi
    if (( EPOCHREALTIME - _last_int < 2 )); then
      echo; echo "!! second Ctrl-C — stopping sysup"
      return 130
    fi
    _last_int=$EPOCHREALTIME
    if (( _rc == 0 )); then
      echo; echo "!! Ctrl-C: no command was running, nothing to skip (again within 2 s stops sysup)"
      return 0
    fi
    _sysup_skipped=$_rc
    _sysup_notes+=("skipped with Ctrl-C: the running command in ${_sysup_step}$([[ $_sysup_guard == paru ]] && print -r -- '; nothing was installed')")
    echo; echo "!! Ctrl-C: skipping the running command in ${_sysup_step} (again within 2 s stops sysup)"
    return 0
  }

  local _sysup_status=0
  {
    _sysup_steps
    _sysup_status=$?
  } always {
    [[ -z $_inhibit_pid ]] || kill $_inhibit_pid 2>/dev/null
    rm -f -- "$_herdr_reason"
    [[ -z $_lockfd ]] || exec {_lockfd}>&-
    if [[ -n $_user_trapint ]]; then
      functions[TRAPINT]=$_user_trapint
    else
      unfunction TRAPINT 2>/dev/null
    fi
    _sysup_flush_notes
  }
  return $_sysup_status
}

# The update steps. Runs inside sysup's try/always block and reads its locals (flags, notes,
# step name, cleanup state) through zsh's dynamic scope.
_sysup_steps() {
  _sysup_header "Mirrorlist"
  _sysup_mirrorlist_check

  _sysup_header "System & AUR (paru -Syu)"
  # Keep a byte boundary, not a timestamp: several ALPM transactions can share
  # a second, and paru may run more than one transaction in a single invocation.
  local _paru_status=0
  _pacman_boundary=$(stat -Lc '%d:%i:%s' /var/log/pacman.log 2>/dev/null) || _pacman_boundary=unavailable
  _sysup_guard=paru
  paru -Syu || _paru_status=$?
  _sysup_guard=
  if (( _paru_status && _paru_status != _sysup_skipped )); then
    echo "!! paru failed — checking transaction diagnostics before stopping sysup"
    _sysup_pacnew --pacman-since "$_pacman_boundary" || :
    return "$_paru_status"
  fi

  _sysup_header "uv tools"
  echo "    Installed tools:"
  local _status=0
  uv tool list --show-version-specifiers || {
    _status=$?
    _sysup_note "$_status" "could not list uv tools (exit $_status); see the output above"
  }
  echo "    Checking for updates..."
  _status=0
  uv tool upgrade --all || _status=$?
  if (( _status )); then
    _sysup_note "$_status" "uv tool upgrade failed (exit $_status); tools, including yt-dlp and its token helper, may be outdated or mismatched; see the output above"
  else
    echo "    All uv tools checked"
  fi

  if (( _test_tools )); then
    _sysup_header "Own tools: tests against the newest dependencies"
    _sysup_tool_tests || : # records its own notes
  fi

  _sysup_header "yt-dlp token helper (bgutil)"
  _sysup_guard=bgutil
  _sysup_bgutil || {
    echo "!! bgutil update failed; yt-dlp/helper may still be mismatched — stopping sysup"
    return 1
  }
  _sysup_guard=

  _sysup_header "yts (local app)"
  _status=0
  _sysup_yts || _status=$?
  (( _status )) && { _sysup_note "$_status" "yts install failed (exit $_status); see the output above"; }

  _sysup_header "Cargo tools"
  _status=0
  cargo install-update --all || _status=$?
  if (( _status && _status != _sysup_skipped )); then
    echo "!! Cargo tool update failed — stopping sysup"
    return 1
  elif (( ! _status )); then
    echo "    All Cargo tools checked"
  fi

  _sysup_header "Herdr (Cargo stable release)"
  local _herdr_note
  rm -f -- "$_herdr_reason"
  _status=0
  HERDR_CARGO_REASON_FILE=$_herdr_reason _sysup_herdr || _status=$?
  if (( _status )); then
    _herdr_note="Herdr update failed (exit $_status): $(cat -- "$_herdr_reason" 2>/dev/null)"
    [[ -s $_herdr_reason ]] || _herdr_note="Herdr update failed (exit $_status); see the output above"
    _sysup_note "$_status" "$_herdr_note"
  fi

  _sysup_header "Claude Code"
  claude update
  _sysup_prune_claude_versions

  _sysup_header "Editor & shell plugins"
  _sysup_plugins

  _sysup_header "Neovim health"
  _sysup_nvim_health

  local _podman_status=0
  if (( _include_podman_images )); then
    _sysup_header "Container images (podman)"
    _sysup_podman_images || {
      _status=$?
      if (( _status != _sysup_skipped )); then
        _podman_status=$_status
        echo "!! container image update failed — continuing to post-update checks"
      fi
    }
  fi

  _sysup_header "Firmware metadata (fwupd)"
  _sysup_fwupd_refresh_if_stale

  _sysup_header "Config drift"
  _sysup_pacnew --pacman-since "$_pacman_boundary"

  local _recorded=${#_sysup_notes}
  _sysup_flush_notes
  if (( _podman_status || _recorded )); then
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
