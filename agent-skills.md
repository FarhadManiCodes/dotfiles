# Agent skills — assessment against Omarchy's, 2026-09-05/06

Read against `~/projects/omarchy` at `49306774`. Separate from `docs/omarchy-comparison.md` on
purpose: that document is about *configuration*, this one is about how agent-facing
documentation is organised, which is a different question with a different answer.

**Everything here is closed.** It is kept for one job: so a declined skill is not re-proposed
at the next audit, and so the test that declined it is reusable.

> **On the shape of this file.** It was 965 lines — a working design session that carried its
> brief, the prompt written to open the session, brainstorming scaffolding, the full skill
> specification, and the argument that its own later sections overturned. The session shipped
> on 2026-09-06 and the scaffolding has nothing left to scaffold, so it was cut to the
> dispositions and the reusable test on **2026-09-09**, the same treatment
> `docs/omarchy-comparison.md` had on 2026-09-08. Section names are unchanged where `TODO.md`
> and `docs/omarchy-comparison.md` cite them; the full argument is in
> `git log -p -- agent-skills.md`.

**Superseded numbers.** This file's line counts and `CLAUDE.md:NNN` citations were written when
`CLAUDE.md` was 969 lines. It is now a 10-line `@AGENTS.md` import; the guardrails are in
`AGENTS.md` (67 lines) and the reasoning in `docs/architecture.md` + `docs/system-notes.md`.
Read every count below as "as of 2026-09-05", and none of the line numbers resolve.

---

## Two different mechanisms, easily confused

Omarchy has both, and only the second is a Claude Code skill:

| | `agents/skills/*.md` | `default/agents/skills/*/SKILL.md` |
|---|---|---|
| Format | Plain markdown, **no frontmatter** | YAML frontmatter (`name`, `description`) |
| Mechanism | Linked from `AGENTS.md`: *"Read the matching guide before starting"* | The Skill tool — loaded on demand by description match |
| Audience | Anyone working **on** Omarchy | End users configuring **their own** desktop |
| Count | 7 files, 438 lines | 2 skills (`omarchy`, `diagnose-crash`), 9 files |

The first kind is a convention, not a feature: it works because `AGENTS.md` names each file and
says when to read it. The second is what a `description` trigger list is for — that string is
all the model sees when deciding whether to load.

## The seven, one by one — none transfers

| Skill | Lines | Verdict |
|---|---|---|
| `command-metadata.md` | 31 | **No.** `# omarchy:summary=` headers for a 440-command router. `bash/` has 38 scripts, all invoked by keybinding, unit or name, and no router — already declined in `docs/omarchy-comparison.md` as ceremony |
| `install-scripts.md` | 19 | **No.** Describes their `install/` tree. Here `install.sh` is one file |
| `shell-dev.md` | 49 | **No.** Quickshell/QML desktop |
| `icon-font.md` | 79 | **No.** Adding glyphs to their branded TTF |
| `acceptance-tests.md` | 46 | **No.** A graphical suite in a disposable VM via a sibling `omarchy-iso` repo, with QMP virtual-keyboard input |
| `migrations.md` | 170 | **No.** Versioned one-shot repairs with per-user markers — one machine, one user, and `install.sh` is idempotent |
| `visual-verification.md` | 44 | **Principle yes, content no.** Its principle is sound, but every mechanic is an Omarchy command and the one portable tool it names, `wtype`, is not installed here |

## What did transfer: split docs by *kind*, not by topic

Omarchy states the rule in `AGENTS.md` and follows it — task procedure in `agents/skills/`,
system shape in `docs/`, end-user material in `manual/` — with everything long behind a pointer.

Applied here, the useful form is sharper than "move big sections out". A section is not
homogeneous. It contains **guardrails**, whose whole value is being seen without being asked
for (*"never `sudo podman`"*, *"never enable the system `podman.socket`"*), and **evidence and
reasoning**, which is why the decisions are trustworthy and is needed roughly never.

**So the split is by kind: invariants stay always-loaded, reasoning moves behind a pointer.**
A skill that fails to load is a guardrail that was not there, so for rules whose cost of being
missed is a security regression, always-loaded is the correct trade.

**Done 2026-09-05.** `containers/README.md` took the reasoning; the guardrails stayed. The
remaining candidates were measured and **declined**: `Package notes` has the highest guardrail
density in the file (it is a do-not-touch list, and moving it behind a pointer is how
`aocl-gcc` gets removed as unused), and `rclone` has no directory to live in. The rule that
fell out: split only when the section is >150 lines, below ~8 guardrails per 100 lines, and a
tracked directory already exists.

---

# Agreed design (2026-09-06) — one skill shipped

## What measuring changed, before any design

Six probes were run first. **Five contradicted something the design was about to rest on**,
which is why the two probe rules ended up in the always-loaded file rather than in a skill.

| Assumption | Measured 2026-09-06 |
|---|---|
| The audit sweeps are slow, so `config-drift` needs a gated `--audit` mode | Unowned-`/etc` sweep **1.15 s**; `pacman -Qii \| grep '[modified]'` **40 ms**. No gate needed. |
| `pacman -Qkk` is the tool for modified package configs | **19 s**, and as non-root it emits 110 warning lines, mostly checksum failures — unreadable, not altered |
| Suspend evidence is volatile, so a capture script earns its place | The journal retains **41 boots, 178 MB**, back past 2026-07-26 |
| The unowned-`/etc` count is stable enough to assert | **172** today against **183** on 2026-09-04. A count is not a finding; only a diff against a tracked baseline is |
| A failed `journalctl` query is distinguishable from a quiet one | It is **not**. Byte-identical: both `-- No entries --`, both exit **0** |

One discrepancy is deliberately **not** resolved: `Starting System Suspend` in that window is
456, not the 916 attempts then documented. The same event counted at a different layer gives a
different number — recorded so the next reader does not assume a typo.

## Why `config-audit` was dropped

**Its best content — the wrong-probe catalogue — is not procedural. It is an invariant.** Seven
instances collapse into two rules of three lines each, which belong where they are always
loaded.

**And its trigger is every session, not just audits.** The `fc-match` error happened during a
config comparison, the `grep ENCRYPTED` false alarm during an SSH review, the `-Qkk` error
during the design session itself. A skill loading on the word "audit" would not have been
loaded for any of the three — precisely the guardrail-that-did-not-load failure.

Once the catalogue leaves, the rest disperses: the sweeps are `config-drift` features, the
audit workflow is ~12 lines, and the track/don't-track rules are already carried as worked
cases with reasons.

**Do not re-propose it as "the judgement half of the audit".** That framing is what made it
look viable for most of a session. The question that settles it is *when does this need to be
loaded* — and the answer is "when about to assert any finding", which is not an occasion.

## Why `diagnose-boot-or-suspend` survives

The objection was that it is method for a failure class seen once. That was wrong about the
domain: the class is not "FUSE wedge" but "the machine misbehaved across a power-state
transition", and the repo records **four** such investigations, each resolved by measurement —
the 2026-09-02 FUSE wedge, `restart-swayidle` proven never to have run across 1002 resumes,
`fix-wifi.sh` removed on nine measured resumes, and `rclone@gdrive` timed against a 103 s boot.

It is also the only candidate genuinely **not scriptable**: the next query depends on the last
answer, which is why `config-drift` cannot absorb it the way it absorbed the sweeps.

**Narrowing that must hold:** it is not a general systemd-debugging skill — that is model
general knowledge. The content is what is specific to this machine.

**Corrected while building the fixture.** The spine was first written as *"which line is absent
names the stage that failed"*. Reading a real failed cycle killed that: line 2 is not absent, it
is **replaced** by `Failed to freeze unit 'user.slice': Connection timed out`, and systemd then
attempts the suspend anyway — the abort lands one line later, in the kernel. A stage fails by
**substitution** as often as by absence. The corrected spine compares against the known-good
chain and names the first line that *differs*.

## Where `config-audit`'s parts went instead

- **Into `bash/config-drift`** — the unowned-`/etc` sweep against `etc/unowned.txt` and
  `pacman -Qii '[modified]'` against `etc/modified.txt`, each diffing a tracked baseline rather
  than reporting a count, because both sets churn. A new entry is a finding; accepting one is a
  commit whose message carries the reason.
- **Into the always-loaded file** — the two probe rules, and the audit workflow (branch, one
  commit per finding, verify empirically, `--no-ff` merge).

---

## The test any candidate must pass, corrected twice

**Procedural, occasional, and too long for the always-loaded file** — necessary and **not
sufficient**. Two candidates got a long way on three legs before failing for reasons those legs
do not express.

**Fourth leg: is the knowledge already a runnable artifact?** `link-aocl-blas` passes all three
legs and should still not be a skill, because `~/learning/playground/aocl-check/CMakeLists.txt`
already carries every build-side decision as inline comments — and that artifact is
**executable**. Verified 2026-09-06: it configures, builds, `ctest` passes, and the binary's
`RUNPATH` is `/usr/lib:/opt/aocl/gcc/MT/lib_LP64`, `/usr/lib` first exactly as claimed.

> **If the knowledge is already externalised as something you can run, that beats a skill.**
> Running it proves the wiring; a document only asserts it.

The mistake that produced that candidate was counting lines and inferring a gap without
checking whether something already filled it. Note what does *not* move: the guardrails stay
always-loaded, because their value is firing when you are **not** doing C++ work.

**Fifth consideration: who reads the skill?** Every candidate in the first survey was judged by
"does the maintainer need this written down?" That is the wrong question. **Skills are read by
agents.** An agent cannot press `Print`; it is the thing that creates a second venv beside an
existing one, and reaches for `sudo podman` because that is what the rest of the world does.

Worked example: screenshots were rejected in the first survey as "niri has native bindings, one
command each". True for a person, false for an agent — `niri msg action screenshot` opens an
interactive UI and is unusable non-interactively, while `grim` is. Verified 2026-09-06: `grim`
captures 1920x1200 headlessly from a normal shell.

So the question is not only *is this written down*, but **who is blocked without it, and what
can they actually execute?**

## Conformance to the Agent Skills conventions

Several cut against this repo's instincts, so they are worth keeping:

- Folder in `kebab-case`, file exactly `SKILL.md`.
- **No `README.md` inside a skill folder** — a real trap here, where a `README.md` sits beside
  almost everything. Documentation goes in `SKILL.md` or under `references/`.
- `description` under 1024 characters, carrying *when to use* and not only *what it does*.
- Subdirectories are `references/`, `scripts/`, `assets/` — not the bare siblings Omarchy uses.
- `name` may not contain "claude" or "anthropic".

## Deliverables — all implemented 2026-09-06

**Only one item had a clock on it.** A diagnostic skill cannot be tested on a healthy machine,
and the only known-answer fixture was a journal window that expires: `journald` is capped at
`SystemMaxUse=200M`, so the 2026-09-02 incident rotates out around **2026-10-21**.

| # | Deliverable | State |
|---|---|---|
| 0 | `references/incident-2026-09-02.md` — the fixture, distilled while the journal still had it | done |
| 1 | The two probe rules, into the always-loaded file | done |
| 2 | `skills/diagnose-boot-or-suspend/` — `SKILL.md` plus `references/suspend.md` | done |
| 3 | `install.sh` symlinks it; `~/.claude/skills` joins `config-drift`'s roots | done |
| 4 | Conformance and link checks | done, passing |
| 5 | `config-drift` gains the two `/etc` sweeps against their baselines | done |
| 6 | The audit workflow, into the always-loaded file | done |
| 7 | The three assertions recorded in `TODO.md` §10 (C) | done |

### What building it already found

**The raw unowned sweep was the wrong baseline.** 131 of its 172 paths are
`/etc/ca-certificates/{extracted,trust-source}/`, rewritten wholesale by `update-ca-trust`. A
baseline containing them churns on every update, and *a warning that fires on every run is a
warning you stop reading*. Those trees are excluded in code, leaving 44 paths — a file small
enough to actually review, which 172 was not.

**Both baselines were verified identical to the live sweep** when written, and the new check was
proven by a negative test: removing one line from `etc/unowned.txt` makes it report exactly that
path as undecided.
