# Git hooks

This repository's commit checks: how they run, how to set them up and what they cover.
The checks live in `git-hooks/` and `.pre-commit-config.yaml`; Git hooks, installed by
hand in a checkout, run them.

## How it runs

Once installed in a checkout (see "Setup in a fresh clone"), two Git hooks check what
Git is about to record:

- `.git/hooks/pre-commit` runs on every `git commit` that tries to record a commit (not
  `--dry-run`) and is not given `--no-verify`, including one that then finds nothing to
  commit. It also runs when a stopped merge, cherry-pick or revert is finished with
  `git commit` or `--continue`, and for a `git commit` run while a rebase is stopped;
  `git rebase --continue` on its own runs no hook.
- `.git/hooks/pre-merge-commit` runs when `git merge`, or `git pull` in merge mode,
  creates a merge commit in one step: no conflicts, and no `--no-commit`, `--squash` or
  `--no-verify`. A merge that stops is finished with `git commit`, or with
  `git merge --continue` unless it was a `--squash`; only `pre-commit` runs for it.

Other commands that make commits, among them rebase replays, `cherry-pick`, `revert`,
`git am` and `git stash`, mostly run neither hook, and which ones do depends on the
command and the Git version (a rebase `reword` runs `pre-commit`). So count a commit
made any other way as unchecked, though it may have been checked. Whether a later commit
checks the files these commits brought in is under "Scope". A fast-forward creates no
commit.

Each installed hook is a copy, made by hand, of the tracked file `git-hooks/hook` (the
stub); after a change to the stub, copy it to both again.

Each installed hook runs these steps:

1. If the working tree has `git-hooks/bootstrap`, the hook runs it. If that file is in
   none of the working tree, the index and HEAD, as on a branch older than these checks,
   the hook prints a note and lets the commit or merge through. In the remaining cases
   the hook fails; see "Removal".
2. The bootstrap makes a new temporary directory, the snapshot, under
   `$XDG_RUNTIME_DIR`. It clones the repository into a subdirectory of it
   (`git clone --shared --no-checkout`), copies in the index file Git is about to
   commit, and writes that index's files out with `git checkout-index`. The snapshot is
   deleted when the run ends, also after a failure or an INT, TERM or HUP signal
   (Ctrl-C sends INT). A run killed another way, such as with SIGKILL, can leave a
   `herdr-hook.*` directory behind; `$XDG_RUNTIME_DIR` is a tmpfs, removed at reboot
   and when your last login session ends.
3. The bootstrap runs the snapshot's own `git-hooks/checks`, which runs prek in the
   snapshot with the snapshot's `.pre-commit-config.yaml`. Each item under `hooks:` in
   that file is one check; its `entry:` command is `bash git-hooks/checks <name>`, where
   `<name>` is the item's `id`. prek's exit status becomes the Git hook's: if any check
   exits non-zero, report-only ones included, Git records nothing. Which checks run
   when, and when each exits non-zero, is under "Blocking and report-only".

The checks look at the files Git will record: no unstaged edits, no untracked or
ignored files, and with `git commit <path>` no staged changes outside those paths.
Symlinks and the contents of submodules are not checked (see "Scope"). The checks read
those files, and `git-hooks/checks`, `git-hooks/report.py`, `.pre-commit-config.yaml`,
`.shellcheckrc`, `ruff.toml`, `.editorconfig`, and `.gitattributes` if one is added,
from the snapshot, never from the working tree, which in `~/dotfiles` is the live
configuration. So each check and settings file is the version the commit records: the
commit's own version if it changes that file, otherwise HEAD's, never the working
tree's. The tools themselves are whichever versions are found on the `PATH` of the
program that runs Git.

Two pieces of this repository's code run outside the snapshot: the installed hook and
the working tree's `git-hooks/bootstrap`, which builds the snapshot. So the bootstrap
refuses to run, and Git records nothing, if the working tree's `git-hooks/bootstrap`
differs from the version the commit will record: the index's, or for
`git commit <path>` and `--only`, HEAD's unless the bootstrap is one of the paths. To
include the edit in a plain commit, `git add` it or use `git commit -a`; for
`git commit <path>` or `--only`, name the bootstrap among the paths; if the edit is
already staged, `--include` also works. If the edit is not wanted, staged or not, undo
it with `git restore --staged --worktree git-hooks/bootstrap`. Any failed
`pre-merge-commit` leaves the merge in progress; for this one, run `git merge --abort`,
commit the bootstrap, then merge again.

In a clone of this repository, the only prek commands to run yourself are
`prek --version`, `prek list` and `prek validate-config .pre-commit-config.yaml`, which
leave the working tree, the index and Git hooks alone (`prek list` and
`validate-config` may create prek's cache, `~/.cache/prek`). Any other prek command,
or the Python `pre-commit` tool, may run checks in the working tree or install hooks;
prek takes an unknown first word, such as a mistyped command, as the name of a check
to run. The checks run only through `git-hooks/bootstrap` (see "Manual runs"), whose
`git-hooks/checks` runs prek inside the snapshot. `prek install` replaces
`.git/hooks/pre-commit` with prek's own hook and keeps ours as `pre-commit.legacy`; on
every later `git commit`, prek's hook runs ours first, which then fails every commit,
clean or not, because the bootstrap does not know the mode `pre-commit.legacy`, and then
runs prek in the working tree even so. While prek runs there, it saves unstaged edits to
a patch file and writes the staged content back into those live files. Until it restores
the edits at the end, any program reading those configuration files sees the staged
version; if prek is killed, the edits are left only in its patch file.
`git-hooks/checks` refuses to run unless `CHECKS_SCOPE` and `CHECKS_TMP` are set, which
only the bootstrap does; never set them yourself. That refusal comes only after prek has
rewritten the files, so it does not make running prek safe.

## Setup in a fresh clone

A clone gets neither the hooks nor the blame setting; Git copies neither. In the new
checkout, from its top directory:

```sh
install -m 0755 git-hooks/hook .git/hooks/pre-commit
install -m 0755 git-hooks/hook .git/hooks/pre-merge-commit
git config blame.ignoreRevsFile ':(optional).git-blame-ignore-revs'
```

**The hooks** are copies, not symlinks, so they still run on a branch that has no
`git-hooks/` (see "How it runs", step 1). After a change to `git-hooks/hook`, run the
two `install` lines again; until then the bootstrap prints a warning at every commit,
without blocking it. Git ignores `.git/hooks` when `core.hooksPath` is set;
`git config --get core.hooksPath` must print nothing.

**The blame setting** makes `git blame` skip the commits listed in
`.git-blame-ignore-revs`, which only change layout (one exception is noted under "The
blame list"), so each line usually shows the commit that last changed what it does.
`:(optional)` lets blame work where that file is missing, such as on a branch older than
it; without it, every blame there fails.
`git blame --ignore-revs-file=` (empty) turns the list off for one run;
`git -c blame.ignoreRevsFile=` does not.

**Tools.** Every commit needs `prek`, `shellcheck`, `shfmt`, `ruff`, `jscpd`,
`python3`, `zsh`, `bash` and `git` on the `PATH`; a missing one stops the commit and
names it. `prek` and `jscpd` are Cargo installs in `~/.cargo/bin`, `shellcheck` comes
from the AUR package `shellcheck-bin`, and the rest are Arch packages. Here only
`zsh/.zshenv` puts `~/.cargo/bin` on the `PATH`: Git run from a Zsh shell finds them,
but a program that niri or a systemd user service starts directly does not have it, and
a commit made from such a program fails the same way. The full run also needs
`unshare`, `ip`, `curl`, `llama-server` and the model file
`~/.cache/llama.cpp/jina-code-embeddings-0.5b-F16.gguf` (under `$XDG_CACHE_HOME` when
that is set). No version is pinned: the checks use whatever is installed.

**The snapshot directory.** `$XDG_RUNTIME_DIR` must be set and exist; without it the
bootstrap stops rather than build the snapshot somewhere else, such as inside the
checkout.

**Other refusals.** The bootstrap also stops, with a message, when the index is split
(`git update-index --split-index`), when it has skip-worktree entries (as a sparse
checkout makes), when the repository is shallow (`git clone --depth`; run
`git fetch --unshallow`), when the commit makes `git-hooks/checks`, `report.py` or a
settings file a symlink, which would run or read a file outside the snapshot, or when
`git-hooks/bootstrap` is not tracked yet ("add it first"). None of these is used here.

## Scope

**Which files.** The checks look at tracked regular files. Every check but whitespace
skips symlinks; the whitespace check reads a symlink's target path as its content, so a
target ending in a space fails it. The contents of the submodules (`nvim`,
`notifiers`) are never checked. The tmux files
(`tmux/`, `bash/tmux-cpp-tools`, `tests/test_tmux_cpp_tools.py`) are left out, because
tmux retires at Herdr Milestone 8.

**Which of them a commit checks.** A commit checks each file it adds or changes compared
with HEAD, the whole file and not only the changed lines; whitespace is the exception,
checked only on the lines the commit adds. So:

- `git commit --amend` checks what the amend changes compared with the commit it
  replaces;
- a merge checks every file it brings in, compared with the branch merged into;
- the first commit in a repository, with no HEAD, checks every file.

A commit that changes `.pre-commit-config.yaml`, anything under `git-hooks/`, or a
settings file the tools read at any depth (`.editorconfig`, `.gitattributes`,
`.shellcheckrc` or `shellcheckrc`, `ruff.toml`, `.ruff.toml` or `pyproject.toml`) checks
every file instead, and every line for whitespace, so a new rule fails that commit
rather than a later, unrelated one. The full run (see "Manual runs") checks every file
too. The clone report works the other way: at every commit it scans every shell file and
every Python file outside `tests/`, and reports only the clones that are new compared
with HEAD (see "Blocking and report-only").

A file brought in by a commit that ran no hook (see "How it runs") is checked again only
when a later commit changes it, when a commit changes one of the rule files above, or
by the full run; whitespace on its unchanged lines only by the last two.

**Which check reads which file.** Every file in scope gets the whitespace check. The
language checks choose files by dialect:

- Zsh: by path (files ending in `.zsh`, `zsh/.zshenv`, `zsh/.zshrc`, `zsh/aliases`) or
  by a `zsh` shebang.
- Python: files ending in `.py`, or a `python`, `python3` or `python3.<n>` shebang.
  ruff checks the files under `tests/` like any other; the clone and size reports leave
  them out, and only the full run's broad clone scan adds them.
- Bash and sh: by shebang only: `bash`, `sh` or `dash`, named directly or through `env`
  (also `env -S`).

A file ending in `.sh` or `.bash` that no dialect claims fails the shell check. An
executable that no dialect claims, without a shebang or with an interpreter or `env`
option no check reads, is not checked; the report-only indicators check names it when
the file is in the commit's scope, as above.
"Exceptions" covers the files the checks read but do not format, and what no check
covers.

## Exceptions

**Zsh has no linter.** ShellCheck refuses Zsh, and no maintained Zsh linter is
packaged, so Zsh files get only `zsh -n` (syntax) and shfmt's formatting check.

**Three Zsh files are not formatted.** shfmt cannot parse Zsh's `{ … } always { … }`
block, which `zsh/functions/sysup.zsh` and `zsh/functions/sysup/tool-tests.zsh` use
correctly and keep; `zsh/.zshrc` changes rarely and is reviewed by hand. shfmt's
formatting check skips all three; they keep `zsh -n` and the other checks. The
long-chains report cannot measure the two shfmt cannot parse and lists them as not
measured.

**A new Zsh startup file must be added by path.** Zsh is chosen by path because
`zsh/.zshenv` and `zsh/aliases` have no shebang. A new startup file without one, such
as `zsh/.zprofile`, is not checked until it is added to the path list in `dialect()` in
`git-hooks/checks`; if shfmt does not recognise its name as Zsh, it also needs a
`shell_variant = zsh` section in `.editorconfig`, as `zsh/aliases` has.

**sh files get Bash's syntax check.** `sh -n` runs `/bin/sh`, which here is Bash, so it
parses them as Bash would; ShellCheck checks them as POSIX sh.

## Blocking and report-only

Each item under `hooks:` in `.pre-commit-config.yaml` is one check. A blocking check
stops the commit or merge when it finds something; a report-only check prints what it
finds and lets the commit through. A report-only check's `name:` ends in "(report
only)" and it sets `verbose: true`, so prek prints its output even when it passes; a
blocking check's output appears only when it fails.

**Blocking, at every commit and in the full run:**

- `whitespace`: Git's default whitespace rule, whatever your configuration sets:
  trailing whitespace, a space before a tab in indentation, blank lines at the end of a
  file, and leftover conflict markers.
- `shell`: `bash -n`, `sh -n` and `zsh -n`; ShellCheck with `.shellcheckrc` on Bash and
  sh; `shfmt -d` on all three dialects except the files under "Exceptions"; and a file
  ending in `.sh` or `.bash` that no dialect claims.
- `python`: `ruff check` and `ruff format --check`, both with `ruff.toml`.

**Report-only, at every commit and in the full run:**

- `masked-returns`: ShellCheck's `check-extra-masked-returns` on Bash and sh, commands
  whose failure goes unnoticed. It stays report-only until Milestone 0.5 has fixed or
  suppressed each finding; then it joins `.shellcheckrc` and blocks.
- `clones`: jscpd's token clones among the shell files and the Python outside `tests/`
  that are new compared with the base: HEAD at a commit, the given base in the full
  run. With no HEAD, as at a first commit, it reports every clone. Clones are judged at
  milestone review, and each verdict goes in `docs/clone-verdicts.md`.
- `indicators`: pipelines and `&&`/`||` chains longer than 3 in shell, lines over 80
  columns in shell and Python, and executables no check reads (see "Scope").

**Report-only, in the full run only:**

- `clones-broad`: candidates for judgment. A stricter token scan that also finds renamed
  copies and includes the tests, and two Python-only detectors on the Python outside
  `tests/`: near-copies by syntax tree, and functions that do the same thing written
  differently.
- `measure`: for each production file that changed since the base commit, its size and
  jscpd's file-level complexity estimate, before and after.

**When a report-only check still fails.** It exits non-zero, which stops the commit or
the full run, when its result could not be trusted:

- any check: a tool it needs is missing;
- `masked-returns`: ShellCheck could not check a file;
- `clones` and `clones-broad`: the scan would be wrong, because jscpd fails or writes no
  report, leaves out a file big enough to hold a clone, a file name contains `,` or `;`,
  or a shell file and a Python file share a name; `clones-broad` also when the model
  file is missing or the embeddings server does not answer;
- `measure`: jscpd fails.

So a Bash script named `a,b.sh` (with a `#!/bin/bash` shebang) stops every commit
through the report-only `clones` check until it is renamed, because that check scans
every file at every commit.

A failed `pre-merge-commit` leaves the merge in progress: fix the cause and finish it
with `git commit`, or run `git merge --abort`.

## Manual runs

Both commands build a snapshot as the hooks do, and work from anywhere in the checkout
given the path to the bootstrap. They are the only way to run the checks by hand: never
use prek to run them ("How it runs" lists the read-only prek commands that are safe).

- `bash git-hooks/bootstrap run` checks what is staged now, as a plain `git commit`
  would: the same checks, compared with HEAD, without committing. `git commit -a` and
  `git commit <path>` commit different content, so stage that content first to check
  it. Like a plain commit, it stops while the working tree's `git-hooks/bootstrap`
  differs from the staged copy.
- `bash git-hooks/bootstrap full <base>` checks HEAD's tree, not what is staged or
  edited: every check, the two full-run-only ones included, over every file in scope
  (see "Scope"). `<base>` is a commit: the clone reports show clones new since it, and
  `measure` compares sizes with it. It needs a HEAD commit and stops while the working
  tree's `git-hooks/bootstrap` differs from HEAD's. It also needs the extra tools and
  the model file listed under "Setup in a fresh clone", and starts a local embeddings
  server for the semantic clone scan.

Herdr's plan runs the full run before each milestone review, with the commit the
milestone branch started from:

```sh
bash git-hooks/bootstrap full "$(git merge-base master HEAD)"
```

**Tool versions.** Before its checks, the full run prints the versions of prek, shfmt,
ShellCheck, ruff, jscpd, llama-server, Python, Zsh, Bash and Git, and the base commit.
It does not print those of `sh`, `unshare`, `ip` or `curl`, or say which model file it
used. Nothing saves these lines: copy them wherever a run must be repeatable, such as a
milestone review's notes. A commit and `bootstrap run` print no versions.

**The checks' own tests.** `tests/test_git_hooks.py` and
`tests/test_blame_ignore_revs.py` test the checks and the blame list;
`bash bash/run-tests` runs them with the other suites.

## After a tool upgrade

The checks use whatever versions are installed (see "Setup in a fresh clone") and
nothing holds a tool back, so an upgrade can make tracked code fail a check it passed
before. It shows when a commit changes that code, when one changes the rule files (see
"Scope"), or in the full run. Then:

- Correct the code in the next commit, ahead of other work.
- A correction may reformat the files the upgrade made fail, although `AGENTS.md`
  otherwise rules out reformatting unrelated files (user decision, 2026-10-27).
- One that reformats many files is a commit of its own, holding only the reformat, and
  is listed in the blame list (see below).

To see which versions changed, compare the full run's version lines with those saved in
the last milestone review's notes. It does not print `sh`, `unshare`, `ip` or `curl`, so
check their packages with `pacman -Q bash util-linux iproute2 curl`.

## The blame list

`.git-blame-ignore-revs` lists commits that only change layout, such as a reformat,
apart from one line of the plan that Milestone 0's comment move also rewrote, as its
comment there says. `git blame` skips them, through the setting under "Setup in a
fresh clone", and shows for each of their lines the earlier commit that last changed
it; a line the commit split or joined may still show it.
`tests/test_blame_ignore_revs.py` enforces two rules:

- Each ID is a full, lowercase, 40-character commit ID with nothing after it on its
  line but whitespace, which the whitespace check rejects anyway. Git rejects an
  abbreviated ID, and every blame then fails; it accepts uppercase or a comment after
  an ID, but the test does not. By convention each entry's comment goes on the line
  above it.
- Each ID is an ancestor of HEAD.

To add one:

1. Commit the reformat on its own.
2. In the next commit on the same branch, add its ID (`git rev-parse HEAD`, run straight
   after the reformat commit). A commit cannot list itself: its ID exists only once it
   is made.
3. Never squash or rebase that branch: either gives the reformat a new ID, and the
   listed one then matches nothing, which the ancestor test catches. Herdr's milestone
   branches land with `--no-ff` merges for this reason.

## Removal

To stop the checks in one checkout, delete its two hooks; nothing else runs them:

```sh
rm .git/hooks/pre-commit .git/hooks/pre-merge-commit
```

To remove the checks from the repository, first delete the hooks in every checkout that
has them, then commit the removal. While the hooks are installed they refuse a commit
that removes `git-hooks/bootstrap`, so the checks cannot be removed by a commit they
check. The hook fails when:

- the commit removes `git-hooks/bootstrap` while HEAD has it ("delete
  .git/hooks/pre-commit and pre-merge-commit first");
- `git-hooks/bootstrap` is deleted from the working tree but still staged, which to the
  hook is an unstaged edit ("restore it with git restore git-hooks/bootstrap").

The removal commit takes `git-hooks/`, `.pre-commit-config.yaml`,
`tests/test_git_hooks.py` and this file, and rewords or drops every other mention of
them, which `git grep -n -e git-hooks -e pre-commit-config` lists. Editors also read
`.editorconfig`, `.shellcheckrc` and `ruff.toml`, so decide on those separately.
`.git-blame-ignore-revs` and its test can stay, since blame still uses them; move
"The blame list" and the blame setting from this file to `git.md` first.

## Measurement limits

- Python functions: ruff blocks one above a McCabe complexity of 8 (`C901`), or with
  more than 6 return statements, 12 branches, 5 arguments or 50 statements (pylint's
  limits, through ruff). Such a function is split, or its line says why it is not.
- Shell functions: no per-function limit. No analyzer that understands Bash and Zsh has
  been validated, so none is claimed. The `indicators` report stands in: pipelines and
  `&&`/`||` chains longer than 3, where 4 is acceptable after review. Python gets no
  chain count, since shfmt cannot read it.
- Line length: Python blocks above 120 columns (ruff's `E501`) and is reported above 80;
  shell is only reported above 80. Columns are counted as characters, so a tab or a wide
  character counts as one.
- File size and complexity: `measure`, in the full run only, reports each changed
  production file's lines, bytes and jscpd's complexity estimate, before and after; an
  empty file or one over 1 MB shows "not measured", and a file missing at one end "not
  in scope". The estimate is for the whole file, not each function: an indicator for
  review, not a limit.
- Clones: the planned scan keeps jscpd's defaults (mild mode, 50 tokens, 5 lines), and
  the broad scan in the full run goes down to 30 tokens with the same 5 lines. Neither
  reports a clone from a file below its minimums; the report names most such files,
  with their size.
