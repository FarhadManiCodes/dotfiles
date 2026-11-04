"""Check the gh skill and ctx7 steps of sysup: what they run, and that a failure is warned about."""

from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "zsh/functions/sysup.zsh"


class SysupAgentToolsTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="sysup-agent-tools-test-")
        self.addCleanup(self.tmp.cleanup)
        self.base = Path(self.tmp.name)
        self.log = self.base / "calls"
        self.env = {
            "HOME": str(self.base),
            "PATH": "/usr/bin:/bin",
            "LC_ALL": "C",
            "NO_COLOR": "1",
            "TEST_LOG": str(self.log),
            "XDG_RUNTIME_DIR": str(self.base),
            "SHPOOL_SESSION_NAME": "fixture",
        }

    def run_sysup(self, stubs=""):
        code = (
            """
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
claude() { return 0; }
gh() { print -r -- "gh $*" >> "$TEST_LOG"; }
ctx7() { print -r -- "ctx7 $*" >> "$TEST_LOG"; }
"""
            + stubs
            + "\nsysup\n"
        )
        return subprocess.run(
            ["zsh", "-f", "-c", code, "test", str(SOURCE)],
            cwd=self.base,
            env=self.env,
            capture_output=True,
            text=True,
            timeout=15,
            check=False,
        )

    def calls(self):
        return self.log.read_text().splitlines()

    def test_clean_run_updates_the_named_skills_and_ctx7(self):
        result = self.run_sysup()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(
            self.calls(),
            [
                "gh skill update --all gh linux-perf",
                "ctx7 upgrade --yes",
                "ctx7 setup --cli --yes --claude",
                "ctx7 setup --cli --yes --codex",
                "ctx7 setup --cli --yes --opencode",
            ],
        )

    def test_failed_skill_update_warns_and_the_run_continues(self):
        result = self.run_sysup(
            'gh() { print -r -- "gh $*" >> "$TEST_LOG"; return 4; }'
        )
        lines = result.stdout.rstrip().splitlines()
        note = "!! gh skill update failed (exit 4); see the output above"
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertEqual(lines[-2:], [note, "==> sysup finished with warnings"])
        self.assertIn("ctx7 upgrade --yes", self.calls())

    def test_failed_upgrade_is_one_warning_and_skips_the_skill_refresh(self):
        result = self.run_sysup(
            'ctx7() { print -r -- "ctx7 $*" >> "$TEST_LOG"; return 5; }'
        )
        lines = result.stdout.rstrip().splitlines()
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertEqual(
            lines[-2:],
            [
                "!! ctx7 upgrade failed (exit 5); see the output above",
                "==> sysup finished with warnings",
            ],
        )
        self.assertEqual(
            self.calls(),
            ["gh skill update --all gh linux-perf", "ctx7 upgrade --yes"],
        )

    def test_failed_setup_names_the_agent_and_the_others_still_run(self):
        result = self.run_sysup("""
ctx7() {
  print -r -- "ctx7 $*" >> "$TEST_LOG"
  [[ $* == *--codex* ]] && return 6
  return 0
}
""")
        lines = result.stdout.rstrip().splitlines()
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertEqual(
            lines[-2:],
            [
                "!! ctx7 setup for codex failed (exit 6); see the output above",
                "==> sysup finished with warnings",
            ],
        )
        self.assertEqual(self.calls()[-1], "ctx7 setup --cli --yes --opencode")


if __name__ == "__main__":
    unittest.main()
