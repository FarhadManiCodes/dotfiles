# Herdr Migration: Implementation

Status: **Not started (updated 2026-10-24; quality checks are Milestone 0 and the repository baseline Milestone 0.5)**
Decisions, reasons and the draft config live in `docs/herdr-migration.md`; "Step N" below refers to its steps.

Testing a config without touching the live one: copy it to `~/.cache/hx/herdr/config.toml` and run `env -u HERDR_CONFIG_PATH XDG_CONFIG_HOME="$HOME/.cache/hx" herdr config check`, then delete `~/.cache/hx`; `HERDR_CONFIG_PATH` would override the copy. To try it in a throwaway session, launch `env -u HERDR_CONFIG_PATH XDG_CONFIG_HOME="$HOME/.cache/hx" herdr --session <name>`. Write `$HOME`, not `~`: as an argument to `env`, zsh leaves `~` unexpanded, and Herdr then finds no config and still reports `Config: ok`. Only that launch needs the short path: under the scratchpad its socket path exceeds `sun_path` and fails, while `config check` works from any path (tested at 109 characters, 2026-10-24). Prove the check can fail by also running it on a deliberately conflicting key.

---

## Milestones

- **Branches:** one branch per milestone, named `herdr/<n>-<name>`, cut from `master` after these two docs are merged. Each is reviewed and lands as a `--no-ff` merge, never a squash or fast-forward, before the next one that depends on it starts. Milestone 0's blame-ignore entry needs the branch to land without a squash or rebase, which would change the formatting commit's ID. Tick the boxes on the milestone's branch. Milestone 1 keeps the `herdr/` name instead of `AGENTS.md`'s `add-<name>-config` on purpose (user decision, 2026-10-23). Milestone 0.5 is an audit of the whole in-scope repository, so it follows `AGENTS.md`'s audit rules instead, with a `-baseline` suffix on the audit branch name so it cannot collide with a regular monthly audit.
- **Order:** 0 → 0.5 → 1 → 2 → 3–7 in any order consistent with their declared implementation prerequisites → 8. A prerequisite milestone must be reviewed and merged before its dependent work starts. Milestone 0 prepares implementation checks and Milestone 0.5 measures the repository with them; the daily-use cutover remains Milestone 2.
- **Shared conventions:** Milestones 3, 5 and 6 must use compatible conventions for project association and editor lookup, including after pane IDs change. The first milestone needing them establishes and documents them; later milestones reuse them and declare any prerequisites before starting dependent work. Milestones 3 and 7 must also agree on how temporary fzf panes are excluded from restart recovery. This coordination does not expand the agentic-layer scope.
- **Integration checks:** Each later milestone reruns affected acceptance checks from earlier milestones. Whichever of Milestones 3 and 7 lands later verifies that a restart with an open temporary fzf pane excludes that pane while eligible persistent panes recover correctly.
- **tmux retires from daily use at Milestone 2.** Nothing else blocks the switch (user decision, 2026-10-23). tmux stays installed only to compare behavior side by side while features are ported, and is removed in Milestone 8.
- **"Prove first" boxes** cover a mechanism that is not chosen yet. They must pass before the build work starts. If one fails, stop and discuss rather than building around it.

| # | Branch | Goal | Status |
|---|---|---|---|
| 0 | `herdr/0-quality-checks` | Local prek checks and implementation discipline ready | Not started |
| 0.5 | `audit-<yyyy-mm>-baseline` | Repository measured and related files mapped | Not started |
| 1 | `herdr/1-base-config` | Tracked Herdr config live, launcher unchanged | Not started |
| 2 | `herdr/2-switch-launcher` | `Mod+Return` opens Herdr; daily use moves over | Not started |
| 3 | `herdr/3-restart-recovery` | Editors, agents and tools come back after a restart | Not started |
| 4 | `herdr/4-copy-output` | Copy the last command's output, or report unavailable | Not started |
| 5 | `herdr/5-layouts-agents` | `Prefix+W` layout picker, `Prefix+A` agent tabs | Not started |
| 6 | `herdr/6-cpp-tools` | `bash/tmux-cpp-tools` ported to Herdr | Not started |
| 7 | `herdr/7-fzf-pane` | fzf in a temporary split pane inside Herdr | Not started |
| 8 | `herdr/8-retire-tmux` | tmux config, helpers and package removed | Not started |

### Implementation discipline (all milestones)

- Work against the current milestone's acceptance criteria. Keep unrelated cleanup, speculative features and extension points out of the change.
- Treat `bash/tmux-cpp-tools` as a reference for required behavior, not a standard for code structure or complexity. Keep project lookup, pane targeting and task execution in clearly owned helpers; extract shared behavior for actual callers rather than copying it or building a generic framework.
- Justify new dependencies, background processes and persistent state against a concrete requirement. Keep external commands and state changes explicit; pass project/pane context rather than rediscovering global focus.
- Keep functions focused on one responsibility and nesting shallow. Review branching, state ownership and cleanup paths alongside size/complexity reports; splitting files or adding forwarding helpers solely to lower a score is not simplification. No per-function complexity limit is claimed without a validated Bash/Zsh-aware analyzer.
- Keep comments about reasons and constraints. Keep agent updates and commit summaries concise: outcome, checks, exceptions and remaining gaps. Reference existing decisions rather than repeating their rationale.
- New checks need observable pass/fail fixtures and must not rely on inherited locale or color settings. Tests assert required behavior, especially failure and cleanup paths, rather than mirroring implementation details. Missing tools or unexecuted checks are not passes.
- Explain any check suppression with its exact scope and reason. Do not broaden exclusions, move a comparison base to hide a finding, pass a reported clone without judging it, weaken thresholds or bypass a failed hook to get a commit through. Keep legitimate exceptions reviewable with the change.

### Milestone 0: Local quality checks and implementation setup
Decisions: Step 1 (implementation preparation). These are developer Git hooks; existing agent integrations remain outside this milestone.

Prerequisites verified on 2026-10-24: Cargo-installed `prek 0.5.7`, `shfmt 3.14.1`, `jscpd 5.4.2` and `shellcheck-bin 0.11.0` are available. No additional package or analyzer is selected.

Work:
- Add a repository-local `.pre-commit-config.yaml` using local hooks and installed tools. Keep standard pre-commit-compatible settings; do not introduce GitHub workflows or global Git configuration. Put any necessary dispatch logic in one small tracked script callable independently of prek.
- **Staging policy — user decision, 2026-10-24:** Allow selective commits, including `git add -p`, while unrelated tracked edits remain unstaged. Export the proposed commit's complete tracked snapshot from the Git index to a temporary directory, including unchanged context needed by the checks. Run prek and its checks there using the staged configuration and code. The live hook must enter this isolation before prek can hide unstaged changes; never stash, reset, check out or rewrite the live working files to prepare checks. Untracked working files are not copied into the snapshot. Clean up the temporary snapshot after success, failure or interruption.
- **Snapshot mechanism — user decision, 2026-10-24** (prototyped in a disposable repository):
  - Build the snapshot in a new directory from `mktemp -d "$XDG_RUNTIME_DIR/herdr-hook.XXXXXX"`, unique per run so concurrent commits and leftovers from a killed run cannot collide; if `$XDG_RUNTIME_DIR` is unset or missing, or `mktemp` fails, fail with a clear message and never fall back to the current directory, which could be inside the live checkout. Use `git clone --shared --no-checkout`, copy the commit's index into the clone and write it out with `git checkout-index -a -u` (`-u` refreshes the stat data, so the clone shows no unstaged changes). This writes nothing into the live `.git`; the clone's `git diff --cached` lists exactly the staged files. With `--amend` it lists only what the amend changes. Files already in the amended commit were checked when it was made, unless it was made without the hook (before activation, by a rebase or cherry-pick, or with `--no-verify`, which the discipline above forbids); the full run before each milestone review covers those.
  - The commit's index is the file in `$GIT_INDEX_FILE`, not `.git/index`: during `git commit -a` or `git commit <path>` Git uses a temporary index. Find it, set or unset, with `git rev-parse --path-format=absolute --git-path index`, run before anything is unset: it honours `GIT_INDEX_FILE`, including Git's `index.lock` and `next-index-*.lock` temporary indexes, and returns an absolute path. Do not join `GIT_PREFIX` onto it, since Git resolves a relative `GIT_INDEX_FILE` against the top. Without `--path-format=absolute` the path is relative to the current directory, so from `bash/` it is `../.git/index` (all tested with a real hook from a subdirectory, 2026-10-24). Fail with a clear message if that index is split, detected from the index itself (its `link` extension) rather than `core.splitIndex`, because `git update-index --split-index` splits it without setting that option; the copy would point at a shared index the clone lacks. This repository does not use one. Likewise fail if the index has skip-worktree entries, which `checkout-index -a` would not write, and drop any untracked-cache or fsmonitor data from the clone's copy with `git update-index --no-untracked-cache --no-fsmonitor` inside the clone, since it describes the live directory (none are in use here, checked 2026-10-24).
  - Order: first save the checkout's top (`git rev-parse --show-toplevel`), the resolved index path and HEAD's commit ID (empty when HEAD does not exist yet, which is not an error), then unset the variables that point Git at a repository (`GIT_DIR`, `GIT_WORK_TREE`, `GIT_INDEX_FILE`, `GIT_PREFIX`, `GIT_COMMON_DIR`, `GIT_OBJECT_DIRECTORY`, `GIT_ALTERNATE_OBJECT_DIRECTORIES`), then run `git clone --shared --no-checkout "$top" "$snapshot"` with the saved top as its source, copy the saved index into the clone, and run `checkout-index` inside the clone. Otherwise Git inside the clone reads and writes the live index (seen with `git commit -a`). Also unset `GIT_CONFIG_PARAMETERS`, `GIT_CONFIG_COUNT` and the `GIT_CONFIG_KEY_<n>`/`GIT_CONFIG_VALUE_<n>` pairs: they carry `git -c` settings into the hook, and `git -c core.whitespace=-trailing-space git commit` would otherwise make `git diff --cached --check` pass trailing whitespace. Keep exactly `GIT_CONFIG_GLOBAL`, `GIT_CONFIG_SYSTEM` and `GIT_CONFIG_NOSYSTEM`, which choose configuration files rather than set values, so a fixture that isolates Git from the user's configuration stays isolated inside the hook; fixtures set any configuration the checks need through such a file, not `git -c`. The `-c` settings still apply to the commit itself, for example its author (tested with a real hook, 2026-10-24). Read and pass every path list NUL-separated (`git diff --cached --name-only -z`, `git ls-files -z`, and the lists handed to the checks), so quoting settings cannot change them.
  - These three points were tested 2026-10-24 with a real hook on `git commit -a`, partial staging and `git commit <path>`.
  - Remove the snapshot with a trap on exit and interruption. Pass the base for comparisons as a commit ID, because the clone sees the live branches under `origin/`. Submodules are not copied.
  - Never run `prek install`: its hook hides unstaged changes by rewriting the live working files. `.git/hooks/pre-commit` and `.git/hooks/pre-merge-commit` both call a small tracked bootstrap; a merge without conflicts runs only `pre-merge-commit`, so without it the `--no-ff` milestone merges would go unchecked, including any clone that appears only when two branches combine. The bootstrap only builds the snapshot, then runs the staged copy of the dispatcher inside the snapshot, which runs prek there and passes prek's exit status through unchanged. The bootstrap is the one file used from the live checkout; everything else the checks use comes from the snapshot. It aborts with a clear message when its live copy differs from its staged copy, so the hook never runs unreviewed bootstrap logic. While the bootstrap has unstaged edits, commit them first; this limit is accepted because the bootstrap is small and rarely changes (user decision, 2026-10-24). On a branch that does not contain the bootstrap, such as one older than Milestone 0, the hooks print a note and let the commit through, since that branch has no checks to run.
- Define the check scope explicitly, including extensionless helpers and dotfiles. Leave tmux files (`tmux/`, `bash/tmux-cpp-tools`, `tests/test_tmux_cpp_tools.py`) out; they retire at Milestone 8, and behavior copied from them while porting is not tracked as a clone (user decision, 2026-10-24). Compare changed files against the unchanged production code in scope as well as each other; Milestone 0.5's map of related files may narrow this later. Keep generated files, plugin clones, submodules and fixtures out of production-code metrics; scoped Neovim checks still follow `nvim/AGENTS.md`.
- Check staged whitespace with `git diff --cached --check`. Shell files are checked by dialect, each selected its own way, and the check and the reformat always pass an explicit file list, never a directory:
  - **Bash and POSIX `sh`** are selected by shebang. Every such script carries one, sourced ones included (user decision, 2026-10-24); a script without one is deliberately left out of these checks. Check with `bash -n` (`sh -n` for `sh`), `shellcheck -x` when sourcing repo files, and `shfmt -d`.
  - **Zsh** is selected by path: `*.zsh`, the startup files `zsh/.zshenv`, `zsh/.zshrc` and `zsh/aliases`, and any script with a Zsh shebang (user decision, 2026-10-24). `zsh/.zshenv` and `zsh/aliases` have no shebang (`zsh/.zshrc` does), so selection by shebang would miss them; a new startup file, such as `zsh/.zprofile`, must be added to this list. Check with `zsh -n` and `shfmt -d`. No linter is used for Zsh: ShellCheck rejects it (`Unknown shell: zsh`), forcing it to Bash gave 201 findings in total across the 26 Zsh files that run covered (it did not include `zsh/update-plugins.sh`), mostly misread Zsh syntax, and no maintained Zsh linter is packaged (checked 2026-10-24).
  - **Formatting** uses `shfmt -d` with no formatting flags: the style (`-i 2 -ci -bn`, user decision, 2026-10-24) lives only in `.editorconfig`, because any formatting or dialect flag makes shfmt ignore that file. Put the settings in a `[[shell]]` section, which matches extensionless scripts and all three dialects; `[*.sh]` does not, and those scripts silently fall back to shfmt's defaults. shfmt recognises `.zshenv` and `.zshrc` as Zsh by name but parses `aliases` as Bash, so `.editorconfig` declares `shell_variant = zsh` for it (tested 2026-10-24). A test proves an extensionless fixture passes in this style and a tab-indented one fails. Editors formatting through stdin need `--filename`, as the `--to-json` rule below explains.
  - **Zsh formatting exceptions:** `zsh/functions/sysup.zsh` and `zsh/functions/sysup/tool-tests.zsh` use Zsh's `{ … } always { … }` block, which shfmt cannot parse; the construct is correct and stays. `zsh/.zshrc` is also left unformatted (user decision, 2026-10-24): it changes rarely, and the user reviews its changes by hand. All three are excluded from the reformat and the blocking `shfmt -d` check, and keep `zsh -n` and the other checks.
- Report, without blocking, pipelines and `&&`/`||` chains longer than 3 (counted from `shfmt --to-json`) and lines longer than 80 columns. They are indicators to judge: 4 is acceptable after review (user decision, 2026-10-24). The counter cannot read the two `always` files, so it skips them by name and its report lists them as not measured. Skipping by name is deliberate: a new file shfmt cannot parse fails, here and in `shfmt -d`, until it is added to the named Zsh exceptions, so each exception is a decision rather than a silent skip.
- Every `shfmt --to-json` call reads the file on stdin with `--filename <path>`: `--to-json` accepts only stdin, and without `--filename` it ignores `.editorconfig`, so `zsh/aliases` would be parsed as Bash (tested 2026-10-24).
- Prepare an isolated `herdr config check` for the staged TOML once Milestone 1 adds it, with `XDG_CONFIG_HOME` pointing at the snapshot and `HERDR_CONFIG_PATH` unset, for that one command only, so the staged `herdr/config.toml` is the one checked. `HERDR_CONFIG_PATH` overrides `XDG_CONFIG_HOME`: exported in the developer's shell, it would let an invalid staged config pass (verified 2026-10-24). Keep `XDG_CONFIG_HOME` on that one command too: exported for the whole hook, it would make Git and other tools read the tracked dotfiles as their own configuration. Its absence before Milestone 1 is explicitly not applicable; after adoption, missing or invalid configuration must fail. `herdr config check` exits 0 when no config file exists, so the hook first checks that the staged `herdr/config.toml` exists. Keep Niri/Neovim validation under their scoped instructions as those files enter later milestones.
- **Clones — user decision, 2026-10-24: report at every commit, judge at milestone review.** What a good level of duplication looks like here is not known yet, so the guard stays flexible until Milestone 0.5 shows the real state; Milestone 0.5 then decides whether to tighten it. Keep jscpd's detection defaults (`mild`, 50 tokens, 5 lines).
  - At each commit, the hook reports, without blocking, every clone that is new compared with HEAD, by file and line range, using `--baseline-from-ref <HEAD commit ID>`. In `pre-merge-commit`, HEAD is the branch being merged into, so the report shows the clones the merge adds; with `--amend`, it shows clones new compared with the commit being replaced, whose own clones were reported when it was made; before the first commit, with no HEAD, the hook skips `--baseline-from-ref` and reports every clone. The flag builds its comparison without writing any file (tested 2026-10-24). An edit inside an existing clone, even a blank line, changes its fingerprint and shows it as new (tested 2026-10-24); that is expected and is judged like any other report.
  - Before each milestone review, the full run reports every clone that is new compared with the milestone's base commit. Each must be fixed, or accepted in `revisit.md` with its files, the function or a short quote of its first line, and the reason (line numbers drift, so they are only a hint); it goes to `TODO.md` only when the user decides to defer the fix, before the review passes. No fingerprint file is tracked: accepted clones live in those readable entries. Milestone 0's own review does not judge clones: its reformat changes every existing clone's fingerprint, so all of them would show as new, and Milestone 0.5 judges every clone in scope, Milestone 0's tooling included, right afterwards.
  - Never use `--changed`: it writes `.jscpd-baseline.json` into the repository root and rebuilds it whenever HEAD moves. Do not pass `--fail-on-new-clones`: nothing blocks on clones yet.
- Do not treat the old helper's duplication or complexity as the target standard. Configure scan failures and unexpectedly empty scans as failures; documentation-only changes may explicitly have no applicable code checks. Give jscpd the explicit in-scope file list, never a directory, and map every listed file to its Bash format with `--formats-names`, not only the ones it would miss. Its own detection skips files with no extension and no shebang, such as `zsh/aliases`, and extensionless scripts with a Zsh shebang; both report 0 tokens exactly like a file below the 50-token minimum, so without the mapping the two cases cannot be told apart (tested 2026-10-24). With every file mapped, compare the number analyzed with the list: a file missing from it can only be below the minimum, which cannot hold a clone, and the dispatcher confirms that by scanning it alone with the same mapping (0 tokens). Fail on any other difference. Today the files below the minimum are `bash/open-detached` and `bash/pdf-meta`. `--fail-on-empty` alone misses a single skipped file in an otherwise full scan (tested 2026-10-24).
- Record file size and jscpd's file-level complexity estimate for affected production code against the milestone's base commit. Report changes for review; do not present those estimates as per-function or architectural guarantees. Record tool versions and effective configuration so the measurements can be repeated.
- Keep the commit hook to the applicable deterministic checks. Before each milestone review, run the same checks over every in-scope file in a snapshot of the branch tip, then `bash bash/run-tests` and each milestone's behavioral/manual acceptance checks; preserve failure and skip reporting. Add meaningful tests of the check dispatch and failure propagation to the existing suite rather than introducing another test framework.
- Finish in this order; the hook is not yet enabled for steps 1–5, so nothing blocks them:
  1. Commit the tooling: `.editorconfig`, `.pre-commit-config.yaml`, the bootstrap, the dispatcher and their tests. In the same commit, record in `AGENTS.md`'s Validation section the one-time reformat as the single exception to "do not reformat unrelated files", so the rule is amended before the reformat lands.
  2. Add a shebang to each Bash or `sh` script in scope that lacks one, such as the five sourced `bash/config-drift.d/*.sh` files, in its own commit.
  3. Reformat every Bash, POSIX `sh` and Zsh file in scope with these settings, apart from the three Zsh exceptions (user decision, 2026-10-24), so the formatting check covers all of them from the start and no hook rule is needed for a formatting commit. Make it one commit that changes nothing else. This is the one deliberate exception to `AGENTS.md`'s "do not reformat unrelated files". Root-installed copies such as `system-sleep/unblock-fuse` then differ from their reformatted sources until `install-root.sh` is rerun, which the user does; `bash/config-drift` reports them meanwhile.
  4. Add the formatting commit's ID to `.git-blame-ignore-revs`, with its test in the same commit. A rebase changes that ID, so a test in `bash/run-tests` checks that every listed ID is a commit and an ancestor of HEAD; a stale entry then fails before the merge. The branch must land without a squash or rebase, which would change that ID. Then set `git config blame.ignoreRevsFile ':(optional).git-blame-ignore-revs'` in this checkout. The `:(optional)` prefix matters: the setting applies in every checked-out tree, and without it a tree lacking the file (an older branch, a bisect step) makes every `git blame` fail with exit 128. With it, blame works there and still skips the formatting commit where the file exists (tested on git 2.56, 2026-10-24).
  5. Document setup, scope, exceptions, manual invocation and removal in `docs/architecture/git.md`, including the blame setting, since a fresh clone needs it as well as the hook. Describe the hook and the shfmt style in `.editorconfig` in `AGENTS.md`'s Validation section, worded as checking commits once it is enabled in step 6.
  6. After the isolation behavior below is proven in disposable fixtures, enable the hook only for this checkout; never use a live commit or installer run as the experiment.

Prove first:
- [ ] Prove that the hook runs prek against the isolated Git-index snapshot, with the required Git metadata/base reference for comparisons, and never invokes unstaged-change hiding in the live checkout. Everything except the bootstrap (the dispatcher, check configuration and shared source files) must come from that snapshot. Prove this before activation.
- [ ] Prove the Zsh comparison's normalizer before the reformat. It must catch a changed space inside quotes, including quotes nested inside `$( … )` (`$(print "a  b")` against `$(print "a b")`), and a removed space between words (`$(print a b)` against `$(print ab)`). It must treat `(( x ))` and `((x))`, `$((a+b))` and `$((a + b))`, and a pipeline moved across a line continuation, as equal, and still catch `$((a+b))` against `$((a-b))`.

Acceptance criteria:
- [ ] `prek validate-config` succeeds, and checks run both through the hook and on demand using the same configuration.
- [ ] Disposable Git fixtures show that syntax, lint, formatting and whitespace violations each block a commit; corrected fixtures pass. Missing tools, checker errors and unexpectedly empty scans also fail.
- [ ] A changed file duplicating an unchanged file is reported by name, without blocking. An extensionless script with a Zsh shebang and a file with neither extension nor shebang are both analyzed, and a file wrongly skipped fails the count check while a genuinely tiny one passes. Extensionless helpers, dotfiles, renamed/deleted files and paths with spaces are selected or excluded as documented; unrelated files are not reformatted or scanned accidentally.
- [ ] A valid staged version passes even when its unstaged version is invalid; an invalid staged version fails even when the working version is valid. Selective commits succeed with unrelated tracked edits left unstaged. Untracked files cannot mask missing staged inputs. Working files, staged contents and live symlink targets remain unchanged after success, failure and interruption; temporary snapshots are cleaned up.
- [ ] For a first commit, a plain commit, one started from a subdirectory, `git commit -a`, `git commit <path>`, partial staging, a clean `--no-ff` merge and an on-demand run from a subdirectory, the snapshot equals what the commit stores, the clone shows no unstaged changes, Git inside the clone resolves its index inside the snapshot, and the live index and working files are unchanged. A prototype passed all of these on 2026-10-24 (40 checks), and failed as expected when given the `GIT_PREFIX` join or no unsetting.
- [ ] A failing check fails the commit through the hook, not only when run on demand. `prek install` was not used. A commit run as `git -c core.whitespace=-trailing-space commit` still fails on trailing whitespace. A clean merge runs the checks through `pre-merge-commit`: a fixture merge bringing in a syntax error fails, and one that creates a new clone between the two branches passes with the clone named by file and line range.
- [ ] An unstaged edit to the dispatcher or a check configuration does not change what the hook runs; the staged versions do. An unstaged edit to the bootstrap makes the hook abort with a clear message.
- [ ] The report lists pipelines and chains longer than 3 and lines longer than 80 columns without blocking the commit, and the counter gives the right answer on a known input.
- [ ] Checks neither auto-fix nor auto-stage files, access the network, launch live Herdr/editor sessions, reload services, or run installers/upgrades. Any installation-dependent validation stays in the later milestone's explicit live checks.
- [ ] The formatting commit changes layout only: `bash bash/run-tests` passes before and after, and each script's parsed syntax tree (`shfmt --to-json`) is unchanged apart from positions. Because shfmt could misread Zsh in a way its own tree cannot show, each formatted Zsh file is also checked by Zsh itself, top-level code included: wrap the whole file in a temporary function with `eval` and print Zsh's canonical form of it with `functions`, before and after. Zsh only parses the code this way, so nothing in the file runs (a probe `mkdir` did not). Zsh keeps the original spacing inside `(( … ))` and `$( … )`, so there the comparison shrinks each run of whitespace, line continuations included, to a single space and drops it next to the brackets, but never removes the space between two words and never touches quoted text. shfmt also spaces arithmetic operators (`$((a+b))` becomes `$((a + b))`), so inside arithmetic the comparison spaces every operator the same way on both sides first. A trial on 2026-10-24 covered all 24 formatted Zsh files (21 `*.zsh` files, `zsh/.zshenv`, `zsh/aliases` and `zsh/update-plugins.sh`): raw output matched for 10, and the rest differed only inside `(( … ))` and `$( … )`. The user also reads the formatting diff of `zsh/.zshenv` and `zsh/aliases` and opens a new terminal before the commit. Afterwards every file in scope passes the formatting check, apart from the three Zsh exceptions. Every `.sh` or `.bash` file in scope has a shebang, and no file carries a `# shellcheck shell=` directive without one. The hook reports, without blocking, any tracked executable file without a shebang, so an extensionless helper left out by accident is visible.
- [ ] Clone reporting: a fixture commit adding a new clone passes, and the hook output names the clone by file and line range. A fixture's first commit, with no HEAD, passes and reports every clone. The full run on a fixture branch lists every clone new since its base. Neither run writes a file or blocks.
- [ ] `git blame` on a re-indented line shows the commit that wrote it, not the formatting commit. Lines shfmt split or joined may still show the formatting commit. Rerun this check on `master` after the merge. The ignore-revs test fails on a fixture listing a commit that is not an ancestor of HEAD.
- [ ] Effective scope, tool versions, formatting settings and the limits of complexity measurement are documented. Successful linting is not recorded as successful runtime acceptance.
- [ ] `bash bash/run-tests` completes with failures and skips reported accurately. Local hook activation and removal are demonstrated; GitHub checks and global hooks remain unchanged.

### Milestone 0.5: Repository baseline
Decisions: user decision, 2026-10-24. It covers the whole in-scope repository, not only the migration, so it is run as an audit under `AGENTS.md`: an `audit-<yyyy-mm>-baseline` branch dated when it starts (for example `audit-2026-11-baseline`), so it cannot collide with a regular monthly audit, one evidence-backed commit per finding and a `--no-ff` merge. The scope is Milestone 0's, so tmux files stay out.

Work:
- Run Milestone 0's checks and reports over the whole scope: clones, file size and complexity, pipelines and chains, line length, ShellCheck. Record the tool versions and configuration so the report can be repeated.
- Map which files are related and why: shared values, scripts that call each other, one feature spread over several configs. The map's form and location stay open until the groups are known.
- Judge every repeat and indicator, by the user or an LLM, before changing anything; nothing is merged automatically. Route each finding to a fix, `TODO.md` or `revisit.md`, rejected ones too, with the reason.
- Decide per group, from the report and with its pros and cons, whether a repeated value is worth a shared or generated file. Until then repeated values stay and live configs stay symlinks.
- Judge every existing clone: fix it, or accept it in `revisit.md` with its files, the function or a short quote of its first line, and the reason; it goes to `TODO.md` only when the user decides to defer the fix. Then decide, from what the audit found, whether clone reporting stays report-only or becomes blocking, and record the decision and its reason here.

Acceptance criteria:
- [ ] The report exists, can be rerun with the recorded versions and configuration, and covers extensionless scripts (a scan that misses them fails).
- [ ] Every clone and indicator in the report is judged and routed. Every clone that remains appears in `revisit.md` or `TODO.md` with its reason.
- [ ] The decision on whether clone reporting stays report-only or becomes blocking is recorded with its reason; a blocking design, if chosen, gets its own reviewed change.
- [ ] Live behavior is unchanged: no app config changed meaning without its own reviewed finding.

### Milestone 1: Base config live
Decisions: Steps 2–7 and the draft config.

Work:
- Add `herdr/config.toml` from the draft config, without the placeholder helper commands (C++ and copy-output). Each of those arrives with its own milestone.
- Add the `[app-name=Herdr]` `format` rule to `mako/config` (Step 3).
- Link `config.toml` as a single file in `install.sh`, not the whole directory, and add it to `bash/config-drift` and the explicit file list in `bash/config-drift.d/symlink-integrity.sh` (paths not listed there are skipped). Before linking, compare the independent live `~/.config/herdr/config.toml` with the tracked one and keep anything wanted from it.
- Run `wl-copy` under `setsid` in Vim's `\y` maps (`vim/config/mappings.vim`): `\y` in the `Prefix+e` editor is the daily copy path from Milestone 2, and a bare `wl-copy` can die with the editor.
- Update `docs/architecture/herdr.md` and the README keybinding references.

Acceptance criteria:
- [ ] `herdr config check` passes on the tracked file.
- [ ] `~/.config/herdr/config.toml` is a symlink into the checkout. A listing of `~/.config/herdr` before and after shows sockets, logs and session data untouched.
- [ ] `bash bash/config-drift` reports the Herdr mappings as clean.
- [ ] Pressed by hand in foot, each of these works: `Prefix+$`, `Prefix+|`, `Prefix+Alt+g`, `Alt+Shift+Left/Right` and direct `Alt+1..9`. A key that fails gets a different binding, recorded in Step 5.
- [ ] `Prefix+Shift+g` creates a worktree under `~/.local/share/herdr/worktrees`, not a folder literally named `~` (the config value starts with `~`).
- [ ] Every popup opens in the invoking pane's directory, as tmux's popups did: `Prefix+t` (scratch terminal) and `Prefix+Alt+g` (lazygit shows that pane's repository).
- [ ] `Ctrl+a Ctrl+a` reaches zsh as `Ctrl+a`, which jumps to the start of the line.
- [ ] `Mod+Alt+T` flips Herdr's sidebar and tab bar without a Herdr-specific signal from the script. If it doesn't, the clients-only `SIGWINCH` fallback from Step 4 is added and does.
- [ ] In both light and dark, Herdr's colors look right beside foot and Neovim. A decision on `panel_bg = "reset"` is recorded.
- [ ] `pane_gaps = false` and `true` compared by eye; the choice is recorded in Step 3.
- [ ] `makoctl reload` succeeds, and a Herdr notification shows 🐑 before its title.
- [ ] Copying with `y` in copy mode and with mouse selection is pasted with both `Ctrl+Shift+v` and middle-click. Where each copy lands (clipboard, primary) is recorded in Step 7.
- [ ] Text copied with `\y` in Vim still pastes after Vim has quit.
- [ ] A multi-line paste into zsh and into Neovim does not run anything by itself.
- [ ] `Shift+Enter` works in OpenCode, Claude Code and Codex. The image previews actually used still show, or the gap is recorded.
- [ ] Bare `Ctrl+h/j/k/l` moves between Neovim and Vim splits, and `Ctrl+l` clears the zsh screen.
- [ ] Vim and Neovim pick the right light/dark background inside Herdr.
- [ ] Sioyek inverse search reaches Neovim when its pane is the focused one, with several foot windows open (Step 3, `window_title`). The hidden-pane case is Milestone 5's.

### Milestone 2: Switch the launcher
Decisions: Step 9. Follow `niri/AGENTS.md`; reload with `niri msg action load-config-file`.

Work:
- Change `Mod+Return` in `niri/config.kdl` from `footclient tmux new-session -A -s main` to `footclient herdr`.
- Have `bash/herdr-cargo` link `~/.local/bin/herdr` to the binary where it actually installed it: it honours `CARGO_INSTALL_ROOT`, `CARGO_HOME` and `--root`, so the target is not always `~/.cargo/bin/herdr`. Check the link in `bash/config-drift`. Only zsh's `.zshenv` adds `~/.cargo/bin`; niri, foot's server, fuzzel and `environment.d` do not, so without the link `footclient herdr` opens a window that closes at once.
- Add `applications/herdr.desktop` running `footclient herdr` (linked by `install.sh`'s existing `applications/*.desktop` glob).
- Remove only the tmux-specific `--tmux center,80%` option from `zsh/functions/fzf.zsh`. Keep fzf installed and available: it runs inline with `--height 40%` in Herdr until Milestone 7, and in plain foot throughout. tmux comparison sessions also use inline fzf after this change.

Acceptance criteria:
- [ ] `herdr` resolves from foot's server environment, not just from zsh.
- [ ] `Mod+Return` opens foot attached to the default Herdr session. A second `Mod+Return` attaches another client to the same session.
- [ ] Herdr appears in fuzzel and opens the same default session.
- [ ] `Mod+T` (plain foot) and `Mod+Grave` (floating scratch terminal) behave as before.
- [ ] Detach (`Prefix+q`) and reattach keep running programs alive.
- [ ] `tmux` still starts by hand in plain foot, for comparison.
- [ ] fzf's history, file and directory widgets still work inline with `--height 40%` in Herdr, plain foot and a tmux comparison session.
- [ ] foot's `Ctrl+Shift+y` and `Ctrl+Alt+c` tested inside Herdr: run a command with known multi-line output, copy it, and compare the clipboard with the real command, directory and output. If they match, record that they work until Milestone 4. If not, record them as untrusted inside Herdr until Milestone 4 replaces them; they keep working in plain foot (`Mod+T`).

Until Milestone 3 lands, a full restart restores layout and directories; with `experimental.pane_history = true`, saved screen history may return only when the restored layout exactly matches the saved one. Herdr already tries to resume agents (`resume_agents_on_restore` is on from Milestone 1, unproven until Milestone 3); editors and other tools are not relaunched.

### Milestone 3: Restart recovery
Decisions: Step 2R.

Prove first:
- [ ] A relaunch mechanism that records, per persistent pane, which editor and project session or which tool (with its directory, Python environment and database) to start, and starts it after Herdr restores the layout. New pane IDs must not break it.
- [ ] Native resume works for OpenCode, Claude Code and Codex through their Herdr integrations with `resume_agents_on_restore = true`.
- [ ] A saving policy for Vim sessions, and for Neovim launches the current auto-tracking misses (`nvim file`, non-Git directories).

Acceptance criteria:
- [ ] Each case is tested separately: detach and reattach, full server restart, reboot.
- [ ] With several projects in one workspace, each project's editor reopens with its own `Session.vim`: files, splits and editor tabs.
- [ ] OpenCode, Claude Code and Codex each resume their own conversation. Two agent tabs on one project resume as two conversations.
- [ ] `ptpython`, `ptipython`, `htop`, `lazygit` and `duckdb` restart fresh in the right directory, Python environment and database file.
- [ ] Popups (scratch terminal, lazygit, pickers), the `Prefix+e` scrollback editor and Git commit editors do not come back and do not overwrite a project's `Session.vim`.
- [ ] With an unchanged layout, pane history returns. Returned screen text is not counted as a resumed program.
- [ ] The integration prerequisite for a rebuilt machine is documented in `docs/architecture/herdr.md`.

### Milestone 4: Copy last command output
Decisions: Step 7.

Prove first:
- [ ] Routing from a foot key binding to the right Herdr pane, with no race against focus changes.
- [ ] Command boundaries and matching command/directory metadata per shell, not the global `~/.local/state/zsh/last_command`.

Work: write `bash/herdr-copy-output`; add the `Prefix+Shift+y` and `Prefix+Alt+c` entries from the draft config; link and drift-map the helper.

Acceptance criteria:
- [ ] `Ctrl+Shift+y` (raw) and `Ctrl+Alt+c` (command + directory + output) work in plain foot and in Herdr. So do `Prefix+Shift+y` and `Prefix+Alt+c`, with `Prefix+Alt+c` pressed by hand in foot.
- [ ] The copy is complete with output longer than 500 lines, soft-wrapped lines, prompt-like output, two shells running at once, after a `cd` and after a focus change.
- [ ] When output was evicted or the boundaries are missing, the helper reports unavailable and the clipboard is unchanged.
- [ ] Inside a TUI (agent, Vim, Neovim), it reports unavailable.
- [ ] For each of OpenCode, Claude Code and Codex, `Prefix+e` shows useful retained text and `\y` copies the selected lines. The copy still pastes after the editor has closed.

### Milestone 5: Layouts and agent tabs
Decisions: Step 8C.

Work: write the `Prefix+W` and `Prefix+A` helpers, add their key entries, link and drift-map them, and settle initial sizes and focus.

Notes carried over from the removed `TODO.md` item 2 (full text, including Omarchy's `tdl`/`tds`/`tdlm`/`tsl` layout shapes: `git show 8af5af3:TODO.md`, a `master` commit). They were written for tmux; the principles apply to Herdr's pane CLI:
- Address every pane by the ID returned when it is created, starting from the invoking pane's own ID, never "the active pane". Focus can move while the script runs.
- Pass the directory explicitly on every split or new tab.
- Send command text literally, then Enter separately, so text such as `C-m` is not read as a key.
- Omarchy's `tdl` ends with `select-pane -t "$opencode_pane"`, a variable it never sets, so its final focus step silently does nothing. Don't copy it.

Acceptance criteria:
- [ ] `Prefix+W` offers editor + terminal and C++ `code` + `profile`, and builds the layout for the invoking pane's project.
- [ ] `Prefix+W` for a project whose editor is already open focuses that editor. There is no duplicate, and the layout is unchanged. The editor is found by project, not by tab or workspace name.
- [ ] `Prefix+A` offers OpenCode, Claude Code and Codex, and opens a new tab for the invoking pane's project. Existing agent tabs are untouched. AGY is left out on purpose (user decision, 2026-10-23).
- [ ] Both helpers handle a project path with spaces, a missing agent command (clear message, nothing half-built), a small terminal, being run twice in a row, and focus changing while they run. They run no command beyond the layout and the chosen agent.
- [ ] Both keys work correctly when two projects share a workspace.
- [ ] Investigated and decided: Sioyek inverse search when Neovim's pane is not focused. The handler (`nvim/lua/plugins/documents.lua`) only matches a foot window title containing "NVIM", which shows the focused pane, and after Milestone 2 two foot windows attached to the same session can both carry it (the handler takes the first match). Reaching a hidden editor, or the right one of two windows, needs the same find-the-project's-editor lookup as `Prefix+W`; fix it with that lookup, or record it as a known gap.
- [ ] No hooks, dashboards or coordination were added; those stay for the agentic-layer session.

### Milestone 6: C++ tools
Decisions: Step 8D. Behavior reference: `bash/tmux-cpp-tools`; the new helper name is provisional. Follow the implementation discipline above when choosing the new structure.

Prove first:
- [ ] A runner that starts tasks in the selected project's tabs without typing into a running TUI.
- [ ] Per-project editor lookup that replaces the global first-Neovim-pane lookup.

Acceptance criteria:
- [ ] `Prefix+C` opens the menu from any pane, including an editor or another TUI, and types nothing into it.
- [ ] Every existing action is present: configure; build, test, build+test; executable selection and arguments; source navigation from failures; GDB, Valgrind, clang-tidy, Google Benchmark, hyperfine, perf and samply; ccache statistics; project creation; clean. Clean-all keeps its guard.
- [ ] `Prefix+B` quick-builds with the same targeting.
- [ ] The build tab is reused when idle and keeps the previous output. When busy, the helper says so and focuses the tab, without interrupting, queueing or overlapping.
- [ ] Programs run in their own tabs, GDB in the debug tab, and profiling in the project's profile tab. Lifecycle matches the tmux version when compared side by side.
- [ ] The clean-all guard tests in `tests/test_tmux_cpp_tools.py` (no deleting through a symlinked build, no cache naming another tree) are ported to the new helper and pass.
- [ ] With two C++ projects in one workspace, every action and source jump hits the right project and editor, even when focus changes mid-task.

### Milestone 7: fzf temporary pane
Decisions: Step 9 (fzf).

Acceptance criteria:
- [ ] Inside Herdr, the history, file and directory widgets open fzf in a temporary split. The result reaches the original shell: history edits its command line, files are inserted there, and the directory changes there.
- [ ] Scripted fzf callers receive the selection and exit status. Cancelling is a cancel and does not reopen inline.
- [ ] The pane closes and focus returns after a selection, a cancel or an error, with no shell left behind.
- [ ] Concurrent pickers, paths with spaces or newlines, previews and keys behave as they do inline.
- [ ] If the pane cannot open, fzf falls back to inline and any partial pane is cleaned up.
- [ ] Plain foot keeps inline `--height 40%`.
- [ ] The picker pane does not come back after a restart.

### Milestone 8: Retire tmux
Decisions: Steps 6, 8A, 9.

Work:
- Remove `tmux/`, `bash/tmux-cpp-tools`, `tests/test_tmux_cpp_tools.py`, the tmux block in `bash/toggle-foot-theme.sh` (add nothing in its place, Step 4) and the TPM updater in `zsh/functions/sysup/plugins.zsh`. fzf's tmux-specific option was already removed at Milestone 2; fzf itself remains.
- Remove `vim-tmux-navigator` from Neovim (`nvim/lua/plugins/editor.lua`, as a submodule commit plus a parent pointer update) and from Vim (`vim/config/plugins.vim`), and add native `<C-h/j/k/l>` and `<C-\>` split maps (`nvim/lua/config/keymaps.lua` and Vim's mappings).
- Remove the tmux mappings from `install.sh`, `bash/config-drift` and its plugin scan, and `bash/config-drift.d/symlink-integrity.sh`, and the tmux path exclusions Milestone 0 added to the check scope and jscpd configuration. Update the README and `docs/architecture/`.
- Write a much more concise user-level version of `docs/herdr-migration.md` into `docs/architecture/herdr.md`: keys, behavior and the reasons that still matter.
- Remove only the tracked links and plugin clones from `~/.config/tmux`.

Acceptance criteria:
- [ ] A `tmux` grep over tracked files finds only intended mentions (history and notes).
- [ ] `Ctrl+h/j/k/l` and `Ctrl+\` still move between Neovim and Vim splits. `cd nvim && nvim --headless -c 'lua dofile("tests/runtime.lua")'` and `:checkhealth` pass.
- [ ] Personal files in `~/.config/tmux` remain.
- [ ] `docs/architecture/herdr.md` covers the keys, behavior and reasons in a short read, without implementation notes.
- [ ] `bash bash/config-drift` is clean, and the relevant suites pass under `bash bash/run-tests`.
- [ ] The sysup path for Zsh, Vim and Neovim plugin updates is unchanged (checked by reading the code and running `shellcheck`, not by running `sysup`).
- [ ] The tmux removal transaction is inspected first and removes only tmux. The user runs it.
