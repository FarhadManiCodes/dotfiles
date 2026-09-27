"""sioyek-papis-note: what Alt+n / Alt+N in sioyek write and open.

    python3 -B -m unittest discover -s tests -v

The script runs for real against a throwaway papis document folder. papis,
footclient and notify-send are fakes on a private PATH; the fake papis does what
`papis edit --notes --editor true` does (create the file, add the `notes:` key).
That the real papis still does so, and that papis-ask strips what is written
here, is checked end to end by ~/learning/playground/sioyek-papis-notes/run.sh.
"""
from pathlib import Path
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "bash/sioyek-papis-note"


class SioyekPapisNoteTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory(prefix="sioyek-papis-note-test-")
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.doc = self.root / "papers/smith-2020"
        self.doc.mkdir(parents=True)
        (self.doc / "info.yaml").write_text("ref: smith-2020\n")
        self.pdf = self.doc / "paper.pdf"
        self.notes = self.doc / "notes.md"
        self.log = {n: self.root / f"{n}.log" for n in ("notify", "papis", "editor")}
        self.fake("notify-send", f'printf "%s\\n" "$4" >> {self.log["notify"]}')
        self.fake("footclient", f'printf "%s\\n" "$*" >> {self.log["editor"]}')
        self.fake("papis", f'printf "%s\\n" "$*" >> {self.log["papis"]}\n'
                           'touch "$3/notes.md" && echo "notes: notes.md" >> "$3/info.yaml"')
        config = self.root / ".config/papis/config"
        config.parent.mkdir(parents=True)
        config.write_text("[settings]\nnotes-name = notes.md\n")
        # Pinned, not inherited: the fakes shadow the real tools.
        self.env = {"PATH": f"{self.bin}:/usr/bin", "HOME": str(self.root), "LC_ALL": "C.UTF-8"}

    def fake(self, name, body):
        path = self.bin / name
        path.write_text(f"#!/bin/sh\n{body}\n")
        path.chmod(0o755)

    def run_script(self, *args):
        return subprocess.run(["bash", str(SCRIPT), *args], env=self.env,
                              capture_output=True, text=True, timeout=10).returncode

    def read(self, name):
        path = self.log[name]
        return path.read_text() if path.exists() else ""

    def today(self):
        return subprocess.run(["date", "+%F"], capture_output=True, text=True).stdout.strip()

    def test_first_capture_registers_the_note_and_quotes_the_selection(self):
        self.assertEqual(self.run_script(str(self.pdf), "6", "812.5", "a passage\nover two lines"), 0)
        self.assertEqual(self.read("papis"),
                         f"edit --doc-folder {self.doc} --notes --editor true\n")
        self.assertEqual(self.notes.read_text(),
                         f"## p.7 — {self.today()}\n"          # 0-based 6 is the page the reader sees as 7
                         "<!--sioyek page=7 offset_y=812.5-->\n"
                         "\n<!--quote-->\n> a passage\n> over two lines\n<!--/quote-->\n\n")
        self.assertEqual(self.read("editor"), f"--app-id papis-note nvim +$ {self.notes}\n")

    def test_later_capture_skips_papis_and_writes_no_empty_quote(self):
        self.run_script(str(self.pdf), "0", "1", "first")
        before = self.notes.read_text()
        self.run_script(str(self.pdf), "not-a-number", "2", "")
        self.assertEqual(len(self.read("papis").splitlines()), 1, "papis ran again")
        self.assertEqual(self.notes.read_text(),
                         before + f"\n## p.? — {self.today()}\n<!--sioyek page=? offset_y=2-->\n\n")

    def test_pdf_outside_the_library_is_refused_without_a_stray_note(self):
        outside = self.root / "downloads/paper.pdf"
        outside.parent.mkdir()
        self.assertEqual(self.run_script(str(outside), "0", "0", "x"), 1)
        self.assertEqual(self.read("notify"), "not a papis document: paper.pdf\n")
        self.assertEqual(list(outside.parent.iterdir()), [])
        self.assertEqual(self.read("papis") + self.read("editor"), "")

    def test_papis_failure_is_reported(self):
        self.fake("papis", "exit 1")
        self.assertEqual(self.run_script(str(self.pdf), "0", "0", "x"), 1)
        self.assertEqual(self.read("notify"), "papis could not create the note\n")
        self.assertEqual(self.read("editor"), "")

    def test_open_without_notes_creates_nothing(self):
        self.assertEqual(self.run_script("--open", str(self.pdf)), 0)
        self.assertIn("no notes yet for smith-2020", self.read("notify"))
        self.assertFalse(self.notes.exists())
        self.assertEqual(self.read("papis") + self.read("editor"), "")

    def test_open_reads_existing_notes_from_the_top(self):
        self.run_script(str(self.pdf), "0", "0", "x")
        before = self.notes.read_text()
        self.log["editor"].unlink()
        self.assertEqual(self.run_script("--open", str(self.pdf)), 0)
        self.assertEqual(self.read("editor"), f"--app-id papis-note nvim +1 {self.notes}\n")
        self.assertEqual(self.notes.read_text(), before)


if __name__ == "__main__":
    unittest.main()
