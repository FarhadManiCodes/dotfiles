"""Regression tests for the substantive bugs found in the 2026-09-19 reviews of
virtualenv.zsh: exact-match checks that used to be substrings, a hardcoded path
that used to be a variable, argument shapes that used to be misparsed, and names
that used to resolve outside $CENTRAL_VENVS.

Fixes sharing another's code path need no test of their own: vl()'s local-venv
check is vr()'s basename comparison, and vc()'s rejection of "a/b" is the same
_is_valid_name predicate that stops vr() deleting outside $CENTRAL_VENVS.

    python3 -B -m unittest discover -s tests -v
"""
import os
from pathlib import Path
import shutil
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

    def stub(self, name, body):
        (self.bin / name).write_text(body)
        (self.bin / name).chmod(0o755)

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

    def test_get_envrc_env_reads_central_and_local_activate_lines(self):
        # CENTRAL_VENVS here deliberately does not end in ".central_venvs".
        envrc = self.root / ".envrc"
        for body, expected in (
            (f"source {self.central}/myapp/bin/activate", "myapp"),
            ("source .venv/bin/activate", "local"),
            ("source ./.venv/bin/activate", "local"),
            ("layout python", ""),
        ):
            envrc.write_text(body + "\n")
            result = self.run_zsh(f'_get_envrc_env "{envrc}"')
            self.assertEqual(result.stdout.strip(), expected, f"{body}: {result.stderr}")

    def stub_uv_and_direnv(self):
        """A uv that logs its arguments and fakes a venv, and a no-op direnv."""
        self.stub("uv",
                  '#!/bin/sh\n'
                  'printf "%s\\n" "$*" >> "$UV_LOG"\n'
                  '[ "$1" = venv ] && mkdir -p "$2/bin" && : > "$2/bin/activate"\n')
        self.stub("direnv", "#!/bin/sh\nexit 0\n")
        self.env["UV_LOG"] = str(self.root / "uv.log")
        project = self.root / "project"
        project.mkdir()
        return project

    def test_arguments_are_classified_by_type_not_position(self):
        """The positional ladder this replaced needed a branch per argument shape
        and misparsed two of them: "name version" silently used the default
        Python, and a lone version became the environment NAME."""
        project = self.stub_uv_and_direnv()
        log = self.root / "uv.log"
        for args, stdin, expected in (
            ("myapp 3.12", "", "myapp --python 3.12"),
            ("3.12", "proj\n", "proj --python 3.12"),
            ("ds myapp", "", "myapp --python 3.13"),   # order is free now
        ):
            with self.subTest(args=args):
                shutil.rmtree(self.central, ignore_errors=True)
                log.write_text("")
                result = self.run_zsh(f"vc {args}", cwd=project, stdin=stdin)
                self.assertNotIn("Unknown template", result.stdout)
                self.assertIn(f"venv {self.central}/{expected}", log.read_text(),
                              result.stdout + result.stderr)

    def test_vr_refuses_a_name_that_escapes_central_venvs(self):
        # _env_path builds "$CENTRAL_VENVS/$name", so "../decoy" pointed vr's
        # `rm -rf` at a sibling of the central directory.
        self.central.mkdir()
        decoy = self.root / "decoy"
        decoy.mkdir()
        (decoy / "keep").write_text("precious")
        result = self.run_zsh("vr ../decoy", stdin="y\n")
        self.assertTrue((decoy / "keep").exists(), result.stdout + result.stderr)
        self.assertIn("not found", result.stdout)


if __name__ == "__main__":
    unittest.main()
