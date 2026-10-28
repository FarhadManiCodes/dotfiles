"""Check that .git-blame-ignore-revs lists only commits reachable from HEAD.

    python3 -B -m unittest discover -s tests

A rebase or squash gives the formatting commits new IDs, and the listed ones
then stop matching anything; this fails before such a branch is merged. Git
reads the file through blame.ignoreRevsFile and rejects an abbreviated ID.
"""

import os
from pathlib import Path
import re
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
FULL_ID = re.compile(r"[0-9a-f]{40}")


def git_env():
    """The environment without what could point git at another repository."""
    env = {k: v for k, v in os.environ.items() if not k.startswith("GIT_")}
    env.update(GIT_CONFIG_GLOBAL=os.devnull, GIT_CONFIG_NOSYSTEM="1")
    return env


def git(repo, *args):
    return subprocess.run(
        ["git", *args],
        cwd=repo,
        env=git_env(),
        capture_output=True,
        text=True,
        check=False,
    )


def entries(text):
    """The IDs in an ignore-revs file: every line but blanks and comments.

    Lines are split and trimmed as git does it; Python's splitlines() and
    strip() also take a form feed or non-breaking space, which git rejects.
    """
    lines = (line.strip(" \t\r") for line in text.split("\n"))
    return [line for line in lines if line and not line.startswith("#")]


def problems(repo, ids):
    """Why each ID would not work as an ignore-revs entry in repo."""
    found = []
    for rev in ids:
        if not FULL_ID.fullmatch(rev):
            found.append(f"{rev}: not a full commit ID")
        elif git(repo, "cat-file", "-e", f"{rev}^{{commit}}").returncode:
            found.append(f"{rev}: not a commit")
        elif git(repo, "merge-base", "--is-ancestor", rev, "HEAD").returncode:
            found.append(f"{rev}: not an ancestor of HEAD")
    return found


class RepositoryFile(unittest.TestCase):
    def test_every_entry_is_a_full_id_of_an_ancestor_of_head(self):
        ids = entries((ROOT / ".git-blame-ignore-revs").read_text())
        self.assertTrue(ids, "the file lists no commits")
        self.assertEqual(problems(ROOT, ids), [])


class Fixture(unittest.TestCase):
    """The check itself, in a disposable repository."""

    def setUp(self):
        tmp = tempfile.TemporaryDirectory(prefix="blame-ignore-revs-test-")
        self.addCleanup(tmp.cleanup)
        self.repo = Path(tmp.name)
        self.git("init", "-q", "-b", "master")
        self.git("config", "user.name", "Test")
        self.git("config", "user.email", "test@example.com")

    def git(self, *args):
        proc = git(self.repo, *args)
        self.assertEqual(proc.returncode, 0, proc.stderr)
        return proc.stdout.strip()

    def commit(self, message):
        self.git("commit", "-q", "--allow-empty", "-m", message)
        return self.git("rev-parse", "HEAD")

    def test_reports_each_entry_that_would_not_work(self):
        ancestor = self.commit("on master")
        self.git("switch", "-q", "-c", "side")
        side = self.commit("on side only")
        self.git("switch", "-q", "master")
        self.commit("master moves on")
        tree = self.git("rev-parse", "HEAD^{tree}")
        self.assertEqual(
            problems(self.repo, [ancestor, side, tree, ancestor[:7]]),
            [
                f"{side}: not an ancestor of HEAD",
                f"{tree}: not a commit",
                f"{ancestor[:7]}: not a full commit ID",
            ],
        )

    def test_splits_and_trims_lines_as_git_does(self):
        rev = self.commit("on master")
        text = f"# comment\n\n\t{rev} \r\n  # indented comment\n{rev}\u00a0\n"
        self.assertEqual(
            problems(self.repo, entries(text)),
            [f"{rev}\u00a0: not a full commit ID"],
        )


if __name__ == "__main__":
    unittest.main()
