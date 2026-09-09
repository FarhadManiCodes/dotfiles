# Suspend, resume, and the freezer

Read after step 3 of `SKILL.md`. Everything here is read-only.

## Start with `unblock-fuse`'s own log — silence is a finding

This is the cheapest and most informative probe on this machine, and it comes first.

```bash
journalctl -t unblock-fuse -o short-iso --no-pager | tail -20
```

`system-sleep/unblock-fuse` logs **one line per suspend, including the case where it finds
nothing** (`pre: no wedged FUSE tasks, nothing to do`). That was deliberate, and its source says
why: without a line for the boring outcome, "nothing in the journal" means both *ran and found
nothing* and *never ran at all*. Those are not the same, and the ambiguity is exactly what let
the sibling `restart-swayidle` hook sit dead through 1002 resumes before anyone noticed.

So:

| What you see | What it means |
|---|---|
| One line per suspend attempt | The hook ran. Its verdict is on the line. |
| `aborted connections: …` | It found a wedge and released it. This is the failure case, handled. |
| `were mid-request but cleared within 2s, left alone` | A slow mount, correctly not touched. |
| **No line for a suspend that happened** | The hook did **not** run. Check it is installed and executable. |

A hook that has lost `+x` is installed, current, and dead — `systemd-sleep` runs only
executables and says nothing about the rest. `bash/config-drift` checks this too; run it rather
than testing by hand.

## The two shapes

`references/incident-2026-09-02.md` carries a healthy cycle and a failed one verbatim, with the
per-boot counts. Read it before interpreting a cycle you have not seen before.

The two things most easily got wrong, both recorded there:

- **A stage fails by substitution, not only by absence.** The freeze line is not missing from a
  failed cycle; it is replaced by `Failed to freeze unit 'user.slice': Connection timed out`.
  Diagnosing by "which line is missing" misses it entirely.
- **The freeze failure does not stop the sequence.** systemd logs it and attempts the suspend
  anyway; the abort lands one line later, from the kernel, as `Device or resource busy`. One
  cycle can contain two distinct failures of which only the second stops anything.

## Is anything wedged right now?

Three probes, cheapest first. Healthy answers are given so an unfamiliar reading is recognisable
as abnormal rather than merely unfamiliar.

```bash
systemctl show user.slice -p FreezerState --value      # healthy: running
```

Anything else — `frozen`, `frozen-by-parent` — means the user manager is still held. A post-sleep
hook cannot talk to the user manager while this is true; a call into it dies at once with
`Transport endpoint is not connected`, which is why `unblock-fuse` hands off to a transient unit
via `systemd-run --no-block` rather than acting directly.

```bash
for c in /sys/fs/fuse/connections/*/; do
  printf '%s waiting=%s\n' "${c##*/connections/}" "$(cat "$c/waiting" 2>/dev/null)"
done
```

Healthy is `0` on every connection. A non-zero `waiting` is a request the filesystem has not
answered, and a task blocked on one is uninterruptible: the freezer cannot freeze it and
`SIGKILL` does not reach it. Writing `1` to that connection's `abort` releases the waiter —
verified on kernel 7.2.2 — at the cost of tearing the mount down.

```bash
for s in /proc/[0-9]*/status; do
  [ "$(awk '/^State:/{print $2; exit}' "$s")" = D ] || continue
  p=${s%/status}; printf '%s %s %s\n' "${p#/proc/}" \
    "$(cat "$p/wchan" 2>/dev/null)" "$(tr -d '\0' < "$p/cmdline" 2>/dev/null)"
done
```

A `D` state with `wchan` of `request_wait_answer` (or anything containing `fuse`) is the wedge.

**Read the state from `/proc/PID/status`, never `/proc/PID/stat`.** The latter is
`pid (comm) state …` and `comm` may contain spaces, so a positional field lands inside the
process name instead of on the state. That is an instance of the second rule in `CLAUDE.md`
under "Verifying claims", and it is already encoded in `unblock-fuse`'s own source.

## The retry loop

With the lid shut, logind retries a failed suspend indefinitely. Each attempt takes roughly
100 s — that is the *duration of one failed attempt*, not a delay between them; the journal
records it as `Consumed … CPU time over 1min 41.743s wall clock time`. The retry begins
immediately after.

This is why one wedged process costs a whole night rather than one failed suspend, and why every
retry also re-runs whatever else is hooked into the sleep path. On 2026-09-02 that included the
since-removed `fix-wifi.sh`, which cycled the wifi module on every attempt and turned one stuck
`du` into a notification storm.

## What else runs across a suspend

Check the current state of these rather than trusting this list — it is what the path looked like
when this file was written, and units get added.

```bash
ls ~/dotfiles/systemd/user/
systemctl --user list-units --all --plain --no-legend 'rclone@*'
```

At the time of writing: `swayidle.service` locks via `bash/lock-once` (a no-op when a live
swaylock already exists, so a repeated `before-sleep` cannot queue locks); `unblock-fuse` runs
`pre` and `post`; and `rclone@gdrive` / `rclone@Dropbox` are restarted by `unblock-fuse`'s
transient remount unit, but **only** when `pre` actually aborted something.

`ath11k_pci` is **no longer** unloaded and reloaded around suspend — that hook was removed on
2026-09-04 after nine measured resumes showed wifi returning every time and faster without it.
If wifi does not come back, confirm what the current sleep path contains before assuming a
module reload happened; the probe that settled it last time was whether the interface name had
incremented, which proves whether the module was actually reloaded.

## Battery drained overnight, or the machine was hot in the bag

Same investigation, different entry point. The machine never slept, so run step 2 of `SKILL.md`
and check whether `System returned from sleep operation` appears at all. A count of zero against
hundreds of attempts is the signature; see the fixture.
