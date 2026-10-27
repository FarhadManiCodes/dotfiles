"""Check how ptpython and IPython read foot's theme state file.

    python3 -B -m unittest discover -s tests

Neither package is installed for the system Python, so ptpython's config is
loaded with its two imports faked and the IPython startup file is run with a
fake `get_ipython`. Each case points HOME at a directory holding the state file.
"""

import importlib.util
import os
from pathlib import Path
import sys
import tempfile
import types
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[1]
PTPYTHON = ROOT / "ptpython/config.py"
IPYTHON = ROOT / "ipython/profile_default/startup/01-theme.py"

# The state file is written by bash/toggle-foot-theme.sh; the bytes are not
# UTF-8, as after a truncated or corrupted write.
NOT_UTF8 = b"\xff\xfe\x00"


class StateFile(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory(prefix="theme-state-test-")
        self.addCleanup(temp.cleanup)
        self.home = Path(temp.name)
        patch = mock.patch.dict(os.environ, {"HOME": str(self.home)})
        patch.start()
        self.addCleanup(patch.stop)

    def write(self, content):
        state = self.home / ".local/state/foot_theme_state"
        state.parent.mkdir(parents=True, exist_ok=True)
        state.write_bytes(content)


class Ptpython(StateFile):
    def theme(self):
        fakes = {
            "prompt_toolkit": types.ModuleType("prompt_toolkit"),
            "prompt_toolkit.styles": types.ModuleType("prompt_toolkit.styles"),
            "ptpython": types.ModuleType("ptpython"),
            "ptpython.layout": types.ModuleType("ptpython.layout"),
        }
        fakes["prompt_toolkit.styles"].Style = object
        fakes["ptpython.layout"].CompletionVisualisation = object
        spec = importlib.util.spec_from_file_location("ptconfig", PTPYTHON)
        module = importlib.util.module_from_spec(spec)
        with mock.patch.dict(sys.modules, fakes):
            spec.loader.exec_module(module)
        return module._detect_foot_theme()

    def test_follows_the_state_file(self):
        self.write(b"light\n")
        self.assertEqual(self.theme(), "papercolor")

    def test_a_missing_state_file_gives_the_dark_theme(self):
        self.assertEqual(self.theme(), "onedark")

    def test_a_state_file_that_is_not_utf8_gives_the_dark_theme(self):
        self.write(NOT_UTF8)
        self.assertEqual(self.theme(), "onedark")


class Ipython(StateFile):
    def settings(self):
        shell = types.SimpleNamespace()
        exec(  # noqa: S102 - the startup file, run as IPython runs it
            compile(IPYTHON.read_text(), str(IPYTHON), "exec"),
            {"get_ipython": lambda: shell},
        )
        return shell.colors, shell.highlighting_style

    def test_follows_the_state_file(self):
        self.write(b"light\n")
        self.assertEqual(self.settings(), ("LightBG", "pastie"))

    def test_a_missing_state_file_gives_the_dark_theme(self):
        self.assertEqual(self.settings(), ("Linux", "one-dark"))

    def test_a_state_file_that_is_not_utf8_gives_the_dark_theme(self):
        self.write(NOT_UTF8)
        self.assertEqual(self.settings(), ("Linux", "one-dark"))


if __name__ == "__main__":
    unittest.main()
