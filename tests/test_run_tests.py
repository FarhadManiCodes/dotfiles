"""Run the real bash/run-tests against temporary checkouts holding fixture suites.

    python3 -B -m unittest discover -s tests

The repository's own suites are never invoked: each fixture checkout supplies its
own tests/ directory and a fake check-skills that records its invocation, so a
failure here is the runner's and cannot recurse into this file.
"""
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest


SOURCE = Path(__file__).resolve().parents[1] / "bash/run-tests"
ANSI = re.compile(r"\033\[[0-9;]*m")

PASSING = "import unittest\n\n\nclass Fixture(unittest.TestCase):\n    def test_ok(self):\n        pass\n"
FAILING = (
    "import unittest\n\n\nclass Fixture(unittest.TestCase):\n"
    "    def test_bad(self):\n        self.fail('deliberate fixture failure')\n"
)


class RunTestsTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="run-tests-test-")
        self.addCleanup(self.tmp.cleanup)
        self.base = Path(self.tmp.name)
        self.checkout = self.base / "dotfiles"
        (self.checkout / "bash").mkdir(parents=True)
        (self.checkout / "tests").mkdir()
        self.runner = self.checkout / "bash/run-tests"
        shutil.copy(SOURCE, self.runner)
        self.skills_log = self.base / "skills-ran"

    def fixture(self, unittest_body=PASSING, skills_exit=0):
        if unittest_body is not None:
            (self.checkout / "tests/test_fixture.py").write_text(unittest_body)
        fake = self.checkout / "bash/check-skills"
        fake.write_text(
            "#!/bin/bash\n"
            'printf "ran\\n" >> "$SKILLS_LOG"\n'
            f"exit {skills_exit}\n"
        )
        fake.chmod(0o755)

    def run_runner(self, command=None, cwd=None):
        result = subprocess.run(
            [str(command or self.runner)],
            cwd=str(cwd or self.base), capture_output=True, text=True, timeout=120,
            env=dict(os.environ, SKILLS_LOG=str(self.skills_log)),
        )
        return result.returncode, ANSI.sub("", result.stdout)

    def summary(self, stdout):
        lines = stdout.split("== summary ==\n", 1)[1].strip().splitlines()
        return [line.strip() for line in lines]

    def test_all_suites_passing_exits_zero(self):
        self.fixture()
        code, out = self.run_runner()
        self.assertEqual(code, 0)
        self.assertEqual(self.summary(out), ["pass  unittest", "pass  skills"])

    def test_failing_suite_does_not_stop_later_suites(self):
        self.fixture(unittest_body=FAILING)
        code, out = self.run_runner()
        self.assertEqual(code, 1)
        self.assertEqual(self.summary(out), ["FAIL  unittest", "pass  skills"])
        self.assertTrue(self.skills_log.exists(), "later suite did not run after a failure")

    def test_failing_later_suite_fails_the_run(self):
        self.fixture(skills_exit=1)
        code, out = self.run_runner()
        self.assertEqual(code, 1)
        self.assertEqual(self.summary(out), ["pass  unittest", "FAIL  skills"])

    def test_missing_suite_is_not_a_pass(self):
        self.fixture()
        (self.checkout / "bash/check-skills").unlink()
        shutil.rmtree(self.checkout / "tests")
        code, out = self.run_runner()
        self.assertEqual(code, 1)
        self.assertEqual(self.summary(out), ["FAIL  unittest", "FAIL  skills"])

    def test_runs_through_an_installed_symlink_from_outside_the_checkout(self):
        self.fixture()
        bindir = self.base / "bin"
        bindir.mkdir()
        link = bindir / "run-tests"
        link.symlink_to(self.runner)
        code, out = self.run_runner(command=link, cwd=Path("/"))
        self.assertEqual(code, 0)
        self.assertEqual(self.summary(out), ["pass  unittest", "pass  skills"])


if __name__ == "__main__":
    unittest.main()
