# Isolated Niri session

Installed and verified through Ly on 2026-09-11 at 16:27 CEST, on
`add-niri-isolated-config`. Startup and the application/shell environment boundary
are confirmed; the blanket-import deprecation warning was absent. Implementation
and troubleshooting closed on 2026-09-11. Logout/relogin without reboot, automatic
idle actions, and the full interactive application checklist were not verified;
the checks below remain available for normal use or a future reported problem.

`niri-isolated.desktop` is a **login-session menu entry**, not an application shortcut.
Ly uses it to offer “Niri (isolated environment)” alongside packaged “Niri”.
It invokes a root-owned copy of `niri-session-isolated`.

## Environment ownership

The launcher does not read `environment.d`. The user manager already reads it and
supplies application defaults to `niri.service` and other services. Existing PATH,
XDG directories, locale, toolkit, `NO_AT_BRIDGE=1` and eight-worker BLAS settings
are untouched. Zsh supplies its own shell environment, including IPython and Cargo.

Only inherited `XDG_SESSION_ID`, `XDG_SEAT`, and `XDG_VTNR` enter the clean control
shell. They must match the calling logind session's ID, seat and VT; that session
must belong to the current UID, be local, and have type `wayland`.
The launcher sets those three manager variables plus `XDG_SESSION_TYPE=wayland`,
`XDG_CURRENT_DESKTOP=niri`, and `XDG_SESSION_DESKTOP=niri-isolated`.

Control commands use fixed paths, a clean shell and a UID-derived `/run/user/<uid>`
and bus address. Their minimal PATH and `LC_ALL=C` are client settings, never
copied into the manager. No login shell, shell startup file, blanket import, or
additional D-Bus activation-environment update runs. This machine uses dbus-broker
with systemd activation. Niri retains publication of its five display/session
variables: `WAYLAND_DISPLAY`, `DISPLAY`, `NIRI_SOCKET`, `XDG_SESSION_TYPE`, and
`XDG_CURRENT_DESKTOP`, at its own readiness point.

## Changes from the packaged launcher

- Adds a nonblocking per-user lock and validates metadata and service state before
  taking ownership. Duplicate rejection never performs teardown.
- Resets `niri.service` only when its state is `failed`; clears three stale display/socket
  overrides and sets the six named metadata variables explicitly.
- Starts the existing service with `systemctl --user --wait start niri.service`.
  A background client plus shell `wait` allows catchable signals to run cleanup.
- On logout, startup failure, HUP, INT or TERM, uses the packaged
  `niri-shutdown.target`, then a blocking `stop niri.service` before clearing the
  nine managed variables. The latter joins compositor teardown explicitly: the
  packaged service's `Before=graphical-session.target` reverses at shutdown, so
  completion of the target job alone does not prove Niri has stopped.
  Unrelated manager variables remain untouched.
- Reports cleanup failures and preserves an original nonzero exit status. If
  shutdown fails, it retains session variables because teardown is unconfirmed.
  It still attempts the compositor stop when the shutdown-target command fails.
  It never falls back to stock Niri or hides diagnostics.

The service, graphical targets, autostart and existing notification setup remain
packaged/configured as before. No new unit or daemon is added.
The extra script length is validation and lifecycle handling, not a second
application-environment configuration.

The tests are development-only: neither installer nor session entry runs them.
Login checks run once, and cleanup runs at exit. During the session, a shell and
the `systemctl --wait` client remain blocked waiting for logout, as in the stock
launcher; there is no periodic checking, timer, watcher or additional daemon.
`flock` exits after acquiring the lock; the shell retains the lock descriptor.
No login-time or memory-use improvement has been measured.

## Install and rollback

After review, install **only these two files**, from the repository root:

```sh
sudo install -D -o root -g root -m 0755 niri/niri-session-isolated /usr/local/bin/niri-session-isolated
sudo install -D -o root -g root -m 0644 niri/niri-isolated.desktop /usr/share/wayland-sessions/niri-isolated.desktop
```

These mappings are also in `install-root.sh` for rebuilds. Do not run the whole
installer for this rollout. Neither packaged Niri file is overwritten.
Verify content, ownership and modes:

```sh
cmp niri/niri-session-isolated /usr/local/bin/niri-session-isolated
cmp niri/niri-isolated.desktop /usr/share/wayland-sessions/niri-isolated.desktop
stat -c '%U:%G %a %n' /usr/local/bin/niri-session-isolated /usr/share/wayland-sessions/niri-isolated.desktop
```

Both `cmp` commands should exit 0 without output. Expect `root:root 755` for the
launcher and `root:root 644` for the entry. No daemon reload is needed: no units
are being installed. Save your work and reboot when ready, then choose the
isolated entry in Ly. Do not start the script manually inside the existing desktop.

Recovery: choose stock “Niri”. To remove the custom entry and launcher:

```sh
sudo rm /usr/share/wayland-sessions/niri-isolated.desktop /usr/local/bin/niri-session-isolated
```

Stock Niri can repollute the manager through blanket imports. A clean isolated
test after using it requires a fresh user manager; reboot is the chosen procedure.
Only one graphical session per user is supported. The isolated lock coordinates
isolated launches; stock launches and other manager clients do not share it.
This is environment hygiene, not a security sandbox. Ly still performs its initial
shell reads, and other programs can independently modify the manager.

## Verification

Successful live check, 2026-09-11, boot `a9ffa535-46ed-4b71-b37a-b35f9fe6b438`:

- Installed launcher matches the source. Niri became active/running at 16:27:37,
  with `XDG_SESSION_DESKTOP=niri-isolated`; graphical-session.target, swayidle,
  mako and the main/GTK/wlr/document portal services are active. No failed user units.
- Selected initial process-environment values in both Niri and swayidle match
  `environment.d`: application PATH without Cargo, English LANG, German regional
  categories, eight-worker BLAS settings, `NO_AT_BRIDGE=1`, toolkit and socket
  defaults. `LC_ALL`, `IPYTHONDIR`, `CENTRAL_VENVS` and `DOTFILES` are absent.
- A fresh Zsh invocation restores IPython, central-venv and dotfiles variables and
  adds Cargo to PATH. This checks shell startup, not a separate SSH/TTY login.
- Ly's current session log is empty. The checked desktop-service journal contains
  no blanket-import deprecation warning. Two existing messages remain: missing
  `xwayland-satellite` and unset `DISPLAY`, also seen in the earlier recovery login.
  A priority-only journal query misses these text warnings, so full message text
  was checked too. No X11 compatibility fix was included in this change.

All 29 unittest tests passed (15 for this launcher). Offline tests run a temporary
copy with fixed systemctl/loginctl paths replaced by fakes; the installed script
has no test override. Real flock and shell signals are exercised. Tests cover
logout, startup/setup failures, unavailable manager,
metadata rejection, existing service states, duplicate lock, HUP/INT/TERM,
cleanup failures, missing metadata, runtime-directory permissions, interruption
during setup, and injected shell exports, PATH and client overrides.

Shell syntax and ShellCheck include the embedded clean-shell body. Desktop-entry
validation reports exactly the same `DesktopNames` extension diagnostic as the
packaged entry; the remaining standard keys validate. The root installer retains
its two pre-existing ShellCheck findings (SC2043 and SC2295).
Application defaults and shell exports were preserved through launcher development;
closeout updated comments to describe the verified setup.
The initial offline checks ran without installing or changing the live manager.
The user subsequently installed both artifacts and tested through Ly.

Implementation lessons from 2026-09-11:

- `loginctl` requires separate property flags. The comma-separated query returned
  no output and status 0; individual flags returned the six expected values.
  The fake now models this filtering, matching
  [loginctl's argument parser](https://github.com/systemd/systemd/blob/main/src/login/loginctl.c).
- A failed shutdown-target command previously skipped the explicit compositor
  stop. Cleanup now attempts both and retains metadata if either fails. Tests
  cover this both after normal exit and during signal handling.
- The first login failed at an unnecessary `LoadState` gate. Its original query
  output was lost, so the cause is unresolved; the gate was removed. Only
  `ActiveState` is needed to reject an existing session.
- The second login failed at `reset-failed`: systemd's
  [ResetFailedUnit implementation](https://github.com/systemd/systemd/blob/main/src/core/dbus-manager.c)
  does not load units. Reset now runs only for `ActiveState=failed`. The fake was
  corrected to reproduce the reported unloaded-unit error; the old launcher fails
  that test and the fixed one passes. Earlier passing mocks missed this behavior.
- Read-only checks from a desktop application cannot exercise logind's `self`
  lookup as Ly does. [Ly opens PAM before forking the session](https://github.com/fairyglade/ly/blob/v1.4.1/src/auth.zig).
  The successful real login, not those probes, verified that launch path.

Live checklist (startup and selected environment checks completed; other cases unverified):

1. After reboot, select the isolated entry. Confirm readiness and no deprecated
   import warning in the session output/journal.
2. Check terminal, Fuzzel, wallpaper, clipboard, browser, a Qt app, portals and
   `swayidle.service`.
3. Inspect only selected environment names in Niri and an ordinary user service:
   IPYTHONDIR/CENTRAL_VENVS and Cargo's PATH addition should be absent there and
   present in a newly opened Zsh. Check the configured app defaults too.
4. Log out and back in without rebooting; confirm teardown and fresh session IDs,
   functioning display sockets and metadata. Socket names may be reused; they do
   not need to change. Record the outcome when checked.
5. Check real SSH and separate TTY logins when available; their environment
   redesign remains deferred.

Useful checks after the isolated login:

```sh
systemctl --user show niri.service -p ActiveState -p SubState
systemctl --user --no-pager status swayidle.service xdg-desktop-portal.service
journalctl --user -b -u niri.service --no-pager -n 60
```

The expected Niri state is `active` / `running`. The launcher's own stdout/stderr
goes to `~/.local/state/ly-session.log` with the current Ly configuration; compositor
output goes to the user journal. On a failed login, preserve that log from a TTY
before retrying, since Ly may replace it on the next login. Stock “Niri” remains
the recovery entry.
