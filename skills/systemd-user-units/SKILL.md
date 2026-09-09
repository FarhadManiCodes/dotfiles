---
name: systemd-user-units
description: >
  Write or change a systemd user unit or a suspend/resume sleep hook on this machine. Use when
  something needs to run at login, on a timer, in the background, or around suspend and resume;
  when adding a .service, .timer or template unit; when a unit needs to wait for the network or
  restart on failure; or when editing anything under systemd/user/ or system-sleep/. Covers the
  orderings that are silently inert here, how failures get reported, and why a sleep hook cannot
  talk to the user manager.
---

# Writing a user unit or a sleep hook here

Most of what goes wrong in this area fails **silently** — the unit loads, systemd reports
success, and the thing simply does not happen. The rules below each exist because that already
occurred.

## Where things go

| Kind | Repo path | Installed by |
|---|---|---|
| User unit (`.service`, `.timer`, `@.service`) | `systemd/user/` | `install.sh`, symlinked |
| Sleep hook | `system-sleep/` | `install-root.sh`, **copied**, `0755` root-owned |

After adding or editing a unit: `systemctl --user daemon-reload`. The live units are symlinks
into this repo, so editing the repo edits the running configuration — a reload is all that is
needed, not a reinstall.

**`install.sh` enables units from an explicit list, not a glob.** If you add a unit that should
start at login, add it to that list. A glob is wrong three ways: it cannot enable a template
(`rclone@.service`), it never enables the instances you actually want, and it would pull
`study-library-sync.service` into `graphical-session.target` when its **timer** is what should
drive it.

## Never order against `network-online.target`

It does not exist in the user manager, and a user unit cannot order itself against a system
unit. The ordering is inert on *every* machine, not just this one.

What makes it dangerous is that nothing catches it. Verified:

```
Wants=network-online.target      →  systemd-analyze --user verify: exit 0, no output
Requires=network-online.target   →  "Unit network-online.target not found", exit 1
```

A missing `Requires=` is reported; a missing `Wants=` is legal and silent by design. **The only
remedy is not writing the line.** Both `rclone@.service` and `study-library-sync.service`
carried it until 2026-09-04, one with a comment defending it.

### What works instead

`Restart=` plus a `StartLimitIntervalSec`/`StartLimitBurst` window wide enough for the backoff
to fit inside. That is not a workaround — it is strictly better than any ordering could be.
Measured on a boot where wifi took 103 s: `rclone@gdrive` failed its first attempt on DNS and
the retry had the mount serving **4.6 s after the network became usable**, which no ordering
could have beaten, because there was no DNS before that.

Shortening the doomed first attempt was considered and rejected: it fails sooner without
mounting sooner.

## Every unit gets `OnFailure=`

```ini
[Unit]
OnFailure=notify-failure@%n.service
```

This raises a mako notification **and** appends to
`~/.local/state/service-failures/failures.log`, because a popup is useless if nobody is at the
machine.

It matters more than it looks. `Restart=on-failure` with the default limits
(`StartLimitBurst=5` in 10 s) means a unit that keeps failing stops retrying and sits in
`failed` — and without `OnFailure=` nothing reports that. Five units here lacked it until
2026-09-06, `swayidle` among them, which meant the screen could stop auto-locking with no
signal at all. Worse, `failures.log` looked reassuringly empty precisely because it could not
record them.

**`notify-failure@.service` itself deliberately has none**, and `bash/service-failed-notify`
always exits 0 — a notifier that notifies about its own failure loops.

Check the current state with `systemctl --user --failed`.

## Sleep hooks

A hook is `$1 = pre|post` and runs as **root**, from `/usr/lib/systemd/system-sleep/`. Three
rules, each learned expensively.

**It must be executable.** `systemd-sleep` runs only executables and says nothing about the
rest — an installed, up-to-date, non-executable hook is simply dead. `install-root.sh` installs
`0755`, and `bash/config-drift` checks the bit on every `sysup`, because that is how a sibling
hook sat inert through 1002 resumes.

**A `post` hook cannot talk to the user manager.** It runs while `user.slice` is still frozen,
so `systemctl --user --machine=…` dies immediately with `Transport endpoint is not connected`.
It fails *fast*, so backgrounding does not help — and `systemd-suspend.service` is
`Type=oneshot` with `KillMode=control-group` (verified), so any child left behind is SIGTERMed
the moment the hook returns.

The way out is a transient unit that outlives the cgroup:

```sh
systemd-run --no-block --collect --unit=my-hook-followup "$0" followup
```

…and have that followup poll `systemctl show user.slice -p FreezerState --value` until it
reads `running`.

**Log every outcome, including the boring one.** Without a line for "ran, found nothing",
silence in the journal means both that and "never ran at all" — and those are not the same.
`system-sleep/unblock-fuse` logs one line per suspend for exactly this reason; read it as the
worked example rather than inventing a new shape.

## Before finishing

```bash
systemd-analyze --user verify systemd/user/<unit>      # catches Requires=, not Wants=
systemctl --user daemon-reload
bash bash/config-drift                                 # unit verification + sleep-hook +x
```

Remember `systemd-analyze verify`'s silence is not evidence of correctness — it is exactly the
tool that cannot see the most common mistake here.

Deeper reasoning for individual decisions lives in the units themselves:
`systemd/user/rclone@.service` carries the network-ordering post-mortem, and
`system-sleep/unblock-fuse` carries the freezer and hand-off reasoning. Read those rather than
re-deriving them.
