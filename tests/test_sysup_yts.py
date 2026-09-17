"""Exercise the yts install step against a fixture checkout and a stubbed make.

    python3 -B -m unittest discover -s tests -v

Nothing real is touched. That matters more here than for most steps: the real
`make install` runs `uv venv --clear`, so a test pointed at the live prefix
would wipe the working app. Both directories are arguments for that reason.
"""
import os
from pathlib import Path
import shutil
import subprocess
import unittest
import tempfile


SOURCE = Path(__file__).resolve().parents[1] / "zsh/functions/sysup.zsh"
GIT = shutil.which("git")


class YtsInstallTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="sysup-yts-test-")
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.repo = self.root / "checkout with spaces"
        self.prefix = self.root / "installed"
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.log = self.root / "calls"
        self.env = dict(
            os.environ, PATH=f"{self.bin}:/usr/bin:/bin",
            YTS_LOG=str(self.log), YTS_PREFIX=str(self.prefix), YTS_FAIL="",
            GIT_CONFIG_NOSYSTEM="1", GIT_CONFIG_GLOBAL="/dev/null",
        )

        # A checkout with one commit.
        self.write(self.repo / "yts/__init__.py", "")
        self.write(self.repo / ".gitignore", "__pycache__/\nvenv/\n")
        self.git("init", "--quiet")
        self.git("add", ".")
        self.git("commit", "--quiet", "-m", "Fixture")
        self.head = self.rev_parse()

        # An install whose stamp is behind HEAD, so the default case updates.
        self.prefix.mkdir()
        (self.prefix / ".installed-commit").write_text("0" * 40 + "\n")
        self.script(self.prefix / "venv/bin/python", '''
printf 'python %s\\n' "$*" >> "$YTS_LOG"
[ "$YTS_FAIL" = import ] && exit 1
exit 0
''')

        # make -C <repo> <target>; install writes the stamp like yts's Makefile.
        self.script(self.bin / "make", '''
printf 'make %s\\n' "$3" >> "$YTS_LOG"
case "$3" in
  test)
    [ "$YTS_FAIL" = test ] && exit 1 ;;
  install)
    [ "$YTS_FAIL" = install ] && exit 1
    git -C "$2" rev-parse HEAD > "$YTS_PREFIX/.installed-commit" ;;
esac
exit 0
''')

    def write(self, path, content):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content)

    def script(self, path, body):
        self.write(path, "#!/bin/sh\n" + body)
        path.chmod(0o755)

    def git(self, *args):
        subprocess.run(
            [GIT, "-C", str(self.repo), "-c", "core.hooksPath=/dev/null",
             "-c", "user.name=Fixture", "-c", "user.email=fixture@example.invalid",
             *args], env=self.env, capture_output=True, check=True,
        )

    def rev_parse(self):
        out = subprocess.run([GIT, "-C", str(self.repo), "rev-parse", "HEAD"],
                             env=self.env, capture_output=True, text=True, check=True)
        return out.stdout.strip()

    def run_step(self):
        return subprocess.run(
            ["zsh", "-f", "-c", 'source "$1"; _sysup_yts "$2" "$3"',
             "test", str(SOURCE), str(self.repo), str(self.prefix)],
            env=self.env, capture_output=True, text=True, timeout=30,
        )

    def calls(self):
        return self.log.read_text() if self.log.exists() else ""

    def stamp(self):
        path = self.prefix / ".installed-commit"
        return path.read_text().strip() if path.exists() else ""

    # --- the ordinary paths ---------------------------------------------------

    def test_stale_install_is_rebuilt_and_verified(self):
        result = self.run_step()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn(f"Installed {self.head[:7]}", result.stdout)
        # Tests gate the install, so they must run first.
        self.assertEqual(self.calls().splitlines()[:2], ["make test", "make install"])
        # And the import check must actually be exercised.
        self.assertIn("python -c", self.calls())
        self.assertEqual(self.stamp(), self.head)

    def test_matching_commit_does_no_work(self):
        (self.prefix / ".installed-commit").write_text(self.head + "\n")
        result = self.run_step()
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertIn(f"already installed at {self.head[:7]}", result.stdout)
        self.assertEqual(self.calls(), "")

    def test_absent_checkout_and_absent_install_are_skipped(self):
        shutil.rmtree(self.repo)
        result = self.run_step()
        self.assertEqual(result.returncode, 0)
        self.assertIn("no checkout", result.stdout)
        self.assertEqual(self.calls(), "")

        self.setUp()
        shutil.rmtree(self.prefix)
        result = self.run_step()
        self.assertEqual(result.returncode, 0)
        self.assertIn("not installed", result.stdout)
        self.assertEqual(self.calls(), "")

    def test_missing_stamp_reads_as_unknown_and_installs(self):
        (self.prefix / ".installed-commit").unlink()
        result = self.run_step()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("Installing unknown ->", result.stdout)
        self.assertEqual(self.stamp(), self.head)

    # --- the refusals, which are the point -----------------------------------

    def test_modified_file_prevents_install(self):
        (self.repo / "yts/__init__.py").write_text("# half-finished edit\n")
        result = self.run_step()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("uncommitted changes", result.stdout)
        self.assertEqual(self.calls(), "")

    def test_untracked_file_prevents_install(self):
        # `uv pip install .` packages the worktree, so an untracked new module
        # ships exactly like a modified one. --untracked-files=no would miss it
        # and the stamp would then claim HEAD was installed.
        (self.repo / "yts/newmodule.py").write_text("x = 1\n")
        result = self.run_step()
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertIn("uncommitted changes", result.stdout)
        self.assertEqual(self.calls(), "")
        self.assertNotEqual(self.stamp(), self.head)

    def test_gitignored_litter_does_not_prevent_install(self):
        # The stricter check must not trip on ordinary development litter.
        (self.repo / "yts/__pycache__").mkdir()
        (self.repo / "yts/__pycache__/x.pyc").write_text("")
        result = self.run_step()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn(f"Installed {self.head[:7]}", result.stdout)

    def test_failing_tests_keep_the_installed_build(self):
        self.env["YTS_FAIL"] = "test"
        result = self.run_step()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("tests fail", result.stdout)
        self.assertIn("make test", self.calls())
        self.assertNotIn("make install", self.calls())
        self.assertNotEqual(self.stamp(), self.head)

    def test_failed_install_is_reported(self):
        self.env["YTS_FAIL"] = "install"
        result = self.run_step()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("make install failed", result.stdout)

    def test_build_that_does_not_import_is_reported(self):
        # pip reporting success is not evidence the launcher works.
        self.env["YTS_FAIL"] = "import"
        result = self.run_step()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("does not import", result.stdout)


if __name__ == "__main__":
    unittest.main()
