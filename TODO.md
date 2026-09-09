# TODO — actions that need me, not the config

Only open items live here. Closed ones are removed rather than struck through: the
reasoning worth keeping is in `revisit.md` (investigated and deliberately accepted) and
`docs/architecture.md` + `docs/system-notes.md` (how the system works now). Everything else is in git — the July–August audit
is `git show c940d78:AUDIT-2026-08.md` (deleted 2026-09-08), and the last version of this
file carrying items 1–16 is `git show 92bcf79:TODO.md`.

**Item numbers are stable and gaps are deliberate.** Other files cite them, so a closed item
leaves its number empty rather than shifting the rest. Closed on 2026-09-08 and removed here:
§4 (the Omarchy first pass — the `-Qii` vs `-Qkk` measurement it held now lives in
`etc/README.md`), §7 (the doc-duplication sweep) and §8 (the `duckdb/.duckdbrc` rewrite, whose
every removal is explained inline in that file). Closed on 2026-09-09: §9 (`jupytext` not
installed — the finding compared against a superseded uv-tool plan; per-venv is the accepted
setup and the absence is expected, see `revisit.md`). The state of the last tidy was verified
rather than assumed: the three stray `.bak` files are gone, `~/.local/bin/check-skills` is now linked,
and the udev and TLP changes have reached `/etc`.

---

## 1. No NVMe health check

`smartmontools 7.5-1` is installed and `smartctl` works, but nothing runs it. `smartd` was
rejected in August as built for multi-disk ATA rather than one NVMe, and that still holds — the
lighter answer is a user timer running `smartctl -H /dev/nvme0` weekly.

This is the one hardware fault nothing here would warn about. Everything else that can fail
silently now has a watcher (`config-drift`, `notify-failure@`, `sysup`'s health step); a dying
disk does not.

Note it interacts with §10 D: a health warning is only actionable if there is somewhere to
restore from.

## 2. `mkinitcpio` builds no fallback initramfs — and the premise here was wrong

`/etc/mkinitcpio.d/linux.preset` has `PRESETS=('default')`, so `/boot` holds one image and
there is no `initramfs-linux-fallback.img`.

**Corrected 2026-09-08: this was not disabled locally.** The previous note said it had been
"disabled deliberately at some point". It was not touched at all — the file is **byte-identical
to `mkinitcpio 41.1`'s own template** at `/usr/share/mkinitcpio/hook.preset`, which ships
`PRESETS=('default')` with every fallback line commented out. Verified by diffing the two with
`%PKGBASE%` substituted. It is also unowned by any package (`etc/unowned.txt` lists the path),
so nothing would restore a different version.

**A second correction, 2026-09-09 — the first one was wrong.** Yesterday this said `etc/README.md`'s
"all 12 GRUB entries share a single image" was unverified, on the grounds that `grub.cfg` holds
only 7 menuentry/submenu lines and 2 references to the image. **That was the wrong probe.**
`grub-btrfs 4.14-1` is installed and `grub.cfg:183` loads `configfile "${prefix}/grub-btrfs.cfg"`,
a separate 12.7 KB file the grep never read. Counted properly: **5 entries in `grub.cfg` and 11 in
`grub-btrfs.cfg`**, with 30 references to `initramfs-linux.img` in the latter alone. The original
claim was right in substance — every entry points at the same image — and only the total drifts as
snapshots come and go. Exactly the corollary in `docs/system-notes.md`: a number from a probe you wrote is
not evidence against a number from a probe you cannot see.

So the real question is not "why was this changed" but **"do we want upstream's default?"** A
fallback image uses the same `HOOKS` without `autodetect`, so it carries every module rather
than only those probed on the building machine. It is the escape hatch when a hardware change or
a module regression makes the trimmed image unbootable — and there is exactly one kernel
installed here, so there is no second entry to fall back to either.

Enabling it is two lines in the preset plus a `mkinitcpio -P`. Against it: it costs ~50 MB more
in a 1.1 GB `/boot` currently at 8%, and Arch turned it off by default for a reason.

## 3. Re-rank the pacman mirrorlist every few months

Regenerated 2026-09-04 with `use_mirror_status=on` through `rankmirrors -n 10`; 10 https servers
active. Nothing automates this and `config-drift` cannot see it — mirror staleness is not a
`.pacnew`, and detecting it needs network access.

Arch delists mirrors that fall out of sync, and a delisted mirror serves a stale database
silently. The previous list had accumulated 96 entries with **12 hosts Arch had already
retired**.

```bash
curl -s "https://archlinux.org/mirrorlist/?country=DE&protocol=https&ip_version=4&use_mirror_status=on" \
  | sed 's/^#Server/Server/' > /tmp/ml
rankmirrors -n 10 /tmp/ml | sudo tee /etc/pacman.d/mirrorlist >/dev/null
```

## 5. Disk encryption — deferred until a rebuild

**Deferred 2026-09-07.** Keep the current installation; no in-place migration is planned.

Retrofitting means a reinstall or a carefully planned, backup-verified `btrfs send`/restore
cycle, so it belongs to the next rebuild. One prerequisite is already in place: `mkinitcpio`
uses the systemd initrd, so `sd-encrypt` and `systemd-cryptenroll` are available.

Reconsider at the next reinstall. This and §10 D are two halves of one threat model, and the
backup is the one to build first.

## 6. Verify the tmux identity segment in the two cases that cannot be tested from here

`bash/tmux-identity` hides `user@host` when local as the usual user, which is confirmed live.
The other two branches were only tested by faking the environment on throwaway sockets: over
**ssh** it should show the bare hostname, and as **another user** the bare username.

Worth a look the next time either happens for real. Note `SSH_CONNECTION` is read from the
environment that started the *server*, so attaching over ssh to a locally-started tmux will
correctly show nothing — that is not a failure.

## 10. Parked from the Omarchy comparison — each needs its own session

`docs/omarchy-comparison.md` proposed five things worth adopting. **A, B and E are done**
(`config-drift` gained the pacman-log and symlink checks, `sysup` gained a lock). The three
below were deliberately not started: each is larger than a config change and would be poorly
served by being squeezed into the end of another session. **F is not one of the five** — it
comes from the third pass and was parked here on 2026-09-08 because it has the same shape.

### C. A test runner

`tests/test_config_drift.py` covers the checker (14 methods, standard-library `unittest`), but
`docs/architecture.md` and `docs/system-notes.md` are full of invariants that still rest on memory. **Copying Omarchy's bash harness
was withdrawn** — it would duplicate infrastructure this repo already has. What remains worth
taking is three of its design decisions:

- `base-test.sh` refuses to be executed directly and discovers the repo root from its own
  location, so tests never depend on the caller's working directory.
- `fail` **exits the file** at the first failed assertion, because later assertions would
  report against state the failure already invalidated. The runner keeps going past a failing
  file and summarises at the end — aborting at the first bad file once masked 114 of their 134.
- Tests **stub the world and run the real code**: a scratch `bin/` of fakes that log their
  arguments, prepended to `PATH`, with `HOME` pointed at a `mktemp -d`.

**The first suite already exists**: `bash/check-skills` (2026-09-06) — no dependencies beyond
coreutils, read-only, non-zero exit on violation. It asserts, for every `skills/*/SKILL.md`,
that the frontmatter opens and closes, that `name` matches the directory and is kebab-case and
contains neither "claude" nor "anthropic", that `description` is a folded block under 1024
characters free of angle brackets that **says "Use when"** (it is a routing rule, so it must
state the trigger rather than the topic), and that every `references/*.md` and `bash/<tool>` it
names exists — the latter also executable. 15 assertions pass across five skills, and it was
verified to fail correctly against a deliberately broken fixture, because a check that cannot
fail is worthless.

It was written because the same assertions had been retyped inline five times in one session,
slightly differently each time, and the fifth run caught a real defect (a description reading
"Use before…" rather than "Use when…") that four hand-reviews had missed.

**Still to do**: fold `check-skills` into a runner alongside the invariant table in
`docs/omarchy-comparison.md` §8 — three one-line greps encoding decisions already argued
(`install.sh` never uses sudo, no user unit orders against `network-online.target`,
`bash/tmux-theme` uses real hex and never `default`). After that, `bash/tmux-identity` and
`bash/lock-once` are the two scripts with real branching and no coverage, both testable with a
stub `tmux`/`pgrep` and a fake `HOME`.

Deliberately **not** asserted: the journal query in
`skills/diagnose-boot-or-suspend/references/incident-2026-09-02.md`. Journal retention drops
that window around 2026-10-21, and a test that fails when the journal rotates is the tmux-power
mistake in a new costume.

Omarchy has **no CI** — 284 test files run by hand. A reasonable model to copy; a workflow can
come later if it earns its place.

### D. Off-machine backup

**Deferred by the user 2026-09-07.** Revisit later; no implementation now.

The gap `docs/architecture.md` names three times. Snapshots share a filesystem with the data, so they
protect against mistakes and not against a dead disk or anything running as root.
`~/projects/omarchy/plans/backup.md` is a revision-2, adversarially-reviewed design that
survives being lifted out of the distribution context. The parts that transfer:

- **restic**, and specifically **not `rclone sync`** — which mirrors deletions and ransomware
  to the destination, and whose versioning is provider-side or a `--backup-dir` hack. rclone
  stays the right transport for `~/Cloud` and the wrong basis for a backup.
- **`--one-file-system` is load-bearing on this machine.** `~/Cloud/gdrive` and
  `~/Cloud/Dropbox` are FUSE mounts under `$HOME`; without it a backup walks into them and
  pulls the whole Drive down through FUSE. What one stray `du` on an rclone mount already cost
  is recorded in the sleep-hook section of `docs/architecture.md`.
- **State the threat model before the feature**, the way the rclone `combine` note already
  does: this defends against disk death, theft and deletion found late. It does **not** defend
  against malware running as this user, because the machine holds credentials that can delete
  from the repository.
- A local destination must **verify the target filesystem's UUID before writing**, or an absent
  USB disk silently gets a backup written into an empty mountpoint on the root filesystem.
- Notification policy worth stealing regardless: a single failed run is silent, no success in
  24 h warns once and then weekly. A one-shot warning lets a dead credential rot for months.
- Two systemd details that cost a debug session each: `Persistent=true` only works on calendar
  timers, and **pause must not be a unit condition** — a `ConditionPathExists`-gated unit never
  runs while paused, so it can never notice the pause expiring.

Interacts with §5 and §1: disk encryption and an off-machine backup are two halves of one threat
model, and a disk-health warning is only actionable if there is somewhere to restore from.

### F. An editor + agent tmux layout — **wanted; own session** (added 2026-09-08)

From `docs/omarchy-comparison.md` §27, not from A–E. **The user rates this important.** We have
exactly one layout, `tmux/layouts/cpp_layout.sh` on `Prefix W`; an editor+agent layout is the
obvious second, and it is a design job rather than a config edit — which panes, what starts in
them, and how it is invoked all need deciding before anything is written.

Their four functions are reproduced here **so this does not depend on the checkout**
(`~/projects/omarchy/default/bash/fns/tmux`, read at `36e56f4f`). Theirs is bash and ours would
follow `cpp_layout.sh` — a script in `tmux/layouts/` run by `bind-key … run-shell` — so nothing
ports literally; the value is the shapes and the techniques.

| Function | Shape |
|---|---|
| `tdl <ai> [ai2]` | Current window renamed to the directory. Editor pane top-left, terminal strip along the bottom (15%), AI on the right (30%). A second AI splits the AI pane. |
| `tds` | A 2×2 square: editor, `hunk diff --watch`, terminal, `opencode`. We have no `hunk`, so the diff pane needs a local answer. |
| `tdlm <ai> [ai2]` | One `tdl` window per subdirectory of `$PWD`; renames the session after the parent. |
| `tsl <n> <cmd>` | N tiled panes all running the same command — a "swarm" for agents. |

Techniques worth taking, which is the real content:

- **`$TMUX_PANE` rather than "the active pane".** A stable handle that survives the active
  window changing under you mid-script.
- **`split-window … -P -F '#{pane_id}'` returns the new pane's id** (`%3`), so every later
  `send-keys` addresses a pane explicitly instead of assuming where focus landed.
  `cpp_layout.sh` currently relies on focus following the split, which works but does not
  compose past two panes.
- **`send-keys -t <pane> -l "text"` then a separate `C-m`.** `-l` sends the string literally,
  so a command containing something like `C-m` or `Enter` is not reinterpreted as a key. They
  do this in `tds` but not in `tdl` — copy the `tds` form.
- **`-c "$current_dir"` on every split**, or panes open wherever tmux felt like.
- **`tr '.:' '--'` on a session name** — tmux disallows dots and colons.
- `select-layout tiled` after each split is what keeps `tsl` even.

Two corrections to make when writing ours, both verified 2026-09-08:

- **`tdl` has a live bug.** Its last line is `tmux select-pane -t "$opencode_pane"`, and
  `opencode_pane` is never set in that function — it is declared in `tds`. tmux gets an empty
  target, so the "select the nvim pane" the comment promises does not happen. Should be
  `$editor_pane`.
- **`-p 15` is the old spelling.** Both `-p 15` and `-l 15%` are accepted by tmux 3.7c here
  (tested on a throwaway server), but `-l %` is the current form and `cpp_layout.sh` already
  uses the percentage style via `resize-pane -y 30%`.

Open questions for that session: which agent(s) and whether the choice is an argument or fixed;
whether it replaces or sits beside `Prefix W`; whether the `tdlm` per-subdirectory and `tsl`
swarm shapes are wanted at all, or just the single layout.

## 11. 61 `git fsmonitor--daemon` processes, 318 MB — premise corrected 2026-09-09

Rechecked on a 37-minute-old boot: **61 daemons, 318 MB**, matching the 62 / 326 MB and
61 / 319 MB of the two earlier counts. The number is stable across reboots, but everything
this item assumed about *why* was wrong.

**They are not duplicates, and nothing is leaking.** Every daemon binds a distinct
repository. The August probe (`cwd`, command line) could not tell them apart because a
detached daemon inherits the cwd of whatever started it; the probe that does work reads the
IPC socket each one listens on:

```bash
ss -xlp | grep -o '/home[^ ]*fsmonitor--daemon.ipc'   # one line per daemon, names the repo
```

`uniq -c` over those 61 paths returns 1 for every single one. So "61 suggests they are
accumulating rather than being reused" is refuted: one daemon per repository is exactly what
is happening.

**What they are watching** is the finding. 37 are `~/.local/share/nvim/lazy/*`, 14 are
`~/.vim/plugged/*`, 5 are `~/.config/tmux/plugins/*` (including two `lib/tmux-test`
submodules), 3 are `~/.config/zsh/plugins/*`. **That is 59 of 61 watching plugin clones
nobody edits.** The remaining two are `~/dotfiles` and its `nvim` submodule.

Three mechanisms confirmed in a scratch repo, so the behaviour is understood rather than
inferred:

- **Reuse works.** The first git command in an `fsmonitor=true` repo spawns exactly one
  daemon; two further commands in the same repo spawn none.
- **Nothing reaps them.** `git-fsmonitor--daemon(1)` documents only an explicit `stop` and
  the worktree going away. There is no idle timeout, so one sweep across a plugin tree
  leaves one daemon per plugin for the rest of the uptime.
- **`core.fsmonitor` decides it**, and it is global (`git/config:7`). A repo covered by an
  `includeIf` block setting it false spawns no daemon and reports `not watching`.

**Where the storm comes from**, by start time: two at boot +0 s and +2 s — the niri prewarm
at `niri/config.kdl:81-83`, which names "fsmonitor daemon spawn" as its purpose — then 57
inside one 14-second window when plugin trees were walked. Twenty-two of those are exactly
the tmux/zsh/vim set that `bash/config-drift`'s plugin-staleness loop visits, and it ran
twice that afternoon; the other ~36 are the nvim lazy set.

**The cost is real but small**: 5.2 MB per daemon, 318 MB, 0.5% of 60 GB. inotify is
nowhere near its limits — 74 instances of 1024, and `max_user_watches` is 524288, not the
8192 the man page warns about.

**The benefit is not measurable on this machine.** `git status`, 20-run averages, warm cache:

| repo | tracked files | with fsmonitor | without |
|---|---|---|---|
| `dotfiles` | 235 | 5 ms | 5 ms |
| `projects/omarchy` | 1770 | 5 ms | 5 ms |
| `projects/paper-refinery` | 46 | 2 ms | 1 ms |
| `projects/cpp-study` | 132 (+958 untracked) | 5 ms | 5 ms |

`cpp-study` first measured 57 ms/run **with** fsmonitor, which looked like an 11× penalty;
it was the daemon's one-off cold start amortised into that first batch of 20, and warm it is
5 ms either way. Recorded because the wrong reading was one re-run away from being written
down as fact. fsmonitor pays on worktrees far larger than anything here.

What this does **not** measure: warm page cache only, `git status` only. The boot-cold case
is precisely what the prewarm exists for and cannot be tested without a reboot.

**Needs a decision — three options:**

- **A. Drop `core.fsmonitor = true` from `git/config`.** No daemons anywhere, 318 MB back,
  and by the table above nothing measurable is lost. It also makes half of the niri
  prewarm's stated purpose moot, so re-check the starship boot warning before trimming that.
- **B. Keep it, exclude the plugin trees** with four `includeIf "gitdir:…"` blocks for the
  nvim, vim, tmux and zsh plugin roots. Keeps the two daemons that watch repos I actually
  edit, drops the other 59. Mechanism verified; the conservative choice.
- **C. Reap periodically from `sysclean`.** Rejected: `stop` works, but the next
  `config-drift` run walks the plugin trees and spawns them all again.

**A is the recommendation** — on this evidence the feature is paying for nothing — with B if
keeping fsmonitor for `dotfiles` is worth four config blocks.

Benchmarking spawned three daemons of its own (`cpp-study`, `omarchy`, `paper-refinery`);
all three were stopped again.

## 12. Two stale claims in the nvim submodule's database docs (found 2026-09-06)

Found while writing the `local-postgres` skill. **Both are in the `nvim/` submodule, which is on
its own branch and is a separate workstream — recorded here rather than fixed.**

- **`dev_db` does not exist.** `nvim/docs/architecture.md:359` gives
  `postgresql://%s:%s@localhost:5432/dev_db` as the dadbod connection template. The live server
  has only the `postgres` database:
  ```bash
  PGPASSWORD=... psql -h 127.0.0.1 -U postgres -d postgres -tAc \
    "select datname from pg_database where not datistemplate"
  ```
- **`DB_USER` and `DB_PASSWORD` are unset**, so the `.nvim.lua` pattern in that same section —
  `os.getenv("DB_USER")`, `os.getenv("DB_PASSWORD")` — resolves to nils and the connection
  cannot be built. The working credential path is the podman secret, which that section does
  not mention. Substitute it directly -- never print it, and never assign it to a bare shell
  variable that a later `set -x` or error dump would echo:
  ```bash
  PGPASSWORD="$(podman secret inspect --showsecret --format '{{.SecretData}}' pg_password)" \
    psql -h 127.0.0.1 -U postgres -d postgres
  ```
  `skills/local-postgres/SKILL.md` is the authoritative form and carries the same rule.

Neither is dangerous; both mean the documented example cannot work as written. The advice in
that section that *is* right and should stay is "never hardcode credentials".

## 13. Three open Firefox items, moved out of `firefox/firefox-notes.md` (2026-09-09)

They had been sitting under a `## Pending To-Do` heading in an app reference, where the audit
workflow never looks — `TODO.md` is where open items are supposed to live. Each was checked
against the live config on the way across, and all three are genuinely still open:

- **Tridactyl blacklist for sensitive sites.** The mechanism is already in use —
  `tridactyl/tridactylrc:45-46` blacklists `drive.google.com` and `docs.google.com` — so this
  is adding entries, not wiring anything up. Banking and password-manager domains were the
  intent. Needs the actual domains from me.
- **Tridactyl deep-config session** — bindings, search-engine review, quality-of-life tweaks.
- **Firefox Multi-Account Containers** — consider it for site isolation (banking, email,
  social). Not currently installed: the default-release profile carries uBlock Origin and
  Proton VPN plus two extensions identified only by GUID, and none is Multi-Account Containers.

## 14. The `runc` decision is enforced only by `crun` being absent (found 2026-09-09)

`containers/README.md` argues the choice properly — `crun` hard-depends on `criu` on Arch, ~27
MiB whose only purpose is checkpoint/restore, which podman documents as non-functional
rootless. The documentation is not wrong. What is missing is anything that *holds* the
decision.

`containers/containers.conf` is 15 lines and sets only `default_host_ips`. It pins no runtime.
Measured 2026-09-09: `podman info` reports `runc`, `crun` is not installed, and podman's own
shipped config documents `#runtime = "crun"` as the default. So the decision holds today purely
because `crun` is absent from the system — not because anything chose it.

If `crun` ever arrives as some other package's dependency, podman switches to it silently.
Nothing errors, nothing warns, and `config-drift` has no check for it: the same
does-less-quietly shape that motivated that tool in the first place.

**The fix is one line** — `runtime = "runc"` in `containers/containers.conf`, with the
reasoning inline so a future audit does not read it as an arbitrary deviation from podman's
default. It is left here rather than done because it is a config change, and it was found
during a documentation audit that deliberately did not make any.
