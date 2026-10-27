"""Check `sysup --test-tools` runs each project's suite on the newest dependencies, with a stub uv."""

from pathlib import Path
import subprocess
import tempfile
import time
import unittest

SOURCE = Path(__file__).resolve().parents[1] / "zsh/functions/sysup.zsh"


class ToolTestsStepTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="sysup-tool-tests-")
        self.addCleanup(self.tmp.cleanup)
        self.base = Path(self.tmp.name)
        self.projects = self.base / "projects"
        for name in ("mathunicode", "paper-refinery", "audio_text"):
            (self.projects / name).mkdir(parents=True)
            (self.projects / name / "pyproject.toml").write_text("")
        self.log = self.base / "log"
        bin_dir = self.base / "bin"
        bin_dir.mkdir()
        uv = bin_dir / "uv"
        uv.write_text(
            '#!/bin/sh\nprintf "%s|%s\\n" "$(basename "$PWD")" "$*" >> "$TEST_LOG"\n'
            'case "$PWD" in *"$TEST_FAIL") case "$TEST_MODE" in\n'
            '  tests) echo "1 failed, 4 passed in 0.1s"; exit 1 ;;\n'
            '  resolve) echo "error: no solution found"; exit 2 ;;\n'
            "  timeout) exit 124 ;;\n"
            '  nothing) echo "no tests ran in 0.01s"; exit 5 ;;\n'
            "  crash) exit 139 ;;\n"
            "esac ;; esac\n"
            'echo "5 passed in 0.1s"\n'
        )
        uv.chmod(0o755)
        self.env = {
            "HOME": str(self.base),
            "PATH": f"{bin_dir}:/usr/bin:/bin",
            "LC_ALL": "C",
            "NO_COLOR": "1",
            "TEST_LOG": str(self.log),
            "TEST_FAIL": "none",
            "TEST_MODE": "tests",
            "XDG_RUNTIME_DIR": str(self.base),
            "SHPOOL_SESSION_NAME": "fixture",
        }

    def run_zsh(self, body):
        return subprocess.run(
            ["zsh", "-f", "-c", f'source "$1"\n{body}', "test", str(SOURCE)],
            cwd=self.base,
            env=self.env,
            capture_output=True,
            text=True,
            timeout=30,
            check=False,
        )

    def test_each_suite_runs_isolated_on_the_newest_versions(self):
        result = self.run_zsh(f"_sysup_tool_tests {self.projects}; print rc=$?")
        self.assertIn("rc=0", result.stdout, result.stderr)
        uv_run = (
            "{}|run --isolated --upgrade --no-compile-bytecode"
            " {}python -m pytest -q -p no:cacheprovider"
        )
        self.assertEqual(
            sorted(self.log.read_text().splitlines()),
            [
                uv_run.format("audio_text", ""),
                uv_run.format("mathunicode", ""),
                uv_run.format("paper-refinery", "--extra dev "),
            ],
        )
        self.assertIn("mathunicode: 5 passed in 0.1s", result.stdout)

    def run_failing(self, mode):
        self.env.update(TEST_FAIL="paper-refinery", TEST_MODE=mode)
        result = self.run_zsh(
            f"local -a _sysup_notes; _sysup_tool_tests {self.projects}; "
            'print rc=$?; print -r -- "NOTE: ${_sysup_notes[*]}"'
        )
        self.assertIn("rc=1", result.stdout, result.stderr)
        self.assertEqual(
            len(self.log.read_text().splitlines()), 3
        )  # the others still ran
        return result.stdout

    def test_a_failing_suite_is_recorded_with_its_summary(self):
        out = self.run_failing("tests")
        self.assertIn(
            "paper-refinery: FAILED with the latest dependencies (exit 1): 1 failed, 4 passed in 0.1s",
            out,
        )
        self.assertIn(
            "NOTE: tests failed with the latest dependencies: paper-refinery;",
            out,
        )

    def test_the_end_of_a_short_output_is_still_shown(self):
        out = self.run_failing("resolve")
        self.assertIn("error: no solution found", out)
        self.log.unlink()
        out = self.run_failing("tests")
        self.assertEqual(
            out.count("1 failed, 4 passed in 0.1s"), 2
        )  # the header and the output tail

    def test_nothing_collected_is_not_reported_as_a_broken_tool(self):
        out = self.run_failing("nothing")
        self.assertIn("paper-refinery: could not run the suite (exit 5)", out)
        self.assertNotIn("FAILED with the latest dependencies", out)

    def test_a_crashing_suite_is_a_result_not_a_skip(self):
        out = self.run_failing("crash")
        self.assertIn("paper-refinery: could not run the suite (exit 139)", out)
        self.assertNotIn("skipped", out)

    def test_timeout_keeps_the_suite_in_the_foreground_process_group(self):
        # Plain `timeout` starts its child in a new process group, which a terminal Ctrl-C never reaches.
        bin_dir = self.base / "bin"
        (bin_dir / "timeout").write_text(
            '#!/bin/sh\nprintf "%s\\n" "$1" >> "$TEST_LOG.timeout"\nshift; shift\nexec "$@"\n'
        )
        (bin_dir / "timeout").chmod(0o755)
        self.run_zsh(f"_sysup_tool_tests {self.projects}")
        self.assertEqual(
            set(Path(f"{self.log}.timeout").read_text().split()),
            {"--foreground"},
        )

    def test_a_leftover_grandchild_does_not_block_the_step(self):
        (self.base / "bin" / "uv").write_text(
            '#!/bin/sh\nsleep 4 &\necho "5 passed in 0.1s"\n'
        )
        started = time.monotonic()
        result = self.run_zsh(f"_sysup_tool_tests {self.projects}; print rc=$?")
        self.assertLess(
            time.monotonic() - started, 3, "the step waited for the grandchild"
        )
        self.assertIn("rc=0", result.stdout, result.stderr)
        self.assertEqual(
            list(self.base.glob("sysup-tool-tests.*")),
            [],
            "output file left behind",
        )

    def test_a_leftover_suite_process_does_not_keep_the_sysup_lock_held(self):
        (self.base / "bin" / "uv").write_text(
            '#!/bin/sh\nsleep 4 &\necho "5 passed in 0.1s"\n'
        )
        lock = self.base / "lock"
        result = self.run_zsh(
            f"exec {{_lockfd}}>{lock}; flock -n $_lockfd; _sysup_tool_tests {self.projects}; "
            f"exec {{_lockfd}}>&-; flock -n {lock} true; print LOCKRC=$?"
        )
        self.assertIn("LOCKRC=0", result.stdout, result.stderr)

    def test_tool_tests_that_cannot_start_say_so_and_are_recorded(self):
        self.env["XDG_RUNTIME_DIR"] = str(self.base / "no-such-dir")
        result = self.run_zsh(
            f"local -a _sysup_notes; _sysup_tool_tests {self.projects}; "
            'print rc=$?; print -r -- "NOTE: ${_sysup_notes[*]}"'
        )
        self.assertIn("rc=1", result.stdout, result.stderr)
        self.assertIn("NOTE: tool tests could not start", result.stdout)
        self.assertFalse(self.log.exists(), "no suite should have run")

    def test_a_suite_that_could_not_run_is_not_reported_as_a_broken_tool(self):
        out = self.run_failing("resolve")
        self.assertIn("paper-refinery: could not run the suite (exit 2)", out)
        self.assertIn("NOTE: tests could not run", out)
        self.assertNotIn("FAILED with the latest dependencies", out)

    def test_a_timeout_is_named_as_such(self):
        out = self.run_failing("timeout")
        self.assertIn("paper-refinery: TIMED OUT after 600 s", out)
        self.assertIn("NOTE: tests could not run", out)

    def test_stdin_is_closed_for_the_suites(self):
        stub = self.base / "bin" / "uv"
        stub.write_text(
            '#!/bin/sh\nif read -r _; then echo "got stdin"; else echo "5 passed in 0.1s"; fi\n'
        )
        result = subprocess.run(
            [
                "zsh",
                "-f",
                "-c",
                f'source "$1"\n_sysup_tool_tests {self.projects}',
                "test",
                str(SOURCE),
            ],
            cwd=self.base,
            env=self.env,
            input="x\n",
            capture_output=True,
            text=True,
            timeout=30,
            check=True,
        )
        self.assertNotIn("got stdin", result.stdout)

    def test_missing_checkout_is_skipped(self):
        (self.projects / "audio_text" / "pyproject.toml").unlink()
        result = self.run_zsh(f"_sysup_tool_tests {self.projects}; print rc=$?")
        self.assertIn("rc=0", result.stdout, result.stderr)
        self.assertIn("audio_text: no checkout", result.stdout)
        self.assertEqual(len(self.log.read_text().splitlines()), 2)

    SYSUP = """
for fn in _sysup_mirrorlist_check _sysup_bgutil _sysup_yts _sysup_herdr \\
          _sysup_prune_claude_versions _sysup_plugins _sysup_nvim_health \\
          _sysup_fwupd_refresh_if_stale _sysup_pacnew; do
  functions[$fn]=':'
done
systemd-inhibit() { exec sleep 30; }
paru() { return 0; }
cargo() { return 0; }
claude() { :; }
uv() { return 0; }
_sysup_tool_tests() { _sysup_notes+=("tests failed with the latest dependencies: x; see the output above"); return 1; }
"""

    def test_option_is_needed_and_failure_ends_the_run_with_warnings(self):
        result = self.run_zsh(self.SYSUP + "sysup")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertNotIn("Own tools", result.stdout)
        result = self.run_zsh(self.SYSUP + "sysup --test-tools")
        self.assertEqual(result.returncode, 1, result.stderr)
        lines = result.stdout.rstrip().splitlines()
        self.assertIn(
            "==> Own tools: tests against the newest dependencies", lines
        )
        self.assertEqual(
            lines[-2],
            "!! tests failed with the latest dependencies: x; see the output above",
        )
        self.assertEqual(lines[-1], "==> sysup finished with warnings")


if __name__ == "__main__":
    unittest.main()
