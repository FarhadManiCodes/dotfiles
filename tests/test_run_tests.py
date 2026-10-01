"""Run the real bash/run-tests against temporary checkouts holding fixture suites.

    python3 -B -m unittest discover -s tests

The repository's own suites are never invoked: each fixture checkout supplies its
own tests/ directory, a fake check-skills that records its invocation and a fake
notifiers submodule whose Makefile check targets just exit, so a failure here is
the runner's and cannot recurse into this file.
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
SUBMODULES = ("mic-notify", "net-notify", "power-notify")  # suites from the notifiers submodule
ALL_PASS = ["pass  unittest", "pass  skills"] + [f"pass  {s}" for s in SUBMODULES]
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

    def fixture(self, unittest_body=PASSING, skills_exit=0, submodule_exit=0, net_exit=None):
        if unittest_body is not None:
            (self.checkout / "tests/test_fixture.py").write_text(unittest_body)
        fake = self.checkout / "bash/check-skills"
        fake.write_text(
            "#!/bin/bash\n"
            'printf "ran\\n" >> "$SKILLS_LOG"\n'
            f"exit {skills_exit}\n"
        )
        fake.chmod(0o755)
        # One target per suite, as in the real notifiers Makefile; net_exit
        # overrides check-net's exit alone.
        (self.checkout / "notifiers").mkdir(exist_ok=True)
        exits = {"mic": submodule_exit, "power": submodule_exit,
                 "net": submodule_exit if net_exit is None else net_exit}
        (self.checkout / "notifiers/Makefile").write_text(
            "".join(f"check-{p}:\n\t@exit {e}\n" for p, e in exits.items()))

    def run_runner(self, command=None, cwd=None):
        # make reads these from the environment: MAKEFLAGS=-n, say, would print the
        # fixture recipes instead of running them, and every submodule would pass.
        env = {k: v for k, v in os.environ.items()
               if k not in ("MAKEFLAGS", "MFLAGS", "MAKELEVEL", "MAKEFILES", "GNUMAKEFLAGS")}
        result = subprocess.run(
            [str(command or self.runner)],
            cwd=str(cwd or self.base), capture_output=True, text=True, timeout=120,
            env=dict(env, SKILLS_LOG=str(self.skills_log)),
        )
        return result.returncode, ANSI.sub("", result.stdout)

    def summary(self, stdout):
        lines = stdout.split("== summary ==\n", 1)[1].strip().splitlines()
        return [line.strip() for line in lines]

    def test_all_suites_passing_exits_zero(self):
        self.fixture()
        code, out = self.run_runner()
        self.assertEqual(code, 0)
        self.assertEqual(self.summary(out), ALL_PASS)

    def test_skips_are_flagged_even_beside_expected_failures(self):
        # unittest prints "OK (skipped=1, expected failures=1)" here.
        self.fixture(unittest_body=(
            "import unittest\n\n\nclass Fixture(unittest.TestCase):\n"
            "    @unittest.skip('deliberate')\n    def test_skip(self):\n        pass\n\n"
            "    @unittest.expectedFailure\n    def test_xfail(self):\n        self.fail()\n"))
        code, out = self.run_runner()
        self.assertEqual(code, 0)
        self.assertEqual(self.summary(out), ["pass, skips  unittest"] + ALL_PASS[1:])

    def test_failing_suite_does_not_stop_later_suites(self):
        self.fixture(unittest_body=FAILING)
        code, out = self.run_runner()
        self.assertEqual(code, 1)
        self.assertEqual(self.summary(out), ["FAIL  unittest"] + ALL_PASS[1:])
        self.assertTrue(self.skills_log.exists(), "later suite did not run after a failure")

    def test_failing_later_suite_fails_the_run(self):
        self.fixture(skills_exit=1)
        code, out = self.run_runner()
        self.assertEqual(code, 1)
        self.assertEqual(self.summary(out), ["pass  unittest", "FAIL  skills"] + ALL_PASS[2:])

    def test_a_failing_submodule_suite_fails_the_run(self):
        self.fixture(submodule_exit=1)
        code, out = self.run_runner()
        self.assertEqual(code, 1)
        self.assertEqual(self.summary(out), ALL_PASS[:2] + [f"FAIL  {s}" for s in SUBMODULES])

    def test_one_failing_notifier_suite_does_not_hide_the_others(self):
        # Each program is its own suite: `make check` would stop at net-notify.
        self.fixture(net_exit=1)
        code, out = self.run_runner()
        self.assertEqual(code, 1)
        self.assertEqual(self.summary(out),
                         ALL_PASS[:2] + ["pass  mic-notify", "FAIL  net-notify", "pass  power-notify"])

    def test_an_unfetched_submodule_is_not_a_pass(self):
        # Before `git submodule update`, the directory exists but is empty.
        self.fixture()
        (self.checkout / "notifiers/Makefile").unlink()
        code, out = self.run_runner()
        self.assertEqual(code, 1)
        self.assertEqual(self.summary(out), ALL_PASS[:2] + [f"FAIL  {s}" for s in SUBMODULES])

    def test_missing_suite_is_not_a_pass(self):
        self.fixture()
        (self.checkout / "bash/check-skills").unlink()
        shutil.rmtree(self.checkout / "tests")
        code, out = self.run_runner()
        self.assertEqual(code, 1)
        self.assertEqual(self.summary(out)[:2], ["FAIL  unittest", "FAIL  skills"])

    def test_runs_through_an_installed_symlink_from_outside_the_checkout(self):
        self.fixture()
        bindir = self.base / "bin"
        bindir.mkdir()
        link = bindir / "run-tests"
        link.symlink_to(self.runner)
        code, out = self.run_runner(command=link, cwd=Path("/"))
        self.assertEqual(code, 0)
        self.assertEqual(self.summary(out), ALL_PASS)


if __name__ == "__main__":
    unittest.main()
