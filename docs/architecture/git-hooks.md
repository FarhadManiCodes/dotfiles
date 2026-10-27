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
every later `git commit`, prek's hook runs ours first, which still blocks a failing
commit, and then runs prek in the working tree even when ours failed. While prek runs
there, it saves unstaged edits to a patch file and writes the staged content back into
those live files. Until it restores the edits at the end, any program reading those
configuration files sees the staged version; if prek is killed, the edits are left only
in its patch file. `git-hooks/checks` refuses to run unless `CHECKS_SCOPE` and
`CHECKS_TMP` are set, which only the bootstrap does; never set them yourself. That
refusal comes only after prek has rewritten the files, so it does not make running prek
safe.
