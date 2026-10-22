"""Check Herdr update dispatch and that sysup reports failures, continues, and ends non-zero."""
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "zsh/functions/sysup.zsh"
HELPER = ROOT / "bash/herdr-cargo"


class SysupHerdrTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="sysup-herdr-test-")
        self.addCleanup(self.tmp.cleanup)
        self.base = Path(self.tmp.name)
        self.log = self.base / "calls"
        self.helper = self.base / "helper with spaces"
        self.helper.write_text('''#!/bin/bash
printf '%s\\n' "$*" >> "$TEST_LOG"
exit "$TEST_STATUS"
''')
        self.env = {"HOME": str(self.base), "PATH": "/usr/bin:/bin", "LC_ALL": "C",
                    "NO_COLOR": "1", "TEST_LOG": str(self.log), "TEST_STATUS": "0",
                    "XDG_RUNTIME_DIR": str(self.base), "SHPOOL_SESSION_NAME": "fixture"}

    def run_step(self, source=SOURCE, explicit=True):
        code = 'source "$1"; _sysup_herdr "$2"' if explicit else 'source "$1"; _sysup_herdr'
        return subprocess.run(["zsh", "-f", "-c", code, "test", str(source), str(self.helper)],
                              cwd=self.base, env=self.env, capture_output=True, text=True, timeout=15)

    def test_dispatches_update_only_and_propagates_failure(self):
        result = self.run_step()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.log.read_text(), "--update\n")
        self.env["TEST_STATUS"] = "17"
        self.assertEqual(self.run_step().returncode, 17)

    def test_default_helper_path_works_when_sourced_through_symlink(self):
        link = self.base / "sysup.zsh"
        link.symlink_to(SOURCE)
        result = self.run_step(source=link, explicit=False)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("not installed", result.stdout)
        self.assertFalse(self.log.exists())

    def run_sysup(self, stubs, args="", after=""):
        code = '''
source "$1"
for fn in _sysup_mirrorlist_check _sysup_bgutil _sysup_yts _sysup_herdr \\
          _sysup_prune_claude_versions _sysup_plugins _sysup_nvim_health \\
          _sysup_fwupd_refresh_if_stale _sysup_pacnew; do
  functions[$fn]=':'
done
systemd-inhibit() { exec sleep 30; }
paru() { return 0; }
uv() { return 0; }
cargo() { return 0; }
claude() { print -r -- claude >> "$TEST_LOG"; }
''' + stubs + f"\nsysup {args}\n{after}\n"
        return subprocess.run(["zsh", "-f", "-c", code, "test", str(SOURCE)],
                              cwd=self.base, env=self.env, capture_output=True, text=True, timeout=15)

    def assert_warned_and_continued(self, result, failure):
        self.assertEqual(result.returncode, 1, result.stderr)
        lines = result.stdout.rstrip().splitlines()
        self.assertIn(f"!! {failure} \u2014 continuing sysup", lines)
        self.assertEqual(lines[-2:], [f"!! {failure}", "==> sysup finished with warnings"])
        self.assertNotIn("==> sysup done", lines)
        self.assertEqual(self.log.read_text().splitlines(), ["claude"])

    def test_failed_herdr_update_is_reported_and_sysup_continues(self):
        result = self.run_sysup('''
_sysup_herdr() { print -r -- "could not fetch the release" > "$HERDR_CARGO_REASON_FILE"; return 17; }
''')
        self.assert_warned_and_continued(result, "Herdr update failed (exit 17): could not fetch the release")

    def test_herdr_failure_without_a_reason_points_at_earlier_output(self):
        result = self.run_sysup("_sysup_herdr() { return 3; }")
        self.assert_warned_and_continued(result, "Herdr update failed (exit 3); see the output above")

    def test_real_helper_reason_reaches_sysup_through_the_subshell(self):
        wrapper = self.base / "failing-helper"
        wrapper.write_text(f'#!/bin/bash\nexec bash "{HELPER}" --bogus\n')
        result = self.run_sysup(f'''
source {SOURCE.parent}/sysup/herdr.zsh
functions[_sysup_herdr_real]=$functions[_sysup_herdr]
_sysup_herdr() {{ _sysup_herdr_real {wrapper}; }}
''')
        self.assert_warned_and_continued(result, "Herdr update failed (exit 1): unknown argument: --bogus")

    def test_unwritable_reason_file_does_not_change_the_helper_exit(self):
        env = dict(self.env, HERDR_CARGO_REASON_FILE=str(self.base / "no-such-dir" / "reason"))
        result = subprocess.run(["bash", str(HELPER), "--bogus"], env=env, capture_output=True, text=True, timeout=15)
        self.assertEqual(result.returncode, 1)
        self.assertEqual(result.stderr, "herdr-cargo: unknown argument: --bogus\n")

    def test_failed_uv_upgrade_is_reported_and_sysup_continues(self):
        result = self.run_sysup("uv() { [[ $2 == upgrade ]] && return 2; return 0; }")
        self.assertEqual(result.returncode, 1, result.stderr)
        lines = result.stdout.rstrip().splitlines()
        self.assertIn("uv tool upgrade failed (exit 2)", lines[-2])
        self.assertEqual(lines[-1], "==> sysup finished with warnings")
        self.assertEqual(self.log.read_text().splitlines(), ["claude"])

    def test_uv_failure_is_repeated_when_a_later_step_stops_sysup(self):
        result = self.run_sysup("uv() { [[ $2 == upgrade ]] && return 2; return 0; }\n_sysup_bgutil() { return 1; }")
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertEqual(result.stdout.count("!! uv tool upgrade failed (exit 2)"), 2)
        self.assertTrue(result.stdout.rstrip().splitlines()[-1].startswith("!! uv tool upgrade failed"))

    def test_ctrl_c_in_a_step_stops_sysup_instead_of_being_recorded_as_a_failure(self):
        for stubs in ("uv() { [[ $2 == upgrade ]] && return 130; return 0; }",
                      "_sysup_herdr() { return 130; }"):
            with self.subTest(stubs=stubs):
                self.log.unlink(missing_ok=True)
                result = self.run_sysup(stubs)
                self.assertEqual(result.returncode, 130, result.stderr)
                self.assertIn("interrupted, stopping sysup", result.stdout)
                self.assertFalse(self.log.exists(), "later steps must not run")  # claude would log

    def test_ctrl_c_in_any_step_stops_sysup_before_the_next_one(self):
        # (interrupted step, the step that follows it and must not run)
        for hit, nxt in (("_sysup_mirrorlist_check", "paru"), ("_sysup_plugins", "_sysup_nvim_health"),
                         ("_sysup_nvim_health", "_sysup_fwupd_refresh_if_stale"),
                         ("_sysup_fwupd_refresh_if_stale", "_sysup_pacnew")):
            with self.subTest(interrupted=hit):
                self.log.unlink(missing_ok=True)
                result = self.run_sysup(
                    f'{nxt}() {{ print -r -- NEXT-RAN >> "$TEST_LOG"; }}\n{hit}() {{ kill -INT $$; }}')
                self.assertEqual(result.returncode, 130, result.stderr)
                self.assertFalse(self.log.exists() and "NEXT-RAN" in self.log.read_text(), hit)
                self.assertNotIn("sysup done", result.stdout)

    def test_a_crashed_step_is_a_failure_to_continue_past_not_an_interrupt(self):
        result = self.run_sysup("uv() { [[ $2 == upgrade ]] && return 139; return 0; }")
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertNotIn("interrupted", result.stdout)
        self.assertEqual(self.log.read_text().splitlines(), ["claude"])

    def test_traps_do_not_outlive_the_call(self):
        traps = self.base / "traps"
        self.run_sysup("", after=f'trap >| {traps}')  # not in $(...): that subshell resets traps
        self.assertTrue(traps.exists())
        self.assertEqual(traps.read_text(), "")

    def test_a_failed_yts_install_is_repeated_at_the_end(self):
        result = self.run_sysup("_sysup_yts() { return 4; }")
        self.assert_warned_and_continued(result, "yts install failed (exit 4); see the output above")

    def test_reason_file_is_removed_when_sysup_is_interrupted(self):
        runtime = self.base / "run"
        runtime.mkdir()
        self.env["XDG_RUNTIME_DIR"] = str(runtime)
        result = self.run_sysup('''
_sysup_herdr() { print -r -- partial > "$HERDR_CARGO_REASON_FILE"; kill -INT $$; sleep 1; }
''')
        self.assertEqual([p.name for p in runtime.iterdir() if p.name.startswith("sysup-herdr-reason")], [])


    def test_podman_failure_still_ends_with_the_warnings_line(self):
        result = self.run_sysup("uv() { [[ $2 == upgrade ]] && return 2; return 0; }\n"
                                "_sysup_podman_images() { return 3; }", "--podman-images")
        self.assertEqual(result.returncode, 3, result.stderr)
        lines = result.stdout.rstrip().splitlines()
        self.assertIn("uv tool upgrade failed (exit 2)", lines[-2])
        self.assertEqual(lines[-1], "==> sysup finished with warnings")


if __name__ == "__main__":
    unittest.main()
