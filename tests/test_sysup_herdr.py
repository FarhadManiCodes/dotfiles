"""Check update-only dispatch and sysup failure propagation without updates."""
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "zsh/functions/sysup.zsh"


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

    def test_failed_herdr_update_stops_sysup_before_later_tools(self):
        code = '''
source "$1"
for fn in _sysup_mirrorlist_check _sysup_bgutil _sysup_yts \\
          _sysup_prune_claude_versions _sysup_plugins _sysup_nvim_health \\
          _sysup_fwupd_refresh_if_stale _sysup_pacnew; do
  functions[$fn]=':'
done
systemd-inhibit() { exec sleep 30; }
paru() { return 0; }
uv() { return 0; }
cargo() { print -r -- "cargo $*" >> "$TEST_LOG"; }
_sysup_herdr() { print -r -- herdr >> "$TEST_LOG"; return 17; }
claude() { print -r -- claude >> "$TEST_LOG"; }
sysup
'''
        result = subprocess.run(["zsh", "-f", "-c", code, "test", str(SOURCE)],
                                cwd=self.base, env=self.env, capture_output=True, text=True, timeout=15)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Herdr update failed", result.stdout)
        self.assertEqual(self.log.read_text().splitlines(), ["cargo install-update --all", "herdr"])
        self.assertNotIn("==> sysup done", result.stdout)


if __name__ == "__main__":
    unittest.main()
