"""Run the real bash/check-skills against temporary checkouts of fixture skills.

    python3 -B -m unittest discover -s tests

Covers what the runner depends on: absent or empty input fails rather than
reporting a clean run, a real defect is still named when nothing else was
asserted, and the checkout is located from the script rather than from $PWD.
"""
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest


SOURCE = Path(__file__).resolve().parents[1] / "bash/check-skills"
ANSI = re.compile(r"\033\[[0-9;]*m")

VALID = """---
name: {name}
description: >
  Do the fixture thing. Use when a test needs a skill that passes every
  assertion in check-skills without depending on the real skills directory.
---

# Fixture

Body text.
"""


class CheckSkillsTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="check-skills-test-")
        self.addCleanup(self.tmp.cleanup)
        self.base = Path(self.tmp.name)
        self.checkout = self.base / "dotfiles"
        (self.checkout / "bash").mkdir(parents=True)
        self.script = self.checkout / "bash/check-skills"
        shutil.copy(SOURCE, self.script)

    def skill(self, name, body=None):
        path = self.checkout / "skills" / name
        path.mkdir(parents=True)
        (path / "SKILL.md").write_text(body if body is not None else VALID.format(name=name))
        return path

    def run_script(self, command=None, cwd=None):
        result = subprocess.run(
            ["bash", str(command or self.script)],
            cwd=str(cwd or self.base), capture_output=True, text=True, timeout=30,
        )
        return result.returncode, ANSI.sub("", result.stdout + result.stderr)

    def test_valid_skill_passes(self):
        self.skill("fixture-skill")
        code, out = self.run_script()
        self.assertEqual(code, 0, out)
        self.assertIn("assertions passed", out)

    def test_absent_skills_directory_fails(self):
        code, out = self.run_script()
        self.assertEqual(code, 1)
        self.assertIn("no skills/ directory", out)

    def test_empty_skills_directory_is_not_a_pass(self):
        (self.checkout / "skills").mkdir()
        code, out = self.run_script()
        self.assertEqual(code, 1)
        self.assertNotIn("assertions passed", out)
        self.assertIn("no skills asserted", out)

    def test_defect_is_named_even_when_nothing_else_was_asserted(self):
        self.skill("fixture-skill", body="no frontmatter here\n")
        code, out = self.run_script()
        self.assertEqual(code, 1)
        self.assertIn("frontmatter fence", out)
        self.assertNotIn("no skills asserted", out)

    def test_description_without_a_trigger_fails(self):
        self.skill("fixture-skill", body=VALID.format(name="fixture-skill").replace("Use when", "Use before"))
        code, out = self.run_script()
        self.assertEqual(code, 1)
        self.assertIn("must state the trigger", out)

    def test_checkout_is_located_through_an_installed_symlink(self):
        self.skill("fixture-skill")
        bindir = self.base / "bin"
        bindir.mkdir()
        link = bindir / "check-skills"
        link.symlink_to(self.script)
        code, out = self.run_script(command=link, cwd=Path("/"))
        self.assertEqual(code, 0, out)
        self.assertIn("assertions passed", out)


if __name__ == "__main__":
    unittest.main()
