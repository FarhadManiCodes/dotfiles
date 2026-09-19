# `config-drift` — catching config upstream has moved out from under

`bash/config-drift` reports settings that have quietly stopped meaning what they used to.
Run by `sysup` after every update, or by hand; read-only, needs no root, `-v` for full
diffs.

It exists because this failure is silent by construction — nothing errors, the config
just does less. Two instances in one week prompted it: `tmux-power` stopped honouring
`@tmux_power_time_format` so the clock began showing seconds, and nine `.pacnew` files had
been accumulating since May because nothing looked for them.

Checks cover pending `.pacnew`, pacman transactions, tracked root copies, Spotify's local
copy, `/etc` baselines, symlink integrity, plugin staleness and user-unit verification. A
rendered tmux status-bar check was removed 2026-09-08 (the bar is visible at a glance).
Unit files are verified with `systemd-analyze --user verify`; the verifier's exit status
is checked as well as its output.

**Spotify's intentional user copy is checked too** (2026-09-06), via Python's `tomllib`
comparing parsed `spotify-player/app.toml` settings, excluding only top-level
`client_id`. Comments/order/formatting don't count as drift; nested settings and blank
template values do. Missing/unreadable/invalid files or an unavailable parser are
reported as not compared, never as clean.

**Standalone runs inspect the last pacman transaction.** `sysup` records the log's
`device:inode:bytes` boundary before `paru`, then passes it with `--pacman-since` so every
subsequent transaction is checked separately — a later clean transaction can't hide an
earlier recognised error. If `paru` fails, diagnostics run before returning its original
exit status and later steps are skipped. Missing boundaries, unreadable logs and detected
replacement/truncation all produce warnings. Message matching is heuristic (success
matching within each transaction rather than per initramfs image), and a hard
interruption can bypass checks entirely.

**The symlink check verifies `install.sh`'s tracked mappings** — missing links, links
replaced by a file/directory, or resolving to the wrong target. Vim/Neovim and skill
directories, Quadlets, helper scripts and special app destinations are mapped explicitly;
keep these in sync when changing the installer. Root copies, Spotify's `app.toml`,
generated files and anything not installed by `install.sh` aren't required to be links;
Firefox is checked only when a default profile exists. Checks report findings only — they
never repair links or prove every untracked file is configured.

**The root-config check exists because `install-root.sh` copies**, not links: those files
can drift from the repo in either direction with nothing else to notice, and `.pacnew`
can't see them since they're owned by no package. Reports differing copies for review
(mtimes don't establish which side should win; `cmp` failures are distinguished from
content differences). Files needing unavailable root access print as **not compared** and
count as incomplete, never as an all-clear.

**The general lesson:** the obvious check — "does the plugin still read my option" — is
grep-able and **wrong**. `tmux-power` reads every `@tmux_power_*` through one batched
regex and never names an option in its source, so a naive grep-based check would report
every option dead. Worse, it would miss the real regression: the option *was* still read
into a variable, but the code using that variable had been replaced by a hardcoded value.
Assert on observable behaviour, not on configuration.
