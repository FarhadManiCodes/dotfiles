# sysclean (`zsh/functions/sysclean.zsh`)

`sysclean` automatically starts in shpool through `keep`, or runs in the current
shpool session. Closing the terminal leaves cleanup running; `attach` or Mod+A
reconnects. `--all`/`-a` still selects deep cleanup.

## CLI release pruning

Step 1 keeps Claude's current binary and one fallback as before. Step 9, after
Claude Code file-history cleanup, prunes Codex's separate `standalone` and
`app-server-daemon` release trees.
For each tree, the `current` symlink must resolve to a complete release directly
inside `releases/`; a missing or unexpected target stops pruning that tree.
The newest other complete release is kept for rollback. Only version-named
directories are eligible, so installer staging files are left alone. `fuser`
keeps a release whose Codex or code-mode-host executable is still in use for
another run; without `fuser`, Codex pruning is skipped.

On 2026-09-28, `sysclean` removed about 2.1 GiB of older releases. Both trees
now contain the selected 0.158.0 and rollback 0.157.1 releases.
This cleanup needs no sudo and runs only when `sysclean` is invoked.

## NVMe health — the one hardware fault nothing else would report

`_sysclean_nvme_health` runs as step 11. Everything else here that can fail
silently has a watcher — `config-drift`, `notify-failure@`, `sysup`'s health step — a
dying disk did not.

**Why `sysclean` and not `sysup` or a timer.** `smartctl` can't open an NVMe controller as
a normal user, so a plain user timer could never have worked. `sysclean` already holds a
sudo credential from step 2; `sysup` doesn't reliably (its only sudo is the at-most-
quarterly fwupd refresh). `smartd` stays rejected: it's built for polling several ATA
disks, and this is one NVMe — a daemon where a command will do.

**Why not `smartctl -H` alone.** That reports the drive's own pass/fail flag, derived from
`critical_warning`, which trips late. The fields that move first are in the same log for
free, so the check also warns on spare capacity below the drive's own threshold, wear at
80% of rated write endurance, and any media/data-integrity errors. A healthy run prints
one line: endurance used, spare, temperature, hours powered on.

**Not gated to an interval**, unlike fwupd and mirrorlist — those cost a network fetch or
a root write; this costs milliseconds under a credential already granted, and a disk can
go from healthy to failing well inside a quarter.

A missing or non-numeric field is reported as **"health NOT checked"**, never as good
news — an empty answer must never read as a clean bill. Verified against the real drive's
output plus fabricated worn/failing/malformed/empty fixtures; all five branches behave.
Needs `jq`; skips with a message if either tool is absent.

Interacts with the off-machine backup gap (`TODO.md`) — a health warning is only
actionable if there's somewhere to restore from.

## sysclean's removals — glob qualifiers are not decoration

Every `rm` takes an array built with `(N)`, never a bare pattern. In zsh a pattern that
matches nothing is a **fatal error for the whole command**, so `rm -f a/download-*
a/*.part` removes *neither* set when either one misses — and the error escapes
`2>/dev/null`, since globbing happens before the redirection applies. Not hypothetical:
with nine `download-*` files and no `*.part`, step 2 removed none of the nine and printed
`no matches found` every run (2026-09-17); step 7 then printed "coredumps cleared" over a
removal that never ran. `bash` forgives all of this, which is why the rule is `zsh -n` for
zsh files and never a Bash-only check. `rm -f` with zero arguments exits 0, so collecting
first is safe when everything is empty.

Pacman's `download-*` leftovers can be private staging **directories**, too.
Step 2 uses `rm -rf` on the collected paths to cover them and `.part` files;
a failed removal reports failure instead of claiming success. This was found
on 2026-10-10: four staging directories remained after a completed transaction,
and the previous `rm -f` could not remove them.

**The file-history prune refuses an empty answer.** Step 8 removes
`~/.claude/file-history/<id>/` with no matching `projects/**/<id>.jsonl`. If the session
glob finds nothing, it reports that and prunes nothing — "no sessions" means the probe
failed, not that every undo snapshot is orphaned, and the layout belongs to Claude Code,
which is free to change it. Same rule as "health NOT checked" above.

**npm is the one cache wiped only under `--all`.** `uv` gets `prune`/`clean`, `ccache`
`-c`/`-C`; npm has no prune equivalent, so its only action is a full wipe — a deep-clean
act that also undoes itself, since `sysup`'s bgutil rebuild runs `npm ci` and
re-downloads everything.

`tests/test_sysclean.py` covers all of the above; each glob and guard case was confirmed
to fail against the pre-fix code before being kept.
