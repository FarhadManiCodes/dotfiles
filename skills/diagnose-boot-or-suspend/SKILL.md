---
name: diagnose-boot-or-suspend
description: >
  Investigate a boot or suspend/resume that misbehaved on this machine, using the journal as
  the primary evidence source. Use when a resume failed or hung, the machine did not sleep or
  did not wake, wifi or audio did not come back, the lid did nothing, the battery drained
  overnight, boot was slow or degraded, a user unit failed at startup, or the laptop was
  "weird overnight". Covers choosing the right boot, counting before reading, freezer and FUSE
  state, the suspend retry-loop signature, and which probes have given wrong answers here.
---

# Diagnosing a boot or suspend on this machine

Read-only throughout. Every command below can be run as the normal user — the journal is
readable without root, and nothing here changes system state.

## Before any command: three rules

**1. An empty result is not a negative result.** A typo'd unit name and a genuinely quiet unit
are byte-identical — both print `-- No entries --`, both exit `0`. Confirm the unit exists
before its silence means anything:

```bash
systemctl list-unit-files 'systemd-suspend*'      # does the name resolve at all?
```

The general form of this rule, with five more instances, is in `CLAUDE.md` under "Verifying
claims". It is the single most common way a diagnosis here goes wrong.

**2. Reproducing anything requires being unplugged.** `HandleLidSwitchExternalPower=lock`, so
closing the lid on AC only locks — it does not suspend. A "cannot reproduce" on mains is not a
result.

**3. Say what the evidence proves and what you inferred.** Never invent a detail to fill a gap.
If a probe could not answer, report that it could not, rather than reporting what it returned.

## Step 1 — pick the boot

```bash
journalctl --list-boots
```

Then the question that decides everything else: **was the machine power-cycled?** If it was, the
event is in `-b -1` and the current boot is irrelevant. If it recovered on its own, the event is
in `-b 0`.

**Boot indices shift with every reboot.** A boot that is `-13` today is `-14` after the next
restart. Select by the date column and re-derive the index each session; never reuse one written
down earlier — including the ones in this skill's own fixture.

## Step 2 — count per boot, before reading any instance

A single failure and a 456-attempt storm produce *identical* log excerpts. Reading one instance
cannot tell them apart; only counting can.

```bash
b=-1     # the boot chosen in step 1
for p in 'Starting System Suspend' 'Failed to freeze unit' 'System returned from sleep'; do
  printf '%-30s %s\n' "$p" \
    "$(journalctl -b "$b" -u systemd-suspend.service --no-pager | grep -c "$p")"
done
```

`System returned from sleep operation` is the only line that proves the machine actually slept.
Its **absence** is the finding, not the presence of any error.

This step is not ceremony. It is what found a wrong number in `CLAUDE.md` on 2026-09-06: a
figure recorded as "916 suspend attempts" was two different lines summed, each logged once per
attempt. See `references/incident-2026-09-02.md`.

## Step 3 — classify and route

| What the counts show | Go to |
|---|---|
| Suspends attempted and aborted, or the machine never slept, or did not wake | `references/suspend.md` |
| The machine booted but something was missing, late, or failed at startup | the boot section below |

Read the matching one before drawing any conclusion. `references/incident-2026-09-02.md` is the
worked example for the suspend path and is worth reading first if the shape is unfamiliar — it
carries a healthy cycle and a failed one side by side.

## Boot problems

General `systemd-analyze` usage is not repeated here. Only what is specific to this machine:

**A user unit ordered against `network-online.target` is inert, and silently so.** The target
does not exist in the user manager:

```bash
systemctl --user show network-online.target -p LoadState     # LoadState=not-found
```

A missing `Requires=` would be reported by `systemd-analyze verify`; a missing `Wants=` is legal
and silent by design, so nothing catches this. The mechanism that *does* work for a unit
starting before the network is `Restart=` with a `StartLimitIntervalSec`/`StartLimitBurst`
window wide enough for the backoff to fit inside. Measured once here: on a boot where wifi took
103 s, `rclone@gdrive` failed its first attempt on DNS and the retry had the mount serving 4.6 s
after the network became usable — as early as any ordering could have managed.

**Failed user units leave a persistent record, not just a notification.**

```bash
systemctl --user --failed
cat ~/.local/state/service-failures/failures.log
```

A mako popup is useless if nobody was at the machine, which is why `notify-failure@` writes the
log as well. Repeated identical entries a few minutes apart are a restart loop, not several
separate faults.

**Crashes:** `coredumpctl list -n 20`. **Initramfs and package-transaction failures:** do not
re-derive these — `bash/config-drift` already scans the last pacman transaction for scriptlet
errors and for an initramfs rebuild that never reported success. Run it and read that section.

## Leaving the system as you found it

Every probe in this skill and its references is read-only. If a diagnosis suggests a change,
propose it — do not apply it inside the investigation, because a system that has been modified
mid-diagnosis can no longer be compared against the baseline the next step needs.
