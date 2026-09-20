# mirrorlist-rank — measuring speed from this machine, not trusting a lookup

`bash/mirrorlist-rank`, linked into `~/.local/bin`:

```bash
mirrorlist-rank              # the fastest 20 from here; changes nothing
mirrorlist-rank --install    # install them, keeping a .bak
mirrorlist-rank -n 5 -c AT   # five fastest Austrian mirrors
```

**Candidates are filtered before anything is timed.** They come from
`archlinux.org/mirrors/status/json/` rather than the mirrorlist generator, so the filter is
stated here rather than inherited: https, IPv4, active, no more than 24 h behind, and
`completion_pct >= 0.98` — at most two failures out of the 96 checks Arch runs per mirror per
day. A mirror that would later trip `sysup`'s validity check should never have been ranked into
the list to begin with. For `DE` on 2026-09-09 that leaves **49 candidates of 54**; requiring a
perfect record (`--min-completion 1`) leaves 44. The generator's own `use_mirror_status=on`
turns out to mean only "active and under 24 h behind" — it returned exactly those 54 — and
offers no way to exclude a mirror that keeps failing checks.

**https only, IPv4 required**, both measured rather than assumed. Of 152 active `DE` mirrors,
58 offer https, 53 are http-only and 41 rsync — so insisting on https still leaves far more
than the ten needed. Packages and databases are signed, so http is not a tampering risk for
*content*; https is about not advertising which packages this machine downloads, and about
middleboxes. Of those 58, 50 are dual-stack, 8 are IPv4-only and **none is IPv6-only**, and
this machine has no global IPv6 address (a `curl -6` fetch fails outright), so requiring IPv4
excludes nothing and stays correct if IPv6 arrives later.

Note the two thresholds differ on purpose: **select at 0.98, warn at 0.95.** Being fussy about
what goes *into* the list is free, while warning about a list already in place should mean
something is actually wrong.

Arch's own `score` and `duration_avg` are deliberately *not* used as filters. They are timed
from Arch's infrastructure, and speed from this machine is the one thing that has to be
measured here.

**Every surviving candidate is timed, not just enough to fill the list.** Which mirrors are
fastest from this connection is precisely what Arch's health data cannot say, so picking the
best 10 means measuring all 49.

**Ranking is a measurement, not a lookup.** `rankmirrors` downloads from every candidate — 54
for `DE` on 2026-09-09 — and orders them by speed observed *from this machine*, so the answer
is specific to here, this connection and this moment. It takes minutes, which is why nothing
runs it automatically. `use_mirror_status=on` asks Arch to drop mirrors it already knows are
out of sync, so only healthy candidates are timed.

What each test actually fetches is `<mirror>/core/os/x86_64/core.db`, about 126 KB, with a 10 s
per-mirror timeout — responsiveness on a small file rather than sustained bandwidth, which is
the right question for a package mirror but worth knowing before reading much into the order.
The script passes `-r core` so the repo is named rather than guessed from URL shape, and `-w`
so a mirror that fails to answer during the test is dropped instead of merely ranked last.

**One pass, and twenty entries — because the ranking is noise-dominated and cannot be fixed
by averaging.** This was measured, and the measurement went against the intuition:

- Two single-pass runs twenty minutes apart shared 6 of their top 10.
- Median-of-3 was then implemented, and two consecutive median-of-3 runs also shared **6 of
  their top 10**. Averaging bought nothing.
- The arithmetic explains it. Ten repeated fetches from one mirror spread over **54 ms**
  (median 0.167 s), while adjacent ranks differ by about **3 ms**. Averaging cuts noise by
  √n, so separating neighbours needs on the order of **300 passes**.

So the boundary of the list is not determinable, and the answer is to stop trying to resolve
it: take **20** entries instead of 10 and let the cut-off fall somewhere that does not matter.
pacman uses the first working server and descends only on failure, so the extra ten are free
while the top is healthy, and the whole top forty is within a factor of two anyway. A single
pass over ~50 mirrors takes about 15 s.

`--passes N` remains and takes the median (not the mean — one stalled fetch moves a mean far
more than the middle value). Its benefit is narrow: it stops a single fluke evicting a good
mirror. With 20 slots that eviction is inconsequential, which is why it is not the default.

Rejected: timing `extra.db` (8.9 MB) rather than `core.db` (129 KB) would make throughput
dominate the latency jitter and give a sharp ranking — at ~450 MB pulled off other people's
mirrors per pass, to reorder a set within 25 ms of itself.

**The timing is sequential, and must stay that way.** `rankmirrors -p` exists and its own help
says it "may be inaccurate": parallel downloads share one connection, so they measure
contention with each other rather than each mirror. Do not add it to make a run faster.

A dry run also **says whether it would change anything**: it compares the ranked set against
the live list and reports what would be added and dropped, or that the set is identical and a
re-rank would only reorder it. That is the question worth answering before spending minutes on
a measurement, and it is why the plain form is worth running on its own.

Output is filtered to `Server` lines before ranking. Arch's generator prefixes every mirror
with its own `## <Country>` line and `rankmirrors` passes comments through verbatim, so
without that the ten results arrive buried under 54 identical headers. The installed file gets
one provenance line naming the date, country and that the order is measured.

`sysup` checks the file before every update and offers to run this when it finds a problem —
see [mirrorlist check](mirrorlist.md).

**If a re-rank goes wrong**, the previous list is one command away:

```bash
sudo mv /etc/pacman.d/mirrorlist.bak /etc/pacman.d/mirrorlist
```

The script exists rather than a three-line pipeline because of four things, each verified
2026-09-09:

- **Never pipe into `sudo tee`.** `rankmirrors … | sudo tee /etc/pacman.d/mirrorlist` truncates
  the target when the shell *builds* the pipeline, before `curl` or `rankmirrors` has produced
  a byte. A failed fetch leaves an empty mirrorlist and pacman with nowhere to go. Demonstrated
  on a scratch file: a failing producer left it at 0 bytes. The script stages to a temp file and
  refuses to install a list that came back empty.
- **The `.bak` is the recovery, so it is made first.** Of the 763 files in
  `/var/cache/pacman/pkg` none is a `pacman-mirrorlist` package, so there is nothing to extract
  offline and an unbacked overwrite cannot be undone.
- **A `.bak` beside the live file is inert.** `/etc/pacman.conf` `Include`s the literal path,
  not a glob, so the spare file is never read as extra mirrors.
- **A package upgrade will not clobber your list.** `/etc/pacman.d/mirrorlist` is a `Backup`
  entry of `pacman-mirrorlist` and reads `[modified]`, so an upgrade leaves a `.pacnew` beside
  it, which `config-drift` reports like any other.

`-c DE` is the default and the one thing to change if this machine moves; `rankmirrors` comes
from `pacman-contrib`, and `reflector` is deliberately not installed.
