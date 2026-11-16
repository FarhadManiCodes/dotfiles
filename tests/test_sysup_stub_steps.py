"""tests/sysup-stub-steps.zsh names every default step of sysup.

    python3 -B -m unittest discover -s tests -v

The sysup tests source that file to turn every default step into a no-op. A
step missing from it would run for real inside those tests, so each `_sysup_*`
name `_sysup_steps` uses must be a stubbed step, a helper or variable, or an
opt-in step its own test asks for. A new name fails here until it is sorted.
"""

from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[1]
SYSUP = ROOT / "zsh/functions/sysup.zsh"
STUBS = ROOT / "tests/sysup-stub-steps.zsh"

HELPERS = {"_sysup_header", "_sysup_note", "_sysup_flush_notes"}
VARIABLES = {"_sysup_guard", "_sysup_notes", "_sysup_skipped", "_sysup_steps"}
OPT_IN = {"_sysup_tool_tests", "_sysup_podman_images"}


class SysupStubStepsTests(unittest.TestCase):
    def test_every_default_step_is_stubbed(self):
        text = SYSUP.read_text()
        body = re.search(r"^_sysup_steps\(\) \{\n(.*?)^\}", text, re.M | re.S)
        self.assertIsNotNone(body, "_sysup_steps() not found in sysup.zsh")
        used = set(re.findall(r"\b_sysup_[a-z_]+", body.group(1)))
        loop = re.search(r"for fn in (.*?); do", STUBS.read_text(), re.S)
        self.assertIsNotNone(loop, "no `for fn in ...; do` in the stub file")
        stubbed = set(loop.group(1).replace("\\", " ").split())
        self.assertEqual(used - HELPERS - VARIABLES - OPT_IN, stubbed)


if __name__ == "__main__":
    unittest.main()
