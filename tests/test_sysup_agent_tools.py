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
        # ctx7 must be a real executable: sysup runs setup through timeout, which cannot call a
        # shell function. Each stub prints its *_VERSION for a version query; FAIL_ON names the
        # arguments that make it fail, with STATUS.
        bin_dir = self.base / "bin"
        bin_dir.mkdir()
        for name, prefix, version_args in (
            ("ctx7", "CTX7", "--version"),
            ("npm", "NPM", "view ctx7 version"),
        ):
            stub = bin_dir / name
            stub.write_text(
                f"""#!/bin/sh
echo "{name} $*" >> "$TEST_LOG"
case "$*" in *"${prefix}_FAIL_ON"*) exit "${prefix}_STATUS" ;; esac
[ "$*" = "{version_args}" ] && echo "${prefix}_VERSION"
exit 0
"""
            )
            stub.chmod(0o755)
        self.env = {
            "HOME": str(self.base),
            "PATH": f"{bin_dir}:/usr/bin:/bin",
            "CTX7_FAIL_ON": "no-such-argument",
            "CTX7_STATUS": "0",
            "CTX7_VERSION": "1.0.0",
            "NPM_FAIL_ON": "no-such-argument",
            "NPM_STATUS": "0",
            "NPM_VERSION": "1.0.0",
            "LC_ALL": "C",
            "NO_COLOR": "1",
            "TEST_LOG": str(self.log),
            "XDG_RUNTIME_DIR": str(self.base),
            "SHPOOL_SESSION_NAME": "fixture",
        }

    def run_sysup(self, stubs="", **env):
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
"""
            + stubs
            + "\nsysup\n"
        )
        return subprocess.run(
            ["zsh", "-f", "-c", code, "test", str(SOURCE)],
            cwd=self.base,
            env=dict(self.env, **env),
            capture_output=True,
            text=True,
            timeout=15,
            check=False,
        )

    def calls(self):
        return self.log.read_text().splitlines()

    def test_clean_run_updates_the_named_skills_and_refreshes_ctx7(self):
        result = self.run_sysup()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn(
            "    ctx7 1.0.0 is up to date", result.stdout.splitlines()
        )
        # Codex runs last: its variant of the shared ~/.agents/skills/find-docs must win.
        self.assertEqual(
            self.calls(),
            [
                "gh skill update --all gh linux-perf",
                "ctx7 --version",
                "npm view ctx7 version",
                "ctx7 setup --cli --yes --claude",
                "ctx7 setup --cli --yes --opencode",
                "ctx7 setup --cli --yes --codex",
            ],
        )

    def test_newer_ctx7_on_npm_is_installed_before_the_refresh(self):
        result = self.run_sysup(NPM_VERSION="1.1.0")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("    ctx7 1.0.0 -> 1.1.0", result.stdout.splitlines())
        calls = self.calls()
        self.assertEqual(calls[3], "npm install -g ctx7@1.1.0")
        self.assertEqual(calls[4], "ctx7 setup --cli --yes --claude")

    def test_failed_skill_update_warns_and_the_run_continues(self):
        result = self.run_sysup(
            'gh() { print -r -- "gh $*" >> "$TEST_LOG"; return 4; }'
        )
        lines = result.stdout.rstrip().splitlines()
        note = "!! gh skill update failed (exit 4); see the output above"
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertEqual(lines[-2:], [note, "==> sysup finished with warnings"])
        self.assertIn("ctx7 --version", self.calls())

    def assert_one_ctx7_warning_and_no_refresh(self, result, note):
        lines = result.stdout.rstrip().splitlines()
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertEqual(
            lines[-2:], [f"!! {note}", "==> sysup finished with warnings"]
        )
        self.assertFalse(
            [c for c in self.calls() if "setup" in c], self.calls()
        )

    def test_failed_npm_query_is_one_warning_and_skips_the_refresh(self):
        result = self.run_sysup(NPM_FAIL_ON="view", NPM_STATUS="5")
        self.assert_one_ctx7_warning_and_no_refresh(
            result, "ctx7 version check failed (exit 5); see the output above"
        )
        self.assertNotIn("install", " ".join(self.calls()))

    def test_empty_version_answer_counts_as_a_failed_check(self):
        result = self.run_sysup(NPM_VERSION="")
        self.assert_one_ctx7_warning_and_no_refresh(
            result, "ctx7 version check failed (exit 1); see the output above"
        )
        self.assertNotIn("install", " ".join(self.calls()))

    def test_failed_install_is_one_warning_and_skips_the_refresh(self):
        result = self.run_sysup(
            NPM_VERSION="1.1.0", NPM_FAIL_ON="install", NPM_STATUS="7"
        )
        self.assert_one_ctx7_warning_and_no_refresh(
            result, "ctx7 install failed (exit 7); see the output above"
        )

    def test_failed_setup_names_the_agent_and_the_others_still_run(self):
        result = self.run_sysup(CTX7_FAIL_ON="--opencode", CTX7_STATUS="6")
        lines = result.stdout.rstrip().splitlines()
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertEqual(
            lines[-2:],
            [
                "!! ctx7 setup for opencode failed (exit 6); see the output above",
                "==> sysup finished with warnings",
            ],
        )
        self.assertEqual(self.calls()[-1], "ctx7 setup --cli --yes --codex")

    def test_a_login_that_hangs_is_cut_off_and_warned_about_per_agent(self):
        # A fake timeout that expires at once; it records the limit sysup asked for.
        fake = self.base / "fake-bin"
        fake.mkdir()
        timeout = fake / "timeout"
        timeout.write_text(
            '#!/bin/sh\necho "timeout $*" >> "$TEST_LOG"\nexit 124\n'
        )
        timeout.chmod(0o755)
        result = self.run_sysup(PATH=f"{fake}:{self.env['PATH']}")
        lines = result.stdout.rstrip().splitlines()
        self.assertEqual(result.returncode, 1, result.stderr)
        for agent in ("claude", "opencode", "codex"):
            self.assertIn(
                f"!! ctx7 setup for {agent} failed (exit 124); see the output above",
                lines,
            )
        self.assertIn(
            "timeout --foreground 120s ctx7 setup --cli --yes --claude",
            self.calls(),
        )


if __name__ == "__main__":
    unittest.main()
