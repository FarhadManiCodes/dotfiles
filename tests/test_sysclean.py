"""Run isolated sysclean steps against fixture directories and stubbed tools.

    python3 -B -m unittest discover -s tests -v

No cache, package, journal, coredump or Claude session on this machine is
touched. Steps 2 and 7 name absolute system paths, so those sections are run
with the path prefix rewritten to the fixture root; what that leaves untested
is the path constants themselves, which `test_system_paths_are_unchanged`
asserts separately. Everything else -- the glob qualifiers, the guards and the
messages -- is the real source text.

The weight here is on four regressions, because each was live in the committed
version: a bare glob list where NOMATCH aborts the whole `rm` if *either*
pattern misses, an "already cleared" message printed when nothing was, a
missing-sessions probe that read as "every snapshot is orphaned", and a
decimal printed behind an 0x prefix.
"""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


SOURCE_PATH = Path(__file__).resolve().parents[1] / "zsh/functions/sysclean.zsh"
SOURCE = SOURCE_PATH.read_text()

PKG_DIR = "/var/cache/pacman/pkg"
DUMP_DIR = "/var/lib/systemd/coredump"


def section(start, end):
    """The marker is kept, unlike test_config_drift's slicer: these markers are
    partial lines, and dropping one leaves the rest of its line as bare words."""
    return start + SOURCE.split(start, 1)[1].split(end, 1)[0]


# `local` is only legal inside a function, and the sections use it, so each
# section runs wrapped in one. The stubbed `sudo` records the call and then runs
# it without privilege, so a fixture `rm` still happens and is observable.
# Plain "$@" rather than `command "$@"`: `command` bypasses shell functions,
# which would silently run the real journalctl instead of a test's stub.
PREAMBLE = r'''
sudo() { print -r -- "sudo $*" >> "$CALLS"; "$@" }
'''


class SyscleanTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="sysclean-test-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.home = self.root / "home"
        self.home.mkdir()
        self.calls = self.root / "calls"
        self.env = dict(
            os.environ, HOME=str(self.home), ROOT=str(self.root),
            CALLS=str(self.calls), VACUUM_FAIL="",
        )

    # --- harness ---------------------------------------------------------------

    def run_section(self, code, setup="", rewrite=True):
        """Run one extracted section. Asserts stderr is empty, which is the
        whole point for the glob cases: zsh reports `no matches found` there,
        and a bare `2>/dev/null` on the command cannot catch it."""
        if rewrite:
            code = code.replace(PKG_DIR + "/", '$ROOT/pkg/')
            code = code.replace(DUMP_DIR + "/", '$ROOT/coredump/')
        script = PREAMBLE + setup + "\nstep() {\n" + code + "\n}\nstep\n"
        result = subprocess.run(
            ["zsh", "-f", "-c", script],
            env=self.env, capture_output=True, text=True, timeout=30,
        )
        self.assertEqual(result.stderr, "", f"unexpected stderr:\n{result.stderr}")
        self.assertEqual(result.returncode, 0, result.stdout)
        return result.stdout

    def touch(self, *relative):
        for rel in relative:
            path = self.root / rel
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text("")

    def listing(self, relative):
        path = self.root / relative
        return sorted(p.name for p in path.iterdir()) if path.is_dir() else []

    def called(self):
        return self.calls.read_text() if self.calls.exists() else ""

    # --- step 2: partial downloads --------------------------------------------

    PARTIALS = property(lambda self: section(
        "# Clean partial downloads first", "\n  if command -v paccache"))

    def test_only_download_pattern_matches(self):
        # The live state when this was found: nine download-* files, no *.part.
        # The bare glob list aborted on *.part and removed none of the nine.
        self.touch("pkg/download-a.pkg.tar.zst", "pkg/download-b.pkg.tar.zst",
                   "pkg/keep-1.0-1-x86_64.pkg.tar.zst")
        output = self.run_section(self.PARTIALS)
        self.assertIn("Removed 2 partial download(s)", output)
        self.assertEqual(self.listing("pkg"), ["keep-1.0-1-x86_64.pkg.tar.zst"])

    def test_only_part_pattern_matches(self):
        self.touch("pkg/half.pkg.tar.zst.part", "pkg/keep-1.0-1-x86_64.pkg.tar.zst")
        output = self.run_section(self.PARTIALS)
        self.assertIn("Removed 1 partial download(s)", output)
        self.assertEqual(self.listing("pkg"), ["keep-1.0-1-x86_64.pkg.tar.zst"])

    def test_both_patterns_match(self):
        self.touch("pkg/download-a.pkg.tar.zst", "pkg/half.pkg.tar.zst.part")
        output = self.run_section(self.PARTIALS)
        self.assertIn("Removed 2 partial download(s)", output)
        self.assertEqual(self.listing("pkg"), [])

    def test_no_partials_says_so_and_does_not_invoke_sudo(self):
        # Nothing to remove must not spend a sudo prompt on an empty argv.
        self.touch("pkg/keep-1.0-1-x86_64.pkg.tar.zst")
        output = self.run_section(self.PARTIALS)
        self.assertIn("No partial downloads to remove", output)
        self.assertNotIn("Removed", output)
        self.assertEqual(self.called(), "")

    def test_absent_cache_directory_is_survivable(self):
        # The glob's own directory missing is not an error either.
        output = self.run_section(self.PARTIALS)
        self.assertIn("No partial downloads to remove", output)

    # --- step 7: coredumps and the journal ------------------------------------

    DUMPS = property(lambda self: section(
        "  # (N) and an array for the same reason as step 2",
        "  # 2 months, not 2 weeks"))
    JOURNAL = property(lambda self: section(
        "  if command -v journalctl >/dev/null 2>&1; then", "\n\n  # 8."))

    def test_empty_coredump_directory_does_not_claim_a_clear(self):
        (self.root / "coredump").mkdir()
        output = self.run_section(self.DUMPS)
        self.assertIn("No coredumps to clear", output)
        self.assertNotIn("Removed", output)
        self.assertEqual(self.called(), "")

    def test_coredumps_present_are_removed(self):
        self.touch("coredump/core.foo.1000.zst", "coredump/core.bar.1000.zst")
        output = self.run_section(self.DUMPS)
        self.assertIn("Removed 2 coredump(s)", output)
        self.assertEqual(self.listing("coredump"), [])

    def test_journal_vacuum_success_is_reported(self):
        setup = 'journalctl() { print -r -- "journalctl $*" >> "$CALLS"; return 0 }'
        output = self.run_section(
            self.JOURNAL, setup)
        self.assertIn("older than 2 months cleaned", output)
        self.assertIn("--vacuum-time=2months", self.called())

    def test_journal_vacuum_failure_is_reported(self):
        # The committed version swallowed both streams and always claimed success.
        setup = ('journalctl() { print -r -- "Failed to vacuum: Permission denied" >&2;'
                 ' return 1 }')
        output = self.run_section(
            self.JOURNAL, setup)
        self.assertIn("journal vacuum failed", output)
        self.assertIn("Permission denied", output)
        self.assertNotIn("cleaned", output)

    def test_journal_step_skipped_without_journalctl(self):
        setup = 'command() { [[ "$2" == journalctl ]] && return 1; builtin command "$@" }'
        output = self.run_section(
            self.JOURNAL, setup)
        self.assertEqual(output, "")

    # --- step 8: Claude file-history ------------------------------------------

    HISTORY = property(lambda self: section(
        '  local claude_hist="$HOME/.claude/file-history"', "\n\n  # 9."))

    def _history_fixture(self, sessions, snapshots):
        for name in sessions:
            path = self.home / ".claude/projects/-home-farhad-dotfiles" / f"{name}.jsonl"
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text("{}\n")
        for name in snapshots:
            (self.home / ".claude/file-history" / name).mkdir(parents=True)

    def _run_history(self):
        return self.run_section(
            self.HISTORY)

    def test_history_prune_removes_only_orphans(self):
        self._history_fixture(["live-1", "live-2"], ["live-1", "live-2", "gone-1"])
        output = self._run_history()
        self.assertIn("Removed 1 orphaned file-history dir(s)", output)
        self.assertEqual(
            sorted(p.name for p in (self.home / ".claude/file-history").iterdir()),
            ["live-1", "live-2"])

    def test_history_prune_refuses_when_no_sessions_are_found(self):
        # The guard under test. Without it the empty session set reads as "every
        # snapshot is orphaned" and the whole undo history goes in one rm -rf.
        (self.home / ".claude/projects").mkdir(parents=True)
        self._history_fixture([], ["keep-1", "keep-2"])
        output = self._run_history()
        self.assertIn("not pruning", output)
        self.assertNotIn("Removed", output)
        self.assertEqual(
            sorted(p.name for p in (self.home / ".claude/file-history").iterdir()),
            ["keep-1", "keep-2"])

    def test_history_prune_with_nothing_orphaned(self):
        self._history_fixture(["live-1"], ["live-1"])
        self.assertIn("Removed 0 orphaned", self._run_history())

    def test_history_prune_skipped_when_directories_absent(self):
        self.assertIn("No Claude file-history to check", self._run_history())

    # --- step 9: Firefox cache ------------------------------------------------

    FIREFOX = property(lambda self: section(
        "    # (N) again: this one works today only because", "\n  fi\n"))

    def test_firefox_profile_without_cache2_does_not_stop_the_other(self):
        # Two profiles, one with no cache2/ at all: the bare glob would abort
        # and leave the populated profile's cache in place.
        (self.home / ".cache/mozilla/firefox/bare.default").mkdir(parents=True)
        self.touch("home/.cache/mozilla/firefox/main.default/cache2/entries/aaa",
                   "home/.cache/mozilla/firefox/main.default/cache2/index")
        output = self.run_section(self.FIREFOX)
        self.assertIn("Firefox web asset cache cleared (2 entries)", output)
        self.assertEqual(
            self.listing("home/.cache/mozilla/firefox/main.default/cache2"), [])

    def test_firefox_with_no_cache_says_so(self):
        (self.home / ".cache/mozilla/firefox/bare.default").mkdir(parents=True)
        self.assertIn("No Firefox web asset cache", self.run_section(self.FIREFOX))

    # --- step 5: npm ----------------------------------------------------------

    NPM = property(lambda self: section(
        '  if ! command -v npm >/dev/null 2>&1; then', "\n\n  # 6."))

    def _run_npm(self, all_flag, npm_stub='npm() { return 0 }'):
        return self.run_section(
            self.NPM, f'all={all_flag}\n{npm_stub}')

    def test_npm_cache_is_kept_on_the_safe_run(self):
        output = self._run_npm("false", 'npm() { print -r -- "npm $*" >> "$CALLS" }')
        self.assertIn("Kept", output)
        self.assertEqual(self.called(), "")

    def test_npm_cache_is_wiped_on_all(self):
        output = self._run_npm("true", 'npm() { print -r -- "npm $*" >> "$CALLS" }')
        self.assertIn("npm cache cleaned", output)
        self.assertIn("cache clean --force", self.called())

    def test_npm_failure_is_reported(self):
        output = self._run_npm("true", 'npm() { return 1 }')
        self.assertIn("npm cache clean failed", output)
        self.assertNotIn("cleaned.", output)

    def test_npm_step_skipped_when_npm_is_absent(self):
        setup = 'all=true\ncommand() { [[ "$2" == npm ]] && return 1; builtin command "$@" }'
        output = self.run_section(
            self.NPM, setup)
        self.assertEqual(output, "")

    # --- step 10: NVMe health -------------------------------------------------

    def _run_nvme(self, report, devices=True):
        """Source the whole file with only the device glob pointed at a fixture,
        so the function under test is the real one rather than a slice. The real
        jq parses the report; smartctl is a stub that prints it."""
        dev = self.root / "nvme0"
        if devices:
            dev.write_text("")
        pattern = dev if devices else self.root / "absent"
        source = SOURCE.replace("local -a devs=(/dev/nvme[0-9](N))",
                                f"local -a devs=({pattern}(N))")
        self.assertIn(str(pattern), source, "device glob substitution did not apply")
        script = self.root / "sysclean-under-test.zsh"
        script.write_text(source)
        result = subprocess.run(
            ["zsh", "-f", "-c",
             'smartctl() { print -r -- "$SMART_REPORT" }\n'
             'sudo() { "$@" }\n'
             f'source {script}\n_sysclean_nvme_health\n'],
            env=dict(self.env, SMART_REPORT=report),
            capture_output=True, text=True, timeout=30,
        )
        self.assertEqual(result.stderr, "", result.stderr)
        return result.stdout

    HEALTH = ('{"smart_status":{"passed":%s},"nvme_smart_health_information_log":'
              '{"critical_warning":%d,"available_spare":%d,'
              '"available_spare_threshold":10,"percentage_used":%d,'
              '"media_errors":%d,"temperature":41,"power_on_hours":1200}}')

    def test_critical_warning_is_printed_as_hexadecimal(self):
        # critical_warning arrives as a decimal, so the old "0x${h[crit]}"
        # rendered 16 as 0x16 when the flags are 0x10.
        output = self._run_nvme(self.HEALTH % ("true", 16, 90, 3, 0))
        self.assertIn("critical warning flags set (0x10)", output)
        self.assertNotIn("0x16", output)

    def test_healthy_drive_reports_one_line(self):
        output = self._run_nvme(self.HEALTH % ("true", 0, 90, 3, 0))
        self.assertIn("healthy", output)
        self.assertIn("3% endurance used", output)
        self.assertNotIn("needs attention", output)

    def test_each_threshold_is_reported(self):
        spare = self._run_nvme(self.HEALTH % ("true", 0, 5, 3, 0))
        self.assertIn("spare capacity 5% is below", spare)
        worn = self._run_nvme(self.HEALTH % ("true", 0, 90, 80, 0))
        self.assertIn("80% of rated write endurance used", worn)
        media = self._run_nvme(self.HEALTH % ("true", 0, 90, 3, 7))
        self.assertIn("7 media/data-integrity error(s)", media)
        failed = self._run_nvme(self.HEALTH % ("false", 0, 90, 3, 0))
        self.assertIn("self-assessment FAILED", failed)

    def test_missing_fields_are_not_read_as_good_news(self):
        output = self._run_nvme('{"smart_status":{"passed":true}}')
        self.assertIn("health NOT checked", output)
        self.assertNotIn("healthy", output)

    def test_no_output_from_smartctl_is_not_read_as_good_news(self):
        output = self._run_nvme("")
        self.assertIn("health NOT checked", output)

    # --- the rewriting the harness does --------------------------------------

    def test_system_paths_are_unchanged(self):
        """Steps 2 and 7 run against the fixture root, so the path constants
        themselves are only covered here."""
        self.assertIn(f"{PKG_DIR}/download-*(N)", SOURCE)
        self.assertIn(f"{PKG_DIR}/*.part(N)", SOURCE)
        self.assertIn(f"{DUMP_DIR}/*(N)", SOURCE)

    def test_no_bare_glob_survives_on_a_removal_line(self):
        """Every `rm` takes an array built with (N), never a pattern of its own:
        one unmatched pattern otherwise aborts the whole command."""
        for number, line in enumerate(SOURCE.splitlines(), 1):
            stripped = line.strip()
            if stripped.startswith("#") or " rm " not in f" {stripped} ":
                continue
            self.assertNotIn("*", stripped, f"bare glob on a removal line {number}: {stripped}")


if __name__ == "__main__":
    unittest.main()
