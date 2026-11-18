"""Check the gh skill and ctx7 steps of sysup: what they run, and that a failure is warned about."""

from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "zsh/functions/sysup.zsh"
# Every default sysup step as a no-op (test_sysup_stub_steps.py keeps it complete).
STUB_STEPS = Path(__file__).resolve().parent / "sysup-stub-steps.zsh"


class SysupAgentToolsTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="sysup-agent-tools-test-")
        self.addCleanup(self.tmp.cleanup)
        self.base = Path(self.tmp.name)
        self.log = self.base / "calls"
        # ctx7 must be a real executable: sysup runs setup through timeout, which cannot call a
        # shell function. Each stub prints its *_VERSION for a version query; FAIL_ON names the
        # arguments that make it fail, with STATUS. ctx7 setup writes find-docs and the agent's
        # rule like the real one, so a test can tell whether sysup deletes the skill after setup
        # or before; CTX7_NO_RULE names agents whose rule it does not write.
        bin_dir = self.base / "bin"
        bin_dir.mkdir()
        ctx7_setup = """case "$*" in "setup "*)
  args="$*" && agent=${args##*--}
  case $agent in
    claude) skill=.claude/skills/find-docs rule=.claude/rules/context7.md ;;
    opencode) skill=.agents/skills/find-docs rule=.config/opencode/AGENTS.md ;;
    codex) skill=.agents/skills/find-docs rule=.codex/AGENTS.md ;;
  esac
  mkdir -p "$HOME/$skill"
  case " $CTX7_NO_RULE " in *" $agent "*) ;; *)
    mkdir -p "$(dirname "$HOME/$rule")"
    printf '<!-- context7 -->\nUse the ctx7 CLI\n<!-- context7 -->\n' >> "$HOME/$rule" ;;
  esac ;;
esac
"""
        for name, prefix, version_args, extra in (
            ("ctx7", "CTX7", "--version", ctx7_setup),
            ("npm", "NPM", "view ctx7 version", ""),
        ):
            stub = bin_dir / name
            stub.write_text(
                f"""#!/bin/sh
echo "{name} $*" >> "$TEST_LOG"
case "$*" in *"${prefix}_FAIL_ON"*) exit "${prefix}_STATUS" ;; esac
[ "$*" = "{version_args}" ] && echo "${prefix}_VERSION"
{extra}exit 0
"""
            )
            stub.chmod(0o755)
        self.env = {
            "HOME": str(self.base),
            "PATH": f"{bin_dir}:/usr/bin:/bin",
            "CTX7_FAIL_ON": "no-such-argument",
            "CTX7_NO_RULE": "",
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
source "$2" || exit 1
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
            ["zsh", "-f", "-c", code, "test", str(SOURCE), str(STUB_STEPS)],
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
        self.assertEqual(
            self.calls(),
            [
                "gh skill update --all gh",
                "ctx7 --version",
                "npm view ctx7 version",
                "ctx7 setup --cli --yes --claude",
                "ctx7 setup --cli --yes --opencode",
                "ctx7 setup --cli --yes --codex",
            ],
        )

    def test_agents_keep_the_rules_but_not_the_find_docs_skills(self):
        claude_skill = self.base / ".claude/skills/find-docs"
        shared_skill = self.base / ".agents/skills/find-docs"
        result = self.run_sysup()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertFalse(claude_skill.exists())
        self.assertFalse(shared_skill.exists())
        self.assertTrue((self.base / ".claude/rules/context7.md").exists())

    def test_find_docs_is_kept_while_its_rule_is_missing(self):
        # Setup can fail or time out before writing a rule; the skill is then the only copy.
        claude_skill = self.base / ".claude/skills/find-docs"
        shared_skill = self.base / ".agents/skills/find-docs"
        # An empty rule file stands for one a killed setup left behind.
        for missing, empty_file, kept, removed in (
            ("claude", False, claude_skill, shared_skill),
            ("claude", True, claude_skill, shared_skill),
            ("codex", False, shared_skill, claude_skill),
            ("opencode", False, shared_skill, claude_skill),
        ):
            with self.subTest(missing=missing, empty_file=empty_file):
                for path in (".claude", ".agents", ".codex", ".config"):
                    shutil.rmtree(self.base / path, ignore_errors=True)
                if empty_file:
                    rule = self.base / ".claude/rules/context7.md"
                    rule.parent.mkdir(parents=True)
                    rule.touch()
                result = self.run_sysup(CTX7_NO_RULE=missing)
                self.assertEqual(
                    result.returncode, 0, result.stdout + result.stderr
                )
                self.assertTrue(kept.exists())
                self.assertFalse(removed.exists())

    def test_find_docs_is_kept_when_the_refresh_is_skipped(self):
        skills = (
            self.base / ".claude/skills/find-docs",
            self.base / ".agents/skills/find-docs",
        )
        for skill in skills:
            skill.mkdir(parents=True)
        result = self.run_sysup(CTX7_FAIL_ON="--version", CTX7_STATUS="5")
        self.assert_one_ctx7_warning_and_no_refresh(
            result, "ctx7 version check failed (exit 5); see the output above"
        )
        for skill in skills:
            self.assertTrue(skill.exists())

    def test_newer_ctx7_on_npm_is_installed_before_the_refresh(self):
        result = self.run_sysup(NPM_VERSION="1.1.0")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("    ctx7 1.0.0 -> 1.1.0", result.stdout.splitlines())
        self.assertEqual(
            self.calls(),
            [
                "gh skill update --all gh",
                "ctx7 --version",
                "npm view ctx7 version",
                "npm install -g ctx7@1.1.0",
                "ctx7 setup --cli --yes --claude",
                "ctx7 setup --cli --yes --opencode",
                "ctx7 setup --cli --yes --codex",
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
        self.assertIn("ctx7 --version", self.calls())

    def assert_one_ctx7_warning_and_no_refresh(self, result, note):
        lines = result.stdout.rstrip().splitlines()
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertEqual(
            lines[-2:], [f"!! {note}", "==> sysup finished with warnings"]
        )
        self.assertIn(
            "    skipping the ctx7 rule refresh; "
            "the version check or install did not finish",
            lines,
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

    def test_missing_ctx7_is_one_warning_and_skips_the_refresh(self):
        result = self.run_sysup(CTX7_FAIL_ON="--version", CTX7_STATUS="127")
        self.assert_one_ctx7_warning_and_no_refresh(
            result, "ctx7 version check failed (exit 127); see the output above"
        )
        self.assertNotIn("npm view ctx7 version", self.calls())

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
