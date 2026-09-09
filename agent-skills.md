# Agent skills — assessment against Omarchy's, 2026-09-05

Read against `~/projects/omarchy` at `49306774`. Separate from `docs/omarchy-comparison.md` on
purpose: that document is about *configuration*, this one is about how agent-facing
documentation is organised, which is a different question with a different answer.

Short version: **none of Omarchy's seven skills transfers as content.** What does transfer is
the *shape* of their documentation, and that turns out to matter here more than any individual
file, because `CLAUDE.md` was 969 lines and every one of them is loaded into every session.
**The split argued for below has since been done** — `CLAUDE.md` is now 849 lines and the
container reasoning lives in `containers/README.md`.

---

## Two different mechanisms, easily confused

Omarchy has both, and only the second is a Claude Code skill:

| | `agents/skills/*.md` | `default/agents/skills/*/SKILL.md` |
|---|---|---|
| Format | Plain markdown, **no frontmatter** | YAML frontmatter (`name`, `description`) |
| Mechanism | Linked from `AGENTS.md`: *"Read the matching guide before starting"* | The Skill tool — loaded on demand by description match |
| Audience | Anyone working **on** Omarchy | End users configuring **their own** desktop |
| Count | 7 files, 438 lines | 2 skills (`omarchy`, `diagnose-crash`), 9 files |

The seven the question was about are the first kind — a convention, not a feature. They work
because `AGENTS.md` names each one and says when to read it.

The second kind is the one Omarchy ships *to users*, so that a user's own Claude Code knows
how to edit `~/.config/hypr/` safely. Its `description` is written as a trigger list — "Use
when editing ~/.config/hypr/, ~/.config/omarchy/… Triggers: Hyprland, window rules,
animations, keybindings…" — because that string is all the model sees when deciding whether to
load it.

This repo currently has **neither**: no `~/.claude/skills/`, no `SKILL.md` anywhere, and
`.claude/` holds only `settings.local.json`, which is globally gitignored.

---

## The seven, one by one

| Skill | Lines | Verdict |
|---|---|---|
| `command-metadata.md` | 31 | **No.** `# omarchy:summary=` headers for a 440-command router. `bash/` has 35 scripts, all invoked by keybinding, unit or name, and no router — already declined in `docs/omarchy-comparison.md` as ceremony |
| `install-scripts.md` | 19 | **No.** Describes their `install/` tree: `$OMARCHY_INSTALL`, sourced leaves with no shebangs, `install/hardware/` vs `install/user/`. Here `install.sh` is one 467-line file |
| `shell-dev.md` | 49 | **No.** Quickshell/QML desktop |
| `icon-font.md` | 79 | **No.** Adding glyphs to their branded TTF |
| `acceptance-tests.md` | 46 | **No.** A graphical suite run in a disposable VM through a sibling `omarchy-iso` repo, with QMP virtual-keyboard input. Enormous infrastructure; there are no tests here at all |
| `migrations.md` | 170 | **No.** Versioned one-shot repairs with per-user markers — already declined; one machine, one user, and `install.sh` is idempotent |
| `visual-verification.md` | 44 | **Principle yes, content no.** See below |

`visual-verification.md` is the only near-miss, so it is worth being precise about why it still
does not transfer. Its principle — *a change with a visual effect must be checked in the
running UI, because an artifact that looks right in source can clip, overlap, or show stale
state* — is sound and matches the `verify-empirically` habit already recorded in memory. But
every mechanic in it is an Omarchy command (`omarchy capture screenshot fullscreen save`,
`omarchy screenrecord --fullscreen`), and the one portable tool it names, `wtype`, is **not
installed here**. The equivalents would be `grim`, `niri msg action screenshot`, and
`grim -g "$(slurp)"` — a different file with the same first paragraph. Not worth writing until
there is a visual change to verify.

So: nothing to copy. The rest of this document is the part that is actually useful.

---

## What does transfer: they split docs by *when you need them*, and this repo does not

Omarchy states the rule in `AGENTS.md` and follows it:

> - `agents/skills/` — task procedure ("do this when doing X"), for anyone working on the
>   codebase
> - `docs/` — reference on how the system is shaped, for anyone working on the codebase
> - `manual/` — end-user documentation; never codebase internals

`AGENTS.md` itself is 133 lines. Everything long sits behind a pointer.

Here, `CLAUDE.md` was **969 lines and always loaded** — in context for every session
regardless of the task. Measured before the split:

```
## Repository Overview        5      ## Modifying configs      15
## Installation              67      ## Environment variables  10
## Architecture             748      ## Package notes         110
                                     ## TODOs                   9
```

And inside `## Architecture`, the distribution is very uneven:

| Subsection | Lines | Share of CLAUDE.md |
|---|---|---|
| `### Containers — rootless podman, and Postgres as a Quadlet unit` | **197** | **20%** |
| `## Package notes` (top level) | 110 | 11% |
| `### rclone — Google Drive uses a personal OAuth client` | 87 | 9% |
| everything else | 575 | 59% |

Those three total **394 lines — 41% of the file** — and all three are task-scoped: the podman
essay is irrelevant to fixing a tmux colour, and the AOCL/BLAS notes are irrelevant to
debugging a sleep hook.

### The counter-argument, which is real

The obvious move — "put Containers in a skill" — is wrong as stated, and the reason is worth
writing down so it is not tried later.

That section is not homogeneous. It contains **guardrails** whose whole value is being seen
without being asked for:

- *"Never `sudo podman`"* — a separate root-owned store; the symptom is `sudo podman ps` empty
  while `podman ps` shows `pg`.
- *"Never enable the **system** `podman.socket`"* — recreates exactly the escalation path the
  Docker migration removed.
- *"Lifecycle is `systemctl --user`, not `podman`"* — `podman stop pg` gets it restarted.
- *"Do not flip `rootless_port_forwarder` before fixing `pg_hba.conf`"* — silently turns off
  password authentication.

A skill that fails to load is a guardrail that was not there. For rules whose cost of being
missed is a security regression, always-loaded is the correct trade, and 20 lines is a cheap
price.

The other ~175 lines are **evidence and reasoning**: why `runc` over `crun` with the package
sizes, the pasta/rootlessport networking essay, the storage-migration post-mortem, the
`keep-id` mapping rationale, the `StopTimeout`/`Notify`/`HealthOnFailure` derivations. That
material is why the decisions are trustworthy, and it is needed roughly never — only when
someone reopens one of those decisions.

**So the split is not by topic but by kind:** invariants stay in `CLAUDE.md`, reasoning moves
behind a pointer. That is precisely the `AGENTS.md` / `docs/` division, and this repo already
had the pattern in `etc/README.md` — a reference doc that `CLAUDE.md` links to rather than
inlines.

**Done 2026-09-05.** `containers/README.md` now holds the reasoning and `CLAUDE.md` keeps the
guardrails plus a pointer: 969 → 849 lines, no new mechanism. Verified nothing was lost by a
41-point fact check and a 161-token check. The remaining candidates were then measured and
**declined** — `Package notes` has the highest guardrail density in the file (15.5 per 100
lines; it is a do-not-touch list, and moving it behind a pointer is how `aocl-gcc` gets removed
as unused), and `rclone` has no directory to live in. The rule that fell out: split only when
the section is >150 lines, below ~8 guardrails per 100 lines, and a tracked directory already
exists. Containers hit all three; nothing left does.

---

## Would any actual skill earn its place here?

A skill is worth it when the content is **procedural**, **occasional**, and **too long to keep
in an always-loaded file**. Against that test, most of what this repo knows is either an
invariant (belongs in `CLAUDE.md`) or reference (belongs in a linked doc). One candidate meets
all three:

**`config-audit`** — the sweep this repo runs every few months, currently scattered across
three files and one memory entry, with no single place that says "run these, in this order":

- the unowned-`/etc` sweep (`find /etc -type f` diffed against `pacman -Ql`) — `etc/README.md`
- the modified-package-config sweep (`pacman -Qkk`, or the faster
  `pacman -Qii | grep -oE '/[^ ]+ \[modified\]'`) — `etc/README.md`, which also records the
  timings (40 ms against 19 s) and that `-Qkk` had only ever been run against a single package
- the `~/.config` symlink sweep — `CLAUDE.md`
- the workflow itself: branch, one commit per finding, verify empirically, `--no-ff` merge —
  currently only in memory, not in the repo
- and now the symlink-integrity and `pacman.log` checks proposed in `docs/omarchy-comparison.md`

That is genuinely multi-step, genuinely occasional, and genuinely not written down in one
place. It is the one thing here that a skill would improve rather than merely relocate.

Everything else fails the test: *"add a new config to dotfiles"* is 15 lines and already in
`CLAUDE.md`; *"verify empirically"* is a habit, not a procedure; *"visual verification"* has no
content until there is a UI change to check.

**Recommendation: at most one skill, and the `CLAUDE.md` split first.** The split is the change
that pays every session; the skill only pays on audit days. Doing the skill without the split
would leave the 969 lines in place and add a file.

---

## Mechanics, if it is done

A project skill lives at `.claude/skills/<name>/SKILL.md` with frontmatter:

```markdown
---
name: config-audit
description: >
  Run the periodic dotfiles/system audit. Use when asked to audit, sweep, or check for
  config drift, untracked /etc files, modified package configs, or broken symlinks.
  Triggers: audit, drift, pacnew, pacman -Qkk, unowned files, symlink check, sweep.
---
```

Two things to get right:

- **The `description` is the whole trigger.** It is all the model sees when deciding whether to
  load the skill, so it needs the words that will actually be typed — which is why Omarchy's
  reads as a keyword list rather than a summary.
- **Track it.** `.claude/` is not in this repo today, and the only `.claude` entry in the
  global gitignore is `**/.claude/settings.local.json`, so `.claude/skills/**` is trackable —
  but `install.sh` would need to symlink it like every other config, or it exists only in the
  repo and not where Claude Code looks.

Nothing here has been implemented.

---

# Omarchy's agent *tooling* — a different thing from its skills

Added 2026-09-05. The seven files assessed above are contributor task guides. Omarchy also
ships actual **AI-agent integration in the desktop**, which is a separate question and a more
interesting one, because this machine runs Claude Code every day and has none of it.

Four categories, `bin/omarchy-agent-*` plus a Quickshell panel:

| Surface | Size | What it is |
|---|---|---|
| `omarchy-agent` | 132 lines | Launch whichever coding agent is set as default |
| `omarchy-agent-prompt` | 23 | Same, seeded with a prompt |
| `omarchy-agent-crash` | 52 | Diagnose a crashed PID with the agent |
| `omarchy-agent-usage-{claude,codex,fireworks}` | 905 / 603 / 511 | Quota + token accounting per provider |
| `omarchy-agent-usage-update` | 68 | Writes each collector's JSON to a state dir |
| `shell/plugins/agents/` | QML | A bar widget that watches those JSON records |
| `default/agents/skills/{omarchy,diagnose-crash}/` | 9 files | Real Claude-Code-format skills, shipped to end users |

## 1. The launcher — not needed here, but its table is worth keeping

`omarchy-agent` exists because Omarchy supports twelve agents and each spells "don't stop to
ask" differently. That normalisation table is the useful residue:

| Agent | Unattended flag |
|---|---|
| `claude` | `--permission-mode auto` |
| `codex` | `--approve-for-me` |
| `copilot` | `--allow-all` |
| `opencode` | `--auto` |
| `crush` | `--yolo` (interactive only — `crush run` never prompts) |
| `grok` | `--permission-mode bypassPermissions` |
| `hermes`, `omp`, `agy` | `--yolo` / `--auto-approve` / `--dangerously-skip-permissions` |

One machine, one agent here, so the abstraction earns nothing. Two incidental findings do
transfer:

- **Agents refuse to remember trust for `$HOME`**, so their launcher `cd`s to a work directory
  first rather than re-answering the trust prompt every session.
- A **fixed `app-id`** (`org.omarchy.agent`) rather than one per binary, so a single window rule
  can target "the agent window" whatever is running in it. Directly applicable to a niri window
  rule if a dedicated agent window is ever wanted.

## 2. The usage panel — the right idea, the wrong size

`omarchy-agent-usage-claude` is **905 lines of Python** that reads `~/.claude/projects`
transcripts, falls back to a stats cache and history, and queries Anthropic's OAuth usage
endpoint for authoritative rate limits — all to emit one JSON record a QML panel watches.

The question it answers ("how much of my quota is left, and when does the window reset") is a
real one. The answer here is that Claude Code answers it in-session already, so 905 lines of
Python plus a bar widget buys a second, staler copy. **Declined.**

What survives is the plumbing shape, which is the same one already used twice in this repo: a
collector writes JSON to a state dir, and the display only ever reads that file — it never
talks to disk formats or endpoints itself. That is exactly how `sysup`'s nvim health check and
`config-drift`'s lockfile-age check are built.

## 3. `omarchy-agent-crash` — the pattern worth copying

The most transferable thing in the whole tree, and it is 52 lines. A desktop event (a
"Process crashed" notification) launches the agent with a **structured prompt of gathered
facts** that points at a **skill holding the method**. Its own comment is the design:

> The method lives in the diagnose-crash skill so it is edited in one place and works with
> whichever agent is default; this only gathers the facts and points at it.

So: **the script knows the machine, the skill knows the procedure.** The script interpolates
PID, binary, signal and timestamp; the skill says how to investigate. It even carries a
fallback for harnesses without a skill mechanism — "read the skill files directly and follow
them instead."

That split is what this repo would want. A script that captures state cheaply, and a skill that
says what to do with it, rather than one long prompt that has to be edited in two places.

## 4. `diagnose-crash/SKILL.md` — the template

128 lines, and the best model available for what a skill here should look like. Six qualities
worth stealing outright:

- **The `description` is a trigger list, not a summary.** It is all the model sees when
  deciding whether to load the skill: *"Triggers: crash, segfault, SIGSEGV, SIGABRT, core dump,
  coredumpctl, 'why did X crash', 'X keeps crashing', backtrace symbolization."*
- **Method, not facts.** Nothing in it describes Omarchy's machine. It says how to investigate,
  which is why it stays true.
- **Epistemic discipline, stated.** *"Work from evidence… an honest account, not a
  plausible-sounding story."* *"separating clearly what the evidence proves from what you are
  inferring."* *"never invent function names to fill the gap."*
- **Rule out the boring causes first** — check OOM before blaming the program.
- **Safety in line with the work.** A core dump is a verbatim copy of process memory and can
  hold passwords and tokens: write it to `mktemp`, delete it after.
- **"Leave the system as you found it."** Diagnosis reads; it does not fix, tidy, or
  reconfigure.

The other shipped skill, `omarchy/SKILL.md`, uses progressive disclosure — one `SKILL.md` plus
six topic files (`capture.md`, `hooks.md`, `theming.md`, …) loaded only when the topic comes up.
That is the right shape for anything larger than a page.

## What this repo would actually want

Not a port. The honest list, given one machine, one user, one agent:

**Worth having**

1. **`config-audit`** — already argued in the section above, and unchanged by any of this: the
   periodic sweep is multi-step, occasional, and currently scattered across `CLAUDE.md`,
   `etc/README.md` and one memory entry with nowhere saying "run these, in this order".
2. **`diagnose-boot-or-suspend`** — the local analogue of `diagnose-crash`, and the one area
   where this machine has a documented, repeatable, expensive failure: the FUSE-wedged suspend
   that cost 916 suspend attempts and 456 aborts in a night. The method is already written down
   across `CLAUDE.md`'s sleep-hook section and `system-sleep/unblock-fuse`; a skill would say
   how to read `journalctl -b -1`, PSI, `coredumpctl`, and the freezer state, with the same
   "rule out the boring causes first" discipline.
3. **A fact-gathering script per skill, in `bash/`**, following the `omarchy-agent-crash` split
   — cheap to run, no method inside it, points at the skill.

**Declined, with the reason**

- **Usage/quota panel** — answered in-session; a second copy would be staler.
- **Multi-agent launcher** — one agent.
- **A skill wrapping `sysup` or `config-drift`** — those are already single commands that print
  their own findings. A skill that says "run `config-drift`" is a worse `config-drift`.
- **Anything that duplicates `CLAUDE.md`.** The rule from the first half of this document still
  holds: guardrails belong in the always-loaded file, and a skill that repeats them is a
  guardrail that might not load.

**The test to apply to any candidate:** procedural, occasional, and too long for `CLAUDE.md`.
`config-audit` and `diagnose-boot-or-suspend` pass. Almost nothing else here does.

---

# Design brief — start here after a clear

## The prompt to open that session with

```text
I want to DESIGN two skills for this dotfiles repo, before any of them is written:

  1. config-audit
  2. diagnose-boot-or-suspend

These are NOT ports of Omarchy's. They have to be built around how this machine
actually works and what is already in this repo.

READ FIRST
  agent-skills.md   -- section "Design brief - start here after a clear" (line 332)
                       is written to be self-contained. Also read the final section,
                       "Late addition (2026-09-05): how they structure a large skill"
                       (line 492) -- it bears directly on question 1 below.
                       The three sections above the brief are background on Omarchy;
                       read them only if a design question turns on what they did.
  bash/config-drift -- 319 lines, the tool that already does the mechanical checks.
                       Read it before deciding what config-audit is for.
  CLAUDE.md         -- the always-loaded guardrails. Anything a skill would restate
                       is already here, and that is the point of the test below.
  TODO.md           -- section 10 (C) parks an invariant test suite; section 11 and
                       sections 4-7 are open items, useful as realistic input.

THIS SESSION IS FOR THINKING, NOT IMPLEMENTING.
Do not create .claude/skills/ or write any SKILL.md until we have agreed the shape.
What I want is decisions with reasons, and a recommendation rather than a menu of
options. Push back if you think a candidate fails the test rather than designing it
anyway -- "neither of these should be a skill" is an acceptable outcome.

THE TEST any candidate must pass -- procedural, occasional, AND too long for
CLAUDE.md. All three:
  - not procedural  -> it is an invariant, and belongs in CLAUDE.md where it is
                       always loaded. A skill that fails to load is a guardrail
                       that was not there.
  - not occasional  -> it is a command. sysup and config-drift already print their
                       own findings; a skill that says "run config-drift" is a
                       worse config-drift.
  - short enough    -> put it in CLAUDE.md. "Add a new config to dotfiles" is 15
                       lines and already lives there correctly.

WORK THROUGH THE FIVE OPEN QUESTIONS IN THIS ORDER -- the first changes the size of
everything after it:

  1. Does config-audit run the sweeps or describe them? config-drift already does
     the mechanical checks -- so is the skill only the judgement half? Note the
     "Late addition" section: Omarchy's answer is a short SKILL.md that mostly
     routes, plus gated sibling topic guides. That is the same layering this repo
     already uses twice (CLAUDE.md vs reference docs; sysup vs ~/.local/state/sysup).
  2. Does diagnose-boot-or-suspend split into two skills, or one with branches?
  3. Is a per-skill fact-gathering script in bash/ worth it here, given there is no
     notification to click from the way Omarchy has?
  4. .claude/skills/ tracked in-repo, or ~/.claude/skills/ symlinked by install.sh?
  5. How does a skill get kept honest? Its instructions can rot the same way
     bash/tmux-theme's header did -- it stated the opposite of its own code. Decide
     whether these two want designing together with the TODO.md 10(C) test suite.

BEFORE PROPOSING ANYTHING, look at what is actually there: bash/config-drift, the
procedures table in the brief, ~/.local/state/sysup/ and
~/.local/state/service-failures/. Verify rather than assume. Several findings this
month were things the repo already knew and a check had silently missed, and at
least three were my own wrong diagnoses from trusting the wrong probe -- the
fc-match emoji case in docs/omarchy-comparison.md finding 25 is the cautionary one.

WHEN THE SHAPE IS AGREED, write the design into agent-skills.md as a new section.
Implementation is a separate session after that.

Context: branch omarchy-comparison, 21 commits ahead of master, not merged yet.
The nvim submodule is on branch audit-2026-09 and is a separate workstream -- leave
it alone.
```


Everything above is **analysis of Omarchy**. This section is the part that is about *this*
machine, written so a session starting cold can design the skills without re-reading any of it.
Nothing has been implemented; no `.claude/skills/` exists yet.

## The one-line brief

Design two skills for this repo — `config-audit` and `diagnose-boot-or-suspend` — in Claude
Code's native `SKILL.md` format, adapted to this system rather than ported from Omarchy.

## The test any candidate must pass

**Procedural, occasional, and too long for `CLAUDE.md`.** All three, or it does not become a
skill:

- **Not procedural** → it is an invariant, and belongs in `CLAUDE.md` where it is always loaded.
  A skill that fails to load is a guardrail that was not there.
- **Not occasional** → it is a command. `sysup` and `config-drift` already print their own
  findings; a skill that says "run `config-drift`" is a worse `config-drift`.
- **Short enough for `CLAUDE.md`** → put it there. "Add a new config to dotfiles" is 15 lines
  and already lives there correctly.

## Raw material already on this machine

A skill here should carry **method** and reference these, not restate them.

**Documented procedures, currently scattered:**

| Procedure | Where it lives now |
|---|---|
| Unowned-`/etc` sweep (`find /etc -type f` vs `pacman -Ql`) | `etc/README.md` prose |
| Modified package configs (`pacman -Qkk`, or `-Qii \| grep '\[modified\]'`) | `etc/README.md`, one line |
| `~/.config` symlink sweep | `CLAUDE.md:121`, a fenced block |
| Branch → commit-per-finding → verify → `--no-ff` merge | memory only, not in the repo |
| SSH key encryption test (`ssh-keygen -y -P ''`) | `CLAUDE.md:342` |
| rclone remote inspection without leaking tokens | `CLAUDE.md:605` |

**Tools that already gather facts** — a skill should call these rather than re-implement:

- `bash/config-drift` (319 lines) — `.pacnew`, root-config drift, **last pacman transaction**,
  **symlink integrity**, plugin staleness, tmux rendered behaviour, unit verification
- `sysup`'s nvim health step, and its state at `~/.local/state/sysup/`
- `~/.local/state/service-failures/failures.log` — the persistent record behind
  `notify-failure@`
- `bash/status-menu`, `net-notify`, `power-notify` — existing machine-state readers

**The documented expensive failure**, and the reason `diagnose-boot-or-suspend` is the second
candidate rather than an invented one:

> 916 suspend attempts, 456 hard aborts and 1831 wifi disconnects between 22:12 and 11:06
> (`CLAUDE.md`, sleep-hook section) — one stray `du` on an rclone mount wedged a task in an
> unanswered FUSE request, the freezer could not freeze it, and logind retried every ~100 s all
> night with the lid shut.

The mechanism is understood and `system-sleep/unblock-fuse` now handles that specific cause.
What does not exist is the **method for the next one**: how to read `journalctl -b -1`, PSI,
`coredumpctl`, freezer state, and the `systemd-suspend.service` cgroup after a suspend that
misbehaved. That is method, it is occasional, and it is far too long for `CLAUDE.md`.

## Open questions to brainstorm

1. **Scope of `config-audit`.** Does it *run* the sweeps, or *describe* them? Running them
   makes it a script — and `config-drift` already is one. The likely answer is that the skill
   owns the parts that need judgement (what to do with an unowned file, whether a modified
   package config should be tracked, how to decide) and defers the mechanical checks to
   `config-drift`. Worth settling first, because it decides whether the skill is 40 lines or
   150.
2. **Does `diagnose-boot-or-suspend` split?** Boot problems and suspend problems share
   `journalctl -b`, and little else. One skill with two branches, or two skills?
3. **The fact-gatherer question.** Omarchy pairs each skill with a small script that captures
   state and points at the skill (`omarchy-agent-crash`, 52 lines). Does that split earn its
   place here with no notification to click from, or is "run this, paste the output" enough?
4. **Where do they live, and how are they installed?** `.claude/skills/<name>/SKILL.md` is
   project-scoped and would be tracked; `~/.claude/skills/` is user-scoped and would need an
   `install.sh` symlink like everything else. The repo has no `.claude/` content today and the
   global gitignore only excludes `settings.local.json`, so `.claude/skills/**` is trackable.
5. **How is a skill kept honest?** Every other claim in this repo is verified empirically. A
   skill's instructions can rot exactly like `bash/tmux-theme`'s header did. The invariant-lint
   idea parked in `TODO.md` §10 (C) is the obvious answer, and the two may want designing
   together.

## Constraints a design has to satisfy

- **Minimal and non-duplicating.** No restating what `CLAUDE.md`, `etc/README.md` or
  `containers/README.md` already say — the 2026-09-05 duplication sweep exists because two
  copies of the Firefox pref list had already diverged.
- **The `description` is a trigger list, not a summary.** It is the only thing the model sees
  when deciding whether to load the skill.
- **Method, never machine facts.** Facts go stale; `nvim/CLAUDE.md` asserted "duckdb is not
  installed" until the day it was.
- **State the epistemic rules,** the way `diagnose-crash` does: separate what the evidence
  proves from what is inferred, never invent a detail to fill a gap, leave the system as you
  found it.
- **Verify empirically before asserting** — the standing preference in this repo, and the thing
  that caught the broken `.duckdbrc`, the wrong secret path, and the `pesto` miscitation.
- **Progressive disclosure** for anything over a page: one `SKILL.md` plus topic files, the way
  `omarchy/SKILL.md` carries six.

## Mechanics

```markdown
---
name: config-audit
description: >
  Run the periodic dotfiles/system audit. Use when asked to audit, sweep, or check for
  config drift, untracked /etc files, modified package configs, or broken symlinks.
  Triggers: audit, drift, pacnew, pacman -Qkk, unowned files, symlink check, sweep.
---
```

Project skills live at `.claude/skills/<name>/SKILL.md`. If they go to `~/.claude/skills/`
instead, `install.sh` needs a symlink like every other config, or they exist in the repo and
not where Claude Code looks.

## Late addition (2026-09-05): how they structure a large skill

From the fourth pass over `default/` — `docs/omarchy-comparison.md` finding 30.

`default/agents/skills/omarchy/` is not one file. It is a **294-line `SKILL.md` plus six
sibling topic guides**, 28–79 lines each:

```
omarchy/SKILL.md        294   frontmatter, trigger list, MUST-use rules, routing table
omarchy/hyprland.md      78   keybindings, monitors, window rules
omarchy/theming.md       79   themes, backgrounds, fonts
omarchy/contributing.md  65   reporting bugs upstream
omarchy/capture.md       60   screenshots, recording, OCR
omarchy/plugins.md       52   bar layout, widgets, idle
omarchy/hooks.md         28   automation hooks on system events
```

`SKILL.md` carries the frontmatter, the "you MUST invoke this for X" list, and then mostly
**routes**: *"Deeper instructions for common areas live next to this file. Read the matching
guide before starting."* `diagnose-crash/` does the same at smaller scale — a 128-line
`SKILL.md` and a 104-line `reporting.md` that is explicitly gated: *"Read this only after
concluding that a crash is genuinely Omarchy's to fix."*

**Why it matters for question 1 of the brief.** The worry there was that `config-audit` wants
to be one long file. This is the third instance of the same layering already used twice in this
repo — `CLAUDE.md` versus the reference docs, and `sysup` versus `~/.local/state/sysup/` — so
the answer is likely the same shape: a short SKILL.md that says when to run and what to decide,
with the per-area procedure in siblings loaded only when that area is in play.

It also sharpens question 5. A gated sibling (`reporting.md`, read only under a stated
condition) is easier to keep honest than a paragraph buried mid-file, because the gate states
the precondition the content assumes.

---

# Agreed design (2026-09-06)

**One skill ships: `diagnose-boot-or-suspend`.** `config-audit` was designed in full and then
dropped — everything useful in it has a better home, and the part that looked most valuable
failed the test outright. The reasoning is kept below rather than deleted, so it is not
re-proposed from scratch.

Nothing is implemented yet. This section is the specification for the session that does it.

Three external sources were read alongside the repo: Anthropic's support article on skills, the
Agent Skills authoring conventions (frontmatter rules, `references/`, progressive disclosure),
and a survey of ~100 published skills. Two of their rules changed decisions taken during the
session, and both changes are recorded rather than quietly folded in.

## What measuring changed, before any design

Six probes were run first, because the brief asked for verification rather than assumption.
Five contradicted something the design was about to rest on.

| Assumption | Measured 2026-09-06 |
|---|---|
| The audit sweeps are slow, so `config-drift` needs a gated `--audit` mode | Unowned-`/etc` sweep **1.15 s**; `pacman -Qii \| grep '[modified]'` **40 ms**. Both cheaper than checks `config-drift` already runs every `sysup`. No gate needed. |
| `pacman -Qkk` is the tool for modified package configs | **19 s**, and as a non-root user it emits 110 warning lines, mostly `failed to calculate SHA256 checksum` — unreadable, not altered. Correction now in `etc/README.md`. |
| Suspend evidence is volatile, so a capture script earns its place | The journal retains **41 boots, 178 MB, back past 2026-07-26**. The 2026-09-02 incident is still queryable today. |
| The suspend-abort signature would have to be described from memory | It is `Failed to freeze unit 'user.slice': Connection timed out`, **456** occurrences in the 22:00–11:30 window — matching `CLAUDE.md`'s "456 hard aborts" exactly. |
| The unowned-`/etc` count is stable enough to assert | **172** today against **183** on 2026-09-04. A count is not a finding; only a diff against a tracked baseline is. |
| A failed `journalctl` query is distinguishable from a quiet one | It is **not**. A typo'd unit name and a genuinely quiet unit are byte-identical: both print `-- No entries --`, both exit **0**. |

One discrepancy surfaced and is deliberately **not** resolved: `Starting System Suspend` in that
window is **456**, not the **916** attempts `CLAUDE.md` cites. The same event counted at a
different layer gives a different number. Recorded so the next reader does not assume a typo.

## Why `config-audit` was dropped

It was designed as `SKILL.md` plus `references/probes.md`, the judgement half of an audit with
the mechanical half delegated to `config-drift`. Applying the brief's own test to what actually
remained killed it.

**Its best content — the wrong-probe catalogue — is not procedural. It is an invariant.** Seven
instances (`fc-match`, `grep ENCRYPTED`, `/home/.snapshots`, the zsh dotglob, `pgrep fsmonitor`,
`-Qii` vs `-Qkk`, and `config-drift`'s own two `sudo -n` calls) collapse into **two rules of
three lines each**. By the test, that belongs in `CLAUDE.md` where it is always loaded.

**And its trigger is every session, not just audits.** The `fc-match` error happened during a
config comparison, the `grep ENCRYPTED` false alarm during an SSH review, the `-Qkk` error
during *this design session*. A skill that loads on the word "audit" would not have been loaded
for any of the three. That is precisely the guardrail-that-did-not-load failure the brief warns
about.

Once the catalogue leaves, the rest disperses: the sweeps are `config-drift` features, the
branch/commit-per-finding/`--no-ff` workflow is ~12 lines of `CLAUDE.md`, and the
track/don't-track rules are ~20 lines that `CLAUDE.md` already carries as worked cases with
reasons ("Not tracked (intentionally)", and the three deliberately-left-untracked entries).
Nothing procedural, occasional and long is left over.

**Do not re-propose it as "the judgement half of the audit".** That framing is what made it look
viable for most of a session. The question that settles it is *when does this need to be loaded*
— and the answer is "when about to assert any finding", which is not an occasion.

## Why `diagnose-boot-or-suspend` survives

The objection raised against it during the session was that it is method for a failure class
seen **once**, whose specific cause `unblock-fuse` now handles. That objection was wrong about
the domain. The class is not "FUSE wedge" but "the machine misbehaved across a power-state
transition", and the repo records **four** such investigations, each resolved by measurement:

- the 2026-09-02 FUSE wedge (456 aborts overnight),
- `restart-swayidle` proven never to have run, across 1002 resumes and 31 boots,
- `fix-wifi.sh` removed on the evidence of nine measured resumes,
- `rclone@gdrive` timed against a boot where wifi took 103 s.

It is also the only candidate that is genuinely **not scriptable**: the next query depends on the
last answer, which is why `config-drift` cannot absorb it the way it absorbed the sweeps. It is
procedural, occasional, and roughly 200 lines. It passes all three legs.

**Narrowing that must hold:** this is not a general systemd-debugging skill. That is model
general knowledge and does not belong in a repo skill. The content is what is specific to this
machine — the resume path has moving parts (`unblock-fuse`, `lock-once`, swayidle, the `rclone@`
restart, and `ath11k_pci` explicitly **no longer** reloaded), the lid only suspends on battery so
reproducing anything requires being unplugged, and the counting method that has twice produced
the right answer here.

## The design

### The spine: teach the known-good shape, diagnose by how the real one differs

This came out of measuring rather than from the brief, and it is the skill's organising idea. A
healthy suspend cycle is six lines in fixed order; a failed one is a different six. Both shapes,
and the counts, are in `references/incident-2026-09-02.md`.

**Corrected while building that fixture.** The spine was first written as *"which line is absent
names the stage that failed"*. Reading an actual failed cycle killed that: line 2 is not absent,
it is **replaced** by `Failed to freeze unit 'user.slice': Connection timed out`, and systemd
then *proceeds to attempt the suspend anyway* — the abort lands one line later, in the kernel, as
`Device or resource busy`. A stage fails by **substitution** as often as by absence, and one
cycle can contain two distinct failures of which only the second stops anything.

The corrected spine: **compare the observed cycle against the known-good chain line by line, and
name the first line that differs — whether it is missing or replaced.** The one line whose
*absence* really is the signal is `System returned from sleep operation`, which is the only proof
the machine actually slept; it appears 4 times in a boot with 460 attempts.

This is the right kind of skill content because the reader **verifies it against their own
journal every time they use it**. It cannot rot into stating the opposite of reality the way
`bash/tmux-theme`'s header did — and the correction above is the proof, since writing the skill
from `CLAUDE.md`'s summary rather than from the journal would have shipped the wrong rule.

### Layout

```
skills/diagnose-boot-or-suspend/            <- in the repo, symlinked to ~/.claude/skills/
├── SKILL.md               ~70 lines  epistemic rules, boot selection, counting, routing
└── references/
    ├── suspend.md         ~80 lines  the two shapes, freezer/FUSE, retry loop, resume path
    └── incident-2026-09-02.md         the worked fixture — WRITTEN, see below
```

**User scope, not project scope — this reverses the earlier decision in question 4.** That
decision was carried almost entirely by `config-audit`, which really was about this repo. The
survivor is a *machine* diagnostic: it fires when the laptop misbehaved, from whatever directory
you happened to be in. Project-scoped and invoked from `~/projects/something`, it **silently does
not load** and you get a generic systemd session instead of the machine-specific one, with no
sign that anything was missing — the same guardrail-that-was-not-there failure that killed
`config-audit`.

The branch-switch hazard inverts too, which is what settles it. Under a user-scope symlink, a
branch lacking the skill leaves a **dangling symlink**, which `config-drift` already detects once
`~/.claude/skills` joins its `roots` array — one word. Under project scope the file is simply
absent: nothing dangles, and **nothing detects it**. Project scope is not safer here, only less
observable.

It lives at `skills/` in the repo rather than `.claude/skills/`, matching the repo's convention
of naming directories after the thing they configure (`bash/`, `etc/`, `zsh/`), and leaving the
repo's `.claude/` as just the gitignored `settings.local.json`. `install.sh` uses plain
`ln -sf`, so this is two lines.

One skill and not two, because **the invoker cannot classify the problem yet**. "It was weird
overnight", "wifi didn't come back", "it took ages to start" — the branch is only decided after
picking the boot, and picking the boot is the shared hard step. The `description` is the only
thing the model sees at load time, so it carries both vocabularies.

This is in tension with the authoring rule *"one skill, one job"*, and the tension is
acknowledged rather than dismissed: boot and suspend are one job (diagnose a systemd lifecycle
event on this machine from the journal) with two evidence sets. The failure that rule warns
about is triggering at the wrong moment, and splitting would make it **worse**, because the
user's own words at trigger time do not classify. **Tripwire:** if it loads for one branch when
the other was wanted, split it.

### `SKILL.md` — the four steps, plus the boot section

1. **Epistemic rules, stated before any command.** An empty result is not a negative result —
   and here the proof is concrete: a typo'd unit name and a quiet unit are byte-identical, both
   `-- No entries --`, both exit 0, so the unit name is verified before its silence means
   anything. Reproducing anything requires being **unplugged**
   (`HandleLidSwitchExternalPower=lock`). Leave the system as found; every probe here is
   read-only.
2. **Pick the boot.** `journalctl --list-boots`, then the question that decides everything:
   *was the machine power-cycled?* That separates `-b 0` from `-b -1`. And a trap walked into
   during the design session: **boot indices shift with every reboot.** The storm boot was `-13`
   on 2026-09-06 and will not be `-13` next week. Select by date; never reuse a remembered index.
3. **Count per boot before reading any instance.** The `restart-swayidle` lesson. A 456-attempt
   storm and a single failure produce *identical* excerpts — counting is the only thing that
   separates them, and it is what found the wrong number in `CLAUDE.md`.
4. **Classify:** power-transition problem → `references/suspend.md`. Boot problem → the section
   below, which stays in `SKILL.md`.

**The boot section, folded in rather than given its own file.** `references/boot.md` was
specified and then dropped: once general `systemd-analyze` / `blame` / `critical-chain` material
is removed — that is model general knowledge, and the skill's narrowing rule excludes it — only
about twenty lines of genuinely machine-specific content remain, which does not justify a file
the reader must load. What survives, both verified on 2026-09-06:

- `systemctl --user show network-online.target -p LoadState` returns **`not-found`**. A user unit
  ordering against it is inert and silent on every machine. The mechanism that does work is
  `Restart=` with a `StartLimitIntervalSec`/`StartLimitBurst` window wide enough for the backoff.
- `systemctl --user --failed`, and the persistent `~/.local/state/service-failures/failures.log`
  behind `notify-failure@` — a popup is useless if nobody was at the machine.

Plus `coredumpctl`, and a pointer for initramfs rather than a reimplementation: `config-drift`'s
last-pacman-transaction check already owns that. Worked example: the 2026-09-04 13:34 boot, where
wifi took 103 s and `rclone@gdrive` had the mount serving 4.6 s after the network became usable.

### `references/suspend.md`

**The first probe is `journalctl -t unblock-fuse`, not the freezer or FUSE state.** Verifying the
hook changed the order here. It logs one line per suspend *including the boring no-op case*, and
its own source says why that was deliberate: without it, "nothing in the journal" means both "ran
and found nothing" and "never ran at all" — the ambiguity that let `restart-swayidle` sit dead
through 1002 resumes. 31 lines to date, the last five all `pre: no wedged FUSE tasks, nothing to
do`.

So on this machine **silence is itself a finding**: a suspend with no `unblock-fuse` line means
the hook did not run, and the next check is `+x` on the installed copy — which `config-drift`
also checks, for the same reason.

Then, in order:

- the two shapes — **pointed at**, not duplicated, in `references/incident-2026-09-02.md`;
- `systemctl show user.slice -p FreezerState --value` — healthy is `running`; during the failure
  the user manager is `frozen-by-parent`;
- `/sys/fs/fuse/connections/*/waiting` — healthy is `0` on every connection (on 2026-09-06 there
  were three, 77/78/80, all zero). Non-zero means requests outstanding, and `abort` releases a
  waiter that `SIGKILL` cannot reach;
- finding the wedged task: `State: D` in `/proc/PID/status` with `wchan` matching
  `request_wait_answer` — **not** `/proc/PID/stat`, whose positional fields land inside the
  process name when `comm` contains spaces. That wrong-probe lesson is already encoded in the
  hook's source and is repeated here because the skill is where someone will look for it;
- the resume path's moving parts, written as *things to check the current state of* rather than
  as facts that will age.

### Authoring rules, binding on every file in the skill

A `SKILL.md` is pure prose, so it has no code to contradict — the `tmux-theme` failure cannot
even be *detected* there. The defence is structural:

1. **No restated values.** Every factual claim is either a command the reader runs or a pointer
   to the file that owns the fact. This is `config-drift`'s own principle — assert on rendered
   behaviour, not on configuration — applied to prose.
2. **No present-tense claims about the machine; dated past-tense observations instead.** "456
   aborts on 2026-09-02" cannot rot. "`ath11k_pci` is not reloaded on resume" can.
3. **Gates state their precondition,** so a stale reference file shows up as "this condition no
   longer occurs" rather than as quietly wrong advice.

### Frontmatter

```yaml
---
name: diagnose-boot-or-suspend
description: >
  Investigate a boot or suspend/resume that misbehaved on this machine, using the journal
  as the primary evidence source. Use when a resume failed or hung, the machine did not
  sleep, wifi or audio did not come back, the lid did nothing, boot was slow or degraded,
  a unit failed at startup, or the laptop was "weird overnight". Covers boot selection,
  freezer and FUSE state, the suspend retry-loop signature, and which probes have given
  wrong answers here before.
---
```

## Where `config-audit`'s parts go instead

**Into `bash/config-drift`** — two checks, each diffing against a tracked baseline rather than
reporting a count, because both sets churn:

- the unowned-`/etc` sweep against `etc/unowned.txt`, seeded with today's 172 entries;
- `pacman -Qii '[modified]'` against `etc/modified.txt`, seeded with today's 24.

A new entry is a finding; accepting one is a commit whose message carries the reason. That puts
the audit's own output in git history. (The second baseline follows the same argument as the
first, which was the one explicitly agreed.)

**Into `CLAUDE.md`** — the two probe rules, as a short subsection. Nothing in the repo states
either generally today; each instance is recorded locally to its own subject, which is why the
same mistake has now been made seven times.

> **An empty result is not a negative result.** Before reporting that a probe found nothing,
> prove the probe could have found something. A typo'd `journalctl -u` and a genuinely quiet
> unit are byte-identical — both `-- No entries --`, both exit 0. `pacman -Qii` reports
> `/etc/shadow` as unmodified because it cannot read it. `/home/.snapshots` reads as an empty
> directory. A zsh glob silently omits `.duckdbrc`.

> **A probe that answers confidently may be answering a different question.** Name the question
> the probe actually answers before trusting it. `fc-match` answers a charset query, not a
> rendering one; `grep ENCRYPTED` answers a PEM question, not an encryption one; `pacman -Qkk`
> answers a stat question, not a content one.

**Also into `CLAUDE.md`**, beside "Add a new config to dotfiles": the audit workflow — branch,
one commit per finding, verify empirically, `--no-ff` merge. It is ~12 lines and lives only in
session memory today.

## Keeping it honest

**Handed to `TODO.md` §10 (C)** — three greps, not a test of the skill's prose: every path the
skill names exists; every `bash/<tool>` it says to run exists and is executable; every
`references/` file it routes to exists. About ten lines, the `bin-style-test.sh` shape, catching
the whole rename-and-delete class. **Not a blocking dependency** — the skill ships first and
hands §10 (C) that list.

Deliberately **not** asserted: the 2026-09-02 journal query. It is the skill's worked example and
retention will eventually drop it. A test that fails when the journal rotates is the tmux-power
mistake in a new costume.

**Trigger testing is a separate axis.** Run 10–20 realistic phrasings and confirm the skill
loads: "it didn't wake up", "wifi was gone this morning", "boot was slow", "it was weird
overnight", "the lid did nothing", "did it suspend last night".

## Conformance to the Agent Skills conventions

Checked, because several cut against this repo's instincts:

- **Folder in `kebab-case`, file exactly `SKILL.md`.** Complies.
- **No `README.md` inside a skill folder.** A real trap here — this repo puts a `README.md`
  beside almost everything (`etc/`, `containers/`, `uv/`, `sioyek/`). Documentation goes in
  `SKILL.md` or under `references/`.
- **`description` under 1024 characters, no angle brackets, carrying *when to use* and not only
  *what it does*.** It is the only thing the model sees when deciding to load.
- **Subdirectories are `references/`, `scripts/`, `assets/`** — not the bare siblings Omarchy
  uses. Adopted; it costs nothing and matches the standard.
- **`name` may not contain "claude" or "anthropic".** It does not.

## The test, corrected twice (2026-09-06)

The three-part test in the brief — procedural, occasional, too long for `CLAUDE.md` — is
necessary and **not sufficient**. Two candidates got a long way on it before failing for reasons
it does not express.

### Fourth leg: is the knowledge already a runnable artifact?

`link-aocl-blas` passes all three legs. 54 lines in `CLAUDE.md`, a CMake recipe plus five
silently-failing traps, needed once per new C++ project. It should still not be a skill, because
`~/learning/playground/aocl-check/CMakeLists.txt` already carries every build-side decision as
inline comments — and that artifact is **executable**. Verified 2026-09-06: it configures, builds,
`ctest` passes, and the built binary's `RUNPATH` is `/usr/lib:/opt/aocl/gcc/MT/lib_LP64`, `/usr/lib`
first exactly as its comments claim.

A skill there would reduce to "copy this file and read its comments" — a pointer, not a
procedure. So:

> **If the knowledge is already externalised as something you can run, that beats a skill.**
> Running it proves the wiring; a document only asserts it.

Same principle as `config-drift` asserting on rendered behaviour rather than configuration. The
mistake that produced this candidate was counting lines in `CLAUDE.md` and inferring a gap
without checking whether something already filled it.

Note what does *not* move: the guardrails (`aocl-gcc` is load-bearing and must not be flagged as
unused; never add AOCL's lib dir to `ld.so.conf.d`) stay always-loaded, because their value is
firing when you are **not** doing C++ work.

### Fifth consideration: who reads the skill?

Every candidate in the first survey was judged by "does the maintainer need this written down?"
That is the wrong question, and it silently excluded a whole class. **Skills are read by agents.**

An agent cannot press `Print`. It is the thing that creates a second venv beside an existing one.
It is the thing that reaches for `sudo podman` because that is what the rest of the world does.
Procedures that are trivial for a human at a keyboard can be genuinely unavailable to an agent,
and the reverse also holds — a keybinding is not a procedure for a person but *is* one for an
agent, which must reach the same outcome through a different mechanism.

Worked example: `capture`/screenshots was rejected in the first survey as "niri has native
bindings, one command each". True for a person, false for an agent — `niri msg action screenshot`
opens an interactive UI and is unusable non-interactively, while `grim` is. Verified 2026-09-06:
`grim` captures 1920x1200 headlessly from a normal shell.

So the question to ask of a candidate is not only *is this written down*, but **who is blocked
without it, and what can they actually execute?**

## Deliverables — all implemented 2026-09-06

**Only one item had a clock on it, and it was the skill.** An earlier draft put the
`config-drift` and `CLAUDE.md` work first on the grounds that it is independent. True and
irrelevant: a diagnostic skill **cannot be tested on a healthy machine**, and the only
known-answer fixture is a journal window that expires. `journald` is capped at
`SystemMaxUse=200M`, sat at 177.8 MB with the oldest entry at 2026-07-19 — about 49 days — so the
2026-09-02 incident rotates out around **2026-10-21**.

| # | Deliverable | State |
|---|---|---|
| 0 | `references/incident-2026-09-02.md` — the fixture, distilled while the journal still had it | done |
| 1 | `CLAUDE.md` gains the two probe rules — they are the skill's own authoring constraints, so they came first | done |
| 2 | `skills/diagnose-boot-or-suspend/` — `SKILL.md` (119 lines) plus `references/suspend.md` (123) | done |
| 3 | `install.sh` symlinks it to `~/.claude/skills/`; `~/.claude/skills` joins `config-drift`'s `roots` | done |
| 4 | Conformance and link checks | done, passing |
| 5 | `config-drift` gains the two `/etc` sweeps against `etc/unowned.txt` and `etc/modified.txt` | done |
| 6 | `CLAUDE.md` gains the audit workflow beside "Add a new config to dotfiles" | done |
| 7 | The three assertions recorded in `TODO.md` §10 (C) | done |

### What implementation changed

**The raw unowned sweep was the wrong baseline.** 131 of its 172 paths are
`/etc/ca-certificates/{extracted,trust-source}/`, rewritten wholesale by `update-ca-trust`. A
baseline containing them churns on every `ca-certificates` update, and `config-drift`'s own
header already says why that is fatal: *a warning that fires on every run is a warning you stop
reading.* Those two trees are excluded in code, with the reason inline, and the baseline is the
44 paths that remain — a file small enough to actually review, which 172 was not.

**Both checks report a diff, never a count**, and a path disappearing is reported in blue rather
than as a warning: a file going away is usually a package doing its job, but it still has to be
said or the baseline rots into fiction.

**Both baselines were verified identical to the live sweep** at the moment they were written, and
the new check was proven by a negative test — removing one line from `etc/unowned.txt` makes it
report exactly that path as undecided. Total `config-drift` runtime is 2.1 s.

**The `~/.claude/skills` root was proven covered, not assumed.** A temporary broken symlink there
was detected by the same `-xtype l` scan that finds dangling configs, and the real skill symlink
is counted among the 132 links into the repo.

## What building the fixture already found

Recorded because it is the argument for the skill, made by the skill's own method before the
skill exists.

**A number in `CLAUDE.md` was wrong, and is now corrected.** It read *"916 suspend attempts, 456
hard aborts"*. Counted per boot: **460** attempts, **456** aborted, **4** succeeded, and
460 = 456 + 4. The 916 was `Starting System Suspend` + `Failed to freeze unit` summed — both
logged once per attempt, so a doubled count rather than an attempt count.

**And a second number was left alone on purpose.** `CLAUDE.md` also cites 1831 wifi disconnects;
a pattern written on 2026-09-06 returns 910 for that boot. It is a *different pattern from the
one that produced 1831*, and there is no record of the original. A number from a probe you wrote
is not evidence against a number from a probe you cannot see — which is the second `CLAUDE.md`
rule being applied to itself. Left unresolved and noted.

Corrected during this session rather than deferred: `etc/README.md`
presented `pacman -Qii` and `-Qkk` as one check. They are not, and neither is a superset of the
other.
