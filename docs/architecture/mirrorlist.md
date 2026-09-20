# Mirrorlist — the one check that runs before the update

`_sysup_mirrorlist_check` (2026-09-09) runs **before** `paru -Syu` rather than joining
`config-drift` at the end — by then the update has already fetched from whatever mirrors
the file holds, so a warning couldn't change anything.

It asks two questions, because either alone misleads:

- **Age** is a `stat`. Nothing re-ranks the list automatically and speed drifts as
  mirrors and routes change. Warns past 90 days, the window the fwupd metadata step also
  uses.
- **Validity** needs the network. Arch delists a mirror that falls out of sync, and a
  delisted mirror keeps serving a stale database without erroring — so a file written
  yesterday can hold a mirror that broke this morning. Each `Server` line is matched
  against `archlinux.org/mirrors/status/json/` and reported if no longer listed, marked
  inactive, incomplete (below 95% of Arch's 96 daily checks), or a day+ behind upstream.
  The 95% floor came from the published population (of 1229 active mirrors, 980 sit at
  exactly 100%, 57 between 95-99, 178 below 90) after a stricter `<100%` rule immediately
  flagged a mirror that had missed one check.

The validity half is best-effort by design: an 8-second timeout, and being offline
reports **"NOT checked"** rather than failing `sysup` or passing quietly — an empty
answer must never read as good news.

**Rehearsing the warning.** The half that matters fires twice a year, so the function
takes two optional arguments purely so it can be exercised on demand: `$1` is the stale
threshold in days, `$2` a mirrorlist to inspect instead of the live one (reports without
offering to re-rank, since `mirrorlist-rank` writes `/etc/pacman.d/mirrorlist` and
offering it would act on something other than what was measured). `sysup` passes neither.

**It offers the fix rather than printing it.** Both findings have one answer,
re-ranking, and before `paru` is the moment it's worth doing. Never automatic — ranking
times every healthy candidate (~50 mirrors, ~15s) — so the check asks and Enter declines;
with no terminal it prints the command instead, so a scripted `sysup` can't block on a
prompt nobody will answer. The work itself is `bash/mirrorlist-rank`, the only thing that
should ever write that file — procedure and recovery in [mirrorlist-rank](mirrorlist-rank.md).
