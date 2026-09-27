"""papis-fuzzel: the papis picker behind Mod+Shift+P and Mod+z (--books).

    python3 -B -m unittest discover -s tests -v

The script runs for real against a throwaway papis library with real yq and
awk. fuzzel, xdg-open, papis and notify-send are fakes on a private PATH; the
fake fuzzel records the menu and picks the line matching $PICK.
"""
from pathlib import Path
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "bash/papis-fuzzel"


class PapisFuzzelTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory(prefix="papis-fuzzel-test-")
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.papers = self.root / ".local/share/papis/papers"
        self.log = self.root / "log"
        self.menu = self.root / "menu"
        self.entry("smith", "ref: Smith_2020\nyear: 2020\nauthor: Smith\ntitle: Control notes\n"
                            "files:\n- paper.pdf\ntags:\n- control\n- sciml\n")
        self.entry("nocedal", "ref: Nocedal_2006\nyear: 2006\nauthor: Nocedal\n"
                              "title: Numerical Optimization\nfiles:\n- book.pdf\ntags: book\n")
        self.entry("web", "ref: Web_2021\nyear: 2021\nauthor: Web\ntitle: No file here\n")
        self.fake("fuzzel", f'cat > {self.menu}; [ -n "$PICK" ] || exit 1\n'
                            f'grep -m1 -- "$PICK" {self.menu} | cut -f1')
        for name in ("xdg-open", "papis", "notify-send"):
            self.fake(name, f'echo "{name} $*" >> {self.log}')
        self.fake("setsid", 'shift; exec "$@"')  # setsid -f <cmd>
        # Pinned, not inherited: the fakes shadow the real tools.
        self.env = {"PATH": f"{self.bin}:/usr/bin", "HOME": str(self.root), "LC_ALL": "C.UTF-8"}

    def fake(self, name, body):
        path = self.bin / name
        path.write_text(f"#!/bin/sh\n{body}\n")
        path.chmod(0o755)

    def entry(self, folder, yaml):
        d = self.papers / folder
        d.mkdir(parents=True)
        (d / "info.yaml").write_text(yaml)

    def run_script(self, *args, **env):
        return subprocess.run(["bash", str(SCRIPT), *args], env={**self.env, **env},
                              capture_output=True, text=True, timeout=10).returncode

    def labels(self):
        return [line.split("\t", 1)[1] for line in self.menu.read_text().splitlines()]

    def logged(self):
        return self.log.read_text() if self.log.exists() else ""

    def test_menu_lists_every_entry_with_tags_as_words(self):
        self.run_script()
        labels = self.labels()
        self.assertEqual(len(labels), 3)
        self.assertTrue(any("Control notes" in l and l.endswith("#control #sciml") for l in labels))
        # A plain-string tags field (a hand edit, `papis --set tags x`) is read as is.
        self.assertTrue(any("Numerical Optimization" in l and l.endswith("#book") for l in labels))
        self.assertTrue(any("No file here" in l and "↗" in l for l in labels))

    def test_books_view_lists_only_entries_tagged_book(self):
        self.run_script("--books")
        self.assertEqual(len(self.labels()), 1)
        self.assertIn("Numerical Optimization", self.labels()[0])

    def test_pick_opens_the_recorded_file(self):
        self.run_script(PICK="Control notes")
        self.assertEqual(self.logged(), f"xdg-open {self.papers}/smith/paper.pdf\n")

    def test_entry_without_a_file_opens_in_the_browser(self):
        self.run_script(PICK="No file here")
        self.assertEqual(self.logged(), "papis browse ref:Web_2021\n")

    def test_broken_info_yaml_is_reported(self):
        self.entry("aaa-broken", 'title: "unclosed\n')
        self.assertEqual(self.run_script(), 1)
        self.assertIn("Library scan failed", self.logged())


if __name__ == "__main__":
    unittest.main()
