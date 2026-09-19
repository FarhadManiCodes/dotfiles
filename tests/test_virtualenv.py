"""Regression tests for the three substantive bugs found in a 2026-09-19 review
of virtualenv.zsh: exact-match checks that used to be substrings, and a hardcoded
path that used to be a variable. vl()'s local-venv check shares vr()'s fix and
needs no separate test.

    python3 -B -m unittest discover -s tests -v
"""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

SOURCE = Path(__file__).resolve().parents[1] / "zsh/functions/virtualenv.zsh"


class VirtualenvTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="virtualenv-test-")
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.central = self.root / "central"
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.env = dict(
            os.environ, PATH=f"{self.bin}:/usr/bin:/bin",
            HOME=str(self.root), CENTRAL_VENVS=str(self.central),
        )

    def run_zsh(self, script, cwd=None, stdin=""):
        return subprocess.run(
            ["zsh", "-f", "-c", 'source "$1"; ' + script, "test", str(SOURCE)],
            cwd=cwd, env=self.env, input=stdin,
            capture_output=True, text=True, timeout=10,
        )

    def test_vr_does_not_deactivate_an_unrelated_environment(self):
        # "myapp" is a substring of "myapp2" -- removing the former must not
        # tear down an active session of the latter.
        (self.central / "myapp").mkdir(parents=True)
        (self.central / "myapp2").mkdir()
        self.env["VIRTUAL_ENV"] = str(self.central / "myapp2")
        result = self.run_zsh('deactivate() { echo DEACTIVATED; }; vr myapp',
                               stdin="y\n")
        self.assertNotIn("DEACTIVATED", result.stdout, result.stdout + result.stderr)
        self.assertFalse((self.central / "myapp").exists())
        self.assertTrue((self.central / "myapp2").exists())

    def test_get_envrc_env_follows_a_relocated_central_venvs(self):
        # CENTRAL_VENVS here deliberately does not end in ".central_venvs".
        envrc = self.root / ".envrc"
        envrc.write_text(f"source {self.central}/myapp/bin/activate\n")
        result = self.run_zsh(f'_get_envrc_env "{envrc}"')
        self.assertEqual(result.stdout.strip(), "myapp", result.stderr)

    def test_name_plus_version_is_not_treated_as_a_template(self):
        (self.bin / "uv").write_text(
            '#!/bin/sh\n'
            'printf "%s\\n" "$*" >> "$UV_LOG"\n'
            '[ "$1" = venv ] && mkdir -p "$2/bin" && : > "$2/bin/activate"\n'
        )
        (self.bin / "uv").chmod(0o755)
        (self.bin / "direnv").write_text("#!/bin/sh\nexit 0\n")
        (self.bin / "direnv").chmod(0o755)
        self.env["UV_LOG"] = str(self.root / "uv.log")
        project = self.root / "project"
        project.mkdir()
        result = self.run_zsh("vc myapp 3.12", cwd=project)
        self.assertNotIn("Unknown template", result.stdout, result.stdout)
        log = (self.root / "uv.log").read_text()
        self.assertIn(f"venv {self.central}/myapp --python 3.12", log)


if __name__ == "__main__":
    unittest.main()
