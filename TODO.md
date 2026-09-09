# TODO — actions that need me, not the config

Only open items live here. Closed ones are removed rather than struck through: the
reasoning worth keeping is in `revisit.md` (investigated and deliberately accepted) and
`docs/architecture.md` + `docs/system-notes.md` (how the system works now). Everything else is in git — the July–August audit
is `git show c940d78:AUDIT-2026-08.md` (deleted 2026-09-08), and the last version of this
file carrying items 1–16 is `git show 92bcf79:TODO.md`.

**Renumbered 2026-09-09, and the old rule is reversed.** Numbers used to be frozen with gaps
where items closed, so that other files could cite them. After nine closures the list read
2, 5, 6, 10 C/D/F, 12, 13 — the gaps and the lettered subsections cost more than the stability
bought. Items are now numbered **sequentially with no letters, and renumbered whenever one
closes**, which works only because nothing outside this file cites a number any more: the four
files that did (`docs/omarchy-comparison.md`, `docs/architecture.md`, `agent-skills.md`,
`firefox/firefox-notes.md`) now cite items by title. For git history and older audits:

| was | now |
|---|---|
| §2 | closed 2026-09-09 — see below |
| §5 | closed 2026-09-09 — see below |
| §6 | **1** — tmux identity segment |
| §10 C | **2** — a test runner |
| §10 D | **3** — off-machine backup |
| §10 F | **4** — editor + agent tmux layout |
| §12 | closed 2026-09-09 — see below |
| §13 | **5** — the three Firefox items |

Items 2–4 all come from `docs/omarchy-comparison.md` and were parked for the same reason: each
is a design job rather than a config edit, and would be poorly served by being squeezed into the
end of another session. Of that file's five proposals A, B and E are done — `config-drift` gained
the pacman-log and symlink checks, and `sysup` gained a lock.

Closed and removed, listed under **the old numbering** they carried at the time. 2026-09-08:
§4 (the Omarchy first pass — the `-Qii` vs `-Qkk` measurement it held now lives in
`etc/README.md`), §7 (the doc-duplication sweep) and §8 (the `duckdb/.duckdbrc` rewrite, whose
every removal is explained inline in that file). 2026-09-09: §9 (`jupytext` not
installed — the finding compared against a superseded uv-tool plan; per-venv is the accepted
setup and the absence is expected, see `revisit.md`), §11 (the fsmonitor daemons — its
premise was measured wrong, and `core.fsmonitor` is now off everywhere rather than global;
evidence in `git show 14cc481`, outcome in `docs/architecture.md`), §1 (the NVMe health
check — now step 10 of `sysclean`, which is where a sudo credential already exists; the
`smartd` rejection and the reason `-H` alone is not enough moved to `docs/architecture.md`),
§3 (the mirrorlist — `sysup` now checks age *and* validity before `paru` and offers to re-rank,
`bash/mirrorlist-rank` does it safely, and the list was re-ranked 20-deep on 2026-09-09, so
nothing is waiting on me), §14 (the `runc` pin — `containers/containers.conf` now names the
runtime under `[engine]`; deliberately with no `config-drift` check, since the pin converts a
silent substitution into a loud failure. Reasoning in `containers/README.md`) and §12 (the two
stale claims in the nvim submodule's database docs — fixed in the submodule rather than left
recorded, since both were documentation. `dev_db` never existed and neither did the `dev` the
same comment block also invented; the live server holds one database, `postgres`, with
`postgres` as its only login role, and `DB_USER`/`DB_PASSWORD` are set by nothing on this
machine. `nvim/docs/architecture.md` now documents the `$DATABASE_URL`-from-podman-secret path
that actually works) and §2 (the missing fallback initramfs — closed by installing a second
kernel instead of enabling the fallback. The item asked "is there a plan B if the boot image
breaks"; a fallback image and a second kernel answer different halves of it. A fallback carries
every driver and covers one that `autodetect` trimmed out — a hardware change. A second kernel
covers a bad kernel or module version. On a laptop that never changes disks the second failure
is the likelier one, so `linux-lts 6.18.50` is installed, `PRESETS=('default')` stays at
upstream's default, and `/boot` went 81 MB → 144 MB of 1.1 GB. The trap is in `etc/README.md`:
`10_linux` reverse-sorts *filenames*, so LTS silently took the `GRUB_DEFAULT=0` slot until
`GRUB_TOP_LEVEL` pinned it back. **Still to verify: LTS has never actually been booted** — every
boot since the install is `7.2.4-arch1-2`, and an untested recovery kernel is not yet a recovery
kernel). The state of the last tidy was verified
rather than assumed: the three stray `.bak` files are gone, `~/.local/bin/check-skills` is now linked,
and the udev and TLP changes have reached `/etc`.

---

## 1. Verify the tmux identity segment in the two cases that cannot be tested from here

`bash/tmux-identity` hides `user@host` when local as the usual user, which is confirmed live.
The other two branches were only tested by faking the environment on throwaway sockets: over
**ssh** it should show the bare hostname, and as **another user** the bare username.

Worth a look the next time either happens for real. Note `SSH_CONNECTION` is read from the
environment that started the *server*, so attaching over ssh to a locally-started tmux will
correctly show nothing — that is not a failure.

## 2. A test runner

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

## 3. Off-machine backup

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

Interacts with the NVMe health check now in `sysclean` (`docs/architecture.md`) — a
disk-health warning is only actionable if there is somewhere to restore from, which is why its
warning path points here.

## 4. An editor + agent tmux layout — **wanted; own session** (added 2026-09-08)

From `docs/omarchy-comparison.md` §27, not from its A–E proposals. **The user rates this
important.** We have exactly one layout, `tmux/layouts/cpp_layout.sh` on `Prefix W`; an
editor+agent layout is the obvious second, and it is a design job rather than a config edit —
which panes, what starts in them, and how it is invoked all need deciding before anything is
written.

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

## 5. Three open Firefox items, moved out of `firefox/firefox-notes.md` (2026-09-09)

They had been sitting under a `## Pending To-Do` heading in an app reference, where the audit
workflow never looks — `TODO.md` is where open items are supposed to live. Each was checked
against the live config on the way across, and all three are genuinely still open:

- **Tridactyl blacklist for sensitive sites.** The mechanism is already in use —
  `tridactyl/tridactylrc:45-46` blacklists `drive.google.com` and `docs.google.com` — so this
  is adding entries, not wiring anything up. Banking and password-manager domains were the
  intent. Needs the actual domains from me. Note `blacklistadd` is weaker than it sounds:
  Tridactyl 1.25.0's own help says it "simply creates a DocStart autocmd that runs `mode
  ignore`", the content script still runs, and ignore mode keeps `<C-o>`, `<S-Insert>`,
  `<S-Escape>`, `<AC-Escape>` and ``<AC-`>`` bound. For a thorough disable Tridactyl points at
  `seturl <url> superignore true` instead, so which of the two these domains want is part of
  the decision.
- **Tridactyl deep-config session** — bindings, search-engine review, quality-of-life tweaks.
- **Firefox Multi-Account Containers** — consider it for site isolation (banking, email,
  social). Not installed, confirmed 2026-09-09. The profile's add-ons are uBlock Origin 1.74.0,
  Proton VPN 1.3.6 and DownThemAll! 4.15.1, plus a **theme** rather than an extension
  (Catppuccin Latte · Mauve) — that is the second of the "two GUIDs" this item used to be unable
  to name, and Tridactyl is absent from the profile only because it is installed globally by the
  `firefox-tridactyl` package. Two things bear on the decision: `containers.json` already holds
  the four default identities (Personal / Work / Banking / Shopping) and `privacy.userContext.enabled`
  is simply not set, so native containers cost one pref and the extension's real addition is
  per-site assignment; and `prefs.js:278` has
  `privacy.userContext.extension = "tridactyl.vim@cmcaine.co.uk"`, so Tridactyl already claims
  that API — whether the two contend for it is unverified.
