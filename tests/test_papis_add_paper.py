"""papis-add-paper: what `,p` in Firefox does with a DOI or arXiv id.

    python3 -B -m unittest discover -s tests -v

The script runs for real against a throwaway papis library, with real yq, awk
and jq. papis, curl, footclient (the key/tags prompt) and notify-send are fakes
on a private PATH; the fake prompt answers with $KEY and $TAGS, and the fake
papis creates the entry the way `papis add --set ref` would.
"""
from pathlib import Path
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "bash/papis-add-paper"


class PapisAddPaperTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory(prefix="papis-add-paper-test-")
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.papers = self.root / ".local/share/papis/papers"
        self.log = self.root / "log"
        self.entry("smith", "ref: Smith_2020\ndoi: '10.1103/PhysRevLett.1.2345'\ntags:\n- control\n")
        self.entry("lee", "ref: Lee_2026\neprint: 2602.23859v2\n")
        self.fake("notify-send", 'echo "notify: $*" >> "$LOG"')
        self.fake("curl", "exit 6")  # offline: the key suggestion falls back to the identifier
        self.fake("footclient", 'echo "prompt" >> "$LOG"; for a; do last=$a; done\n'
                                '[ -n "$FC_RC" ] && exit "$FC_RC"\n'
                                'printf "%s\\n%s" "$KEY" "$TAGS" > "$last"')
        self.fake("papis", 'echo "papis $*" >> "$LOG"\n'
                           'case "$PAPIS_MODE" in\n'
                           '  dup) echo "WARNING|No new document is created! ..."; exit 0 ;;\n'
                           '  fail) echo "ERROR|No importer found"; exit 1 ;;\n'
                           'esac\n'
                           'for a; do [ "$prev" = ref ] && ref=$a; prev=$a; done\n'
                           'd="$HOME/.local/share/papis/papers/new"; mkdir -p "$d"\n'
                           'printf "ref: %s\\nfiles:\\n- p.pdf\\n" "$ref" > "$d/info.yaml"')
        # Pinned, not inherited: the fakes shadow the real tools.
        self.env = {"PATH": f"{self.bin}:/usr/bin", "HOME": str(self.root), "LC_ALL": "C.UTF-8",
                    "LOG": str(self.log), "KEY": "Typed_2020", "TAGS": ""}

    def fake(self, name, body):
        path = self.bin / name
        path.write_text(f"#!/bin/sh\n{body}\n")
        path.chmod(0o755)

    def entry(self, folder, yaml):
        d = self.papers / folder
        d.mkdir(parents=True)
        (d / "info.yaml").write_text(yaml)

    def run_script(self, importer, identifier, **env):
        return subprocess.run(["bash", str(SCRIPT), importer], input=identifier,
                              env={**self.env, **env}, capture_output=True,
                              text=True, timeout=20).returncode

    def logged(self):
        return self.log.read_text() if self.log.exists() else ""

    def notices(self):
        return [l for l in self.logged().splitlines() if l.startswith("notify:")]

    def test_doi_already_in_library_skips_the_prompt(self):
        self.assertEqual(self.run_script("doi", "10.1103/physrevlett.1.2345"), 0)
        self.assertIn("Already in papis as Smith_2020", self.logged())
        self.assertNotIn("prompt", self.logged())
        self.assertNotIn("papis add", self.logged())

    def test_arxiv_id_matches_a_stored_version(self):
        self.run_script("arxiv", "2602.23859")
        self.assertIn("Already in papis as Lee_2026", self.logged())
        self.assertNotIn("papis add", self.logged())

    def test_new_paper_is_added_with_tags_as_a_list(self):
        self.assertEqual(self.run_script("doi", "10.1000/new", TAGS="sciml  book"), 0)
        self.assertIn("papis add --from doi 10.1000/new --no-edit --batch --set ref Typed_2020",
                      self.logged())
        info = (self.papers / "new/info.yaml").read_text()
        self.assertIn("tags:\n  - sciml\n  - book\n", info)
        self.assertIn("Added with PDF", self.notices()[-1])

    def test_duplicate_papis_refuses_is_not_reported_as_added(self):
        self.run_script("doi", "10.1000/new", PAPIS_MODE="dup")
        self.assertIn("Already in papis (matched on another field), not added", self.notices()[-1])

    def test_failed_add_reports_papis_last_line(self):
        self.assertEqual(self.run_script("doi", "10.1000/new", PAPIS_MODE="fail"), 1)
        self.assertIn("ERROR|No importer found", self.notices()[-1])

    def test_broken_info_yaml_stops_before_the_prompt(self):
        self.entry("aaa-broken", 'title: "unclosed\n')
        self.assertEqual(self.run_script("doi", "10.1000/new"), 1)
        self.assertIn("Library scan failed", self.logged())
        self.assertIn("aaa-broken/info.yaml", self.logged())
        self.assertNotIn("prompt", self.logged())

    def test_prompt_window_that_cannot_open_is_not_a_cancel(self):
        self.assertEqual(self.run_script("doi", "10.1000/new", FC_RC="220"), 1)
        self.assertIn("Could not open the prompt window", self.notices()[-1])

    def test_ctrl_c_or_empty_key_cancels_quietly(self):
        for env in ({"FC_RC": "130"}, {"KEY": ""}):
            self.log.unlink(missing_ok=True)
            self.assertEqual(self.run_script("doi", "10.1000/new", **env), 0)
            self.assertIn("Cancelled", self.notices()[-1])
            self.assertNotIn("papis add", self.logged())

    def test_an_entry_with_plain_string_tags_does_not_block_adding(self):
        # `papis --set tags x` or a hand edit writes a string, not a list.
        self.entry("plain", "ref: Plain_2019\ntags: control-theory\n")
        self.assertEqual(self.run_script("doi", "10.1000/new"), 0)
        self.assertNotIn("Library scan failed", self.logged())
        self.assertIn("Added with PDF", self.notices()[-1])

    def test_suggested_key_skips_taken_ones(self):
        # Offline, the suggestion is the sanitised identifier; a taken key gets a/b/...
        self.entry("taken", "ref: 10_1000_new\n")
        self.fake("footclient", 'printf "%s\\n" "$8" >> "$LOG.prefill"; for a; do last=$a; done\n'
                                'printf "\\n" > "$last"')
        self.run_script("doi", "10.1000/new")
        self.assertEqual(Path(f"{self.log}.prefill").read_text(), "10_1000_newa\n")


if __name__ == "__main__":
    unittest.main()
