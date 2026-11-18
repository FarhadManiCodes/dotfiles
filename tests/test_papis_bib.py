"""papis-bib: the compile-hook sync never loses entries from a .bib.

    python3 -B -m unittest discover -s tests -v

papis is a fake on a private PATH: each `papis bibtex ... save -f FILE` writes
$OUT to FILE, so a test chooses what the library returns, and logs its
arguments to $LOG. How papis merges is papis's own logic; tested is what
papis-bib then does to the .bib.
"""

from pathlib import Path
import subprocess
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / "bash/papis-bib"


def entries(*keys):
    return "".join(f"@article{{{k},\n  title = {{{k}}},\n}}\n" for k in keys)


class PapisBibSyncTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory(prefix="papis-bib-test-")
        self.addCleanup(temp.cleanup)
        root = Path(temp.name)
        bindir = root / "bin"
        bindir.mkdir()
        for name, body in {
            "papis": 'echo "$*" >> "$LOG"\n'
            '[ -n "$FAIL" ] && { echo "ERROR|cannot read" >&2; exit 1; }\n'
            'for a; do [ "$prev" = save ] && s=1\n'
            '  [ -n "$s" ] && [ "$prev" = -f ] && out=$a; prev=$a; done\n'
            'printf "%s" "$OUT" > "$out"',
            "notify-send": "exit 0",
        }.items():
            (bindir / name).write_text(f"#!/bin/sh\n{body}\n")
            (bindir / name).chmod(0o755)
        self.project = root / "paper"
        self.project.mkdir()
        (self.project / "main.tex").write_text("\\addbibresource{refs.bib}\n")
        self.bib = self.project / "refs.bib"
        self.bib.write_text(entries("A", "B"))
        self.log = root / "log"
        # Pinned, not inherited: the fakes shadow the real tools.
        self.env = {
            "PATH": f"{bindir}:/usr/bin",
            "HOME": str(root),
            "LC_ALL": "C.UTF-8",
            "LOG": str(self.log),
        }

    def sync(self, **env):
        return subprocess.run(
            ["bash", str(SCRIPT), str(self.project)],
            env={**self.env, **env},
            check=False,
            capture_output=True,
            text=True,
            timeout=10,
        )

    def test_new_citation_is_added(self):
        result = self.sync(OUT=entries("A", "B", "C"))
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertEqual(self.bib.read_text(), entries("A", "B", "C"))
        # The existing .bib is read first into the union: papis keeps the
        # first copy of a key, so hand-edited entries win over the library's.
        self.assertIn(f"bibtex read {self.bib} read ", self.log.read_text())

    def test_fewer_entries_are_refused(self):
        result = self.sync(OUT=entries("A"))
        self.assertEqual(result.returncode, 1)
        self.assertIn("REFUSING", result.stdout)
        self.assertEqual(self.bib.read_text(), entries("A", "B"))

    def test_papis_failure_leaves_the_bib(self):
        result = self.sync(FAIL="1", OUT="")
        self.assertEqual(result.returncode, 1)
        self.assertEqual(self.bib.read_text(), entries("A", "B"))


if __name__ == "__main__":
    unittest.main()
