"""papis-bib: the compile-hook sync never loses entries from a .bib.

    python3 -B -m unittest discover -s tests -v

papis is a fake on a private PATH: each `papis bibtex ... save -f FILE` writes
$OUT to FILE, so a test chooses what the library returns, and logs its
arguments to $LOG. How papis merges is papis's own logic; tested is what
papis-bib then does to the .bib.
"""

import os
from pathlib import Path
import shlex
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
            'case "$*" in *filter-cited*) if [ -n "$CITED" ]; then\n'
            '  printf "%s" "$CITED" > "$out"\n'
            '  [ -n "$UNREADABLE" ] && rm "$out"; exit 0; fi ;;\n'
            '  *update*) [ -n "$UPDATED" ] && OUT=$UPDATED ;; esac\n'
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
        self.tmp = root / "tmp"
        self.tmp.mkdir()
        # Pinned, not inherited: the fakes shadow the real tools.
        self.env = {
            "PATH": f"{bindir}:/usr/bin",
            "HOME": str(root),
            "LC_ALL": "C.UTF-8",
            "LOG": str(self.log),
            "TMPDIR": str(self.tmp),
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

    def prune(self, answers, **env):
        # --prune needs a terminal: script(1) gives it one and relays answers.
        return subprocess.run(
            [
                "script",
                "-qec",
                shlex.join(["bash", str(SCRIPT), "--prune", str(self.project)]),
                "/dev/null",
            ],
            env={**self.env, **env},
            input=answers,
            check=False,
            capture_output=True,
            text=True,
            timeout=10,
        )

    def test_prune_removes_an_uncited_entry(self):
        result = self.prune("y\n", OUT=entries("A", "B"), CITED=entries("A"))
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertIn("  - B", result.stdout)
        self.assertIn("Remove 1 entry (uncited)?", result.stdout)
        self.assertIn("wrote refs.bib (", result.stdout)
        self.assertEqual(self.bib.read_text(), entries("A"))

    def test_prune_stops_when_the_cited_list_is_unreadable(self):
        # Read as empty, it would offer every entry as uncited.
        result = self.prune(
            "y\n", OUT=entries("A", "B"), CITED=entries("A"), UNREADABLE="1"
        )
        self.assertEqual(result.returncode, 1, result.stdout)
        self.assertIn("cannot read papis's output for refs.bib", result.stdout)
        self.assertNotIn("Uncited entries", result.stdout)
        self.assertEqual(self.bib.read_text(), entries("A", "B"))

    def test_prune_updates_an_entry_that_differs(self):
        library = entries("A") + "@article{B,\n  title = {B, revised},\n}\n"
        result = self.prune(
            "y\n",
            OUT=entries("A", "B"),
            CITED=entries("A", "B"),
            UPDATED=library,
        )
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertIn("  - B", result.stdout)
        self.assertNotIn("  - A", result.stdout)
        self.assertIn("Update 1 entry from the library?", result.stdout)
        self.assertEqual(self.bib.read_text(), library)

    def test_new_citation_is_added(self):
        result = self.sync(OUT=entries("A", "B", "C"))
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertEqual(self.bib.read_text(), entries("A", "B", "C"))
        # The existing .bib is read first into the union: papis keeps the
        # first copy of a key, so hand-edited entries win over the library's.
        self.assertIn(f"bibtex read {self.bib} read ", self.log.read_text())

    def test_sync_keeps_the_bib_mode(self):
        self.bib.chmod(0o644)
        self.sync(OUT=entries("A", "B", "C"))
        self.assertEqual(self.bib.stat().st_mode & 0o777, 0o644)

    @unittest.skipIf(os.geteuid() == 0, "root can write a read-only file")
    def test_read_only_bib_is_left_unchanged(self):
        self.bib.chmod(0o444)
        result = self.sync(OUT=entries("A", "B", "C"))
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertIn("refs.bib is read-only, left unchanged", result.stdout)
        self.assertEqual(self.bib.read_text(), entries("A", "B"))
        self.assertEqual(self.bib.stat().st_mode & 0o777, 0o444)

    def test_sync_writes_through_a_symlinked_bib(self):
        shared = self.project.parent / "shared.bib"
        shared.write_text(entries("A", "B"))
        self.bib.unlink()
        self.bib.symlink_to(shared)
        self.sync(OUT=entries("A", "B", "C"))
        self.assertTrue(self.bib.is_symlink())
        self.assertEqual(shared.read_text(), entries("A", "B", "C"))

    def test_fewer_entries_are_refused(self):
        result = self.sync(OUT=entries("A"))
        self.assertEqual(result.returncode, 1)
        self.assertIn("REFUSING", result.stdout)
        self.assertEqual(self.bib.read_text(), entries("A", "B"))

    def test_papis_failure_leaves_the_bib(self):
        result = self.sync(FAIL="1", OUT="")
        self.assertEqual(result.returncode, 1)
        self.assertEqual(self.bib.read_text(), entries("A", "B"))

    def test_no_temporary_file_is_left(self):
        # Synced, refused, and failed runs; the .bib's own staging file too.
        for env in (
            {"OUT": entries("A", "B", "C")},
            {"OUT": entries("A")},
            {"FAIL": "1", "OUT": ""},
        ):
            with self.subTest(env=env):
                self.sync(**env)
                self.assertEqual(list(self.tmp.iterdir()), [])
                self.assertEqual(
                    sorted(p.name for p in self.project.iterdir()),
                    ["main.tex", "refs.bib"],
                )


if __name__ == "__main__":
    unittest.main()
