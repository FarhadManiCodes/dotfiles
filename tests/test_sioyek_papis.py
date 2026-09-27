"""sioyek-papis: what Alt+p in sioyek does with a selection.

    python3 -B -m unittest discover -s tests -v

The script runs for real against a throwaway papis library, with real yq, awk
and jq. papis, curl, fuzzel, sioyek and notify-send are fakes on a private PATH
that log how they were called; nothing touches the network or the real library.
"""
import os
from pathlib import Path
import subprocess
import tempfile
import time
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "bash/sioyek-papis"


class SioyekPapisTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory(prefix="sioyek-papis-test-")
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.papers = self.root / ".local/share/papis/papers"
        self.log = {n: self.root / f"{n}.log" for n in ("notify", "sioyek", "papis", "curl", "fuzzel")}
        self.fake("notify-send", f'printf "%s\\n" "$2" >> {self.log["notify"]}')
        self.fake("sioyek", f'printf "%s\\n" "$*" >> {self.log["sioyek"]}')
        # papis add prints $PAPIS_OUT and exits $PAPIS_RC.
        self.fake("papis", f'printf "%s\\n" "$*" >> {self.log["papis"]}\n'
                           'printf "%s" "${PAPIS_OUT:-}"; exit "${PAPIS_RC:-0}"')
        # curl prints $CURL_OUT, or fails the way an offline curl -sS does.
        self.fake("curl", f'for a; do printf "%s\\n" "$a"; done >> {self.log["curl"]}\n'
                          '[ -n "${CURL_OUT:-}" ] || { echo "curl: (6) Could not resolve host" >&2; exit 6; }\n'
                          'printf "%s" "$CURL_OUT"')
        # fuzzel shows its menu in the log and picks line $PICK (1-based) with
        # --accept-nth=1; unset PICK is ESC.
        self.fake("fuzzel", f'cat >> {self.log["fuzzel"]}\n'
                            '[ -n "${PICK:-}" ] || exit 1\n'
                            f'sed -n "${{PICK}}p" {self.log["fuzzel"]} | cut -f1')
        # Pinned, not inherited: fakes shadow the real tools, /usr/bin has yq/awk/jq.
        self.env = {"PATH": f"{self.bin}:/usr/bin", "HOME": str(self.root), "LC_ALL": "C.UTF-8"}
        self.paper("smith-2020", doi="10.1103/PhysRevLett.1.2345", title="Physics-informed learning")
        self.paper("lee-2026", eprint="2602.23859v2", title="Shielded agents")

    def fake(self, name, body):
        path = self.bin / name
        path.write_text(f"#!/bin/sh\n{body}\n")
        path.chmod(0o755)

    def paper(self, folder, files=("paper.pdf",), **fields):
        d = self.papers / folder
        d.mkdir(parents=True)
        # Written before the PDF, so a directory listing would offer it first.
        (d / "paper.md").write_text("")
        for f in files:
            (d / f).write_text("")
        yaml = "".join(f"{k}: '{v}'\n" for k, v in fields.items())
        yaml += f"ref: {folder}\n" + ("files:\n" + "".join(f"- {f}\n" for f in files) if files else "")
        (d / "info.yaml").write_text(yaml)
        return d

    def run_script(self, *args, **env):
        proc = subprocess.run(["bash", str(SCRIPT), *args], env={**self.env, **env},
                              capture_output=True, text=True, timeout=10)
        self.assertIn(proc.returncode, (0, 1), proc.stderr)
        return proc

    def read(self, name):
        path = self.log[name]
        return path.read_text() if path.exists() else ""

    def opened(self):
        # sioyek is started in the background; give it a moment to log.
        deadline = time.monotonic() + 5
        while not self.read("sioyek") and time.monotonic() < deadline:
            time.sleep(0.05)
        return self.read("sioyek")

    def test_empty_selection_says_so(self):
        self.run_script(" \n\t")
        self.assertEqual(self.read("notify"), "Empty selection\n")

    def test_doi_in_library_opens_the_recorded_file_not_the_first_listed(self):
        # Split across a PDF line break, with trailing punctuation.
        self.run_script("doi:10.1103/PhysRev", "Lett.1.2345).")
        self.assertEqual(self.opened(), f"--new-window {self.papers}/smith-2020/paper.pdf\n")
        self.assertEqual(self.read("papis"), "")

    def test_entry_without_a_file_says_so(self):
        self.paper("bare-2021", files=(), doi="10.1000/bare")
        self.run_script("10.1000/bare")
        self.assertEqual(self.read("notify"), "Entry is in the library but has no attached file\n")

    def test_bare_doi_prefix_asks_for_the_full_doi(self):
        self.run_script("10.1103/")
        self.assertEqual(self.read("notify"), "Incomplete DOI; select the full DOI\n")
        self.assertEqual(self.read("fuzzel") + self.read("papis"), "")

    def test_new_doi_is_added(self):
        self.run_script("10.1000/new.123")
        self.assertEqual(self.read("papis"), "add --from doi 10.1000/new.123 --no-edit --batch\n")
        self.assertEqual(self.read("notify"), "Added to papis: 10.1000/new.123\n")

    def test_duplicate_papis_refuses_is_not_reported_as_added(self):
        # papis matched it on another unique key; --batch refuses but exits 0.
        self.run_script("10.1000/new.123",
                        PAPIS_OUT="WARNING|No new document is created! Add this document in ...")
        self.assertEqual(self.read("notify"), "Already in papis, not added: 10.1000/new.123\n")

    def test_failed_add_reports_papis_last_line(self):
        self.run_script("10.1000/new.123", PAPIS_OUT="noise\nERROR|No importer found", PAPIS_RC="1")
        self.assertEqual(self.read("notify"), "papis add failed: ERROR|No importer found\n")

    def test_arxiv_id_in_library_opens_it_without_adding(self):
        self.run_script("arXiv:2602.23859")
        self.assertEqual(self.opened(), f"--new-window {self.papers}/lee-2026/paper.pdf\n")
        self.assertEqual(self.read("papis"), "")

    def test_broken_info_yaml_is_reported_not_treated_as_absent(self):
        (self.papers / "aaa-broken").mkdir()
        (self.papers / "aaa-broken/info.yaml").write_text('title: "unclosed\n')
        self.run_script("10.1103/PhysRevLett.1.2345")
        self.assertIn("Library scan failed", self.read("notify"))
        self.assertIn("aaa-broken/info.yaml", self.read("notify"))
        self.assertEqual(self.read("papis") + self.read("sioyek"), "")

    def test_title_matches_are_offered_and_esc_does_nothing(self):
        self.paper("jones-2021", title="Physics informed operators")
        self.run_script("physics", "informed")
        menu = self.read("fuzzel").splitlines()
        self.assertEqual(sorted(line.split("\t")[1] for line in menu),
                         ["jones-2021 | Physics informed operators",
                          "smith-2020 | Physics-informed learning"])
        self.assertEqual(self.read("notify") + self.read("sioyek"), "")

    def test_offline_crossref_is_not_reported_as_no_match(self):
        self.run_script("Some", "unknown", "title")
        self.assertEqual(self.read("notify"),
                         "Crossref request failed: curl: (6) Could not resolve host\n")

    def test_crossref_query_is_passed_verbatim_and_pick_is_added(self):
        text = """it's "$HOME" & #1 + `x`"""
        crossref = ('{"message":{"items":[{"DOI":"10.1000/a","title":["A\\n\\ttitle"],'
                    '"issued":{"date-parts":[[2020]]}}]}}')
        self.run_script(*text.split(), CURL_OUT=crossref, PICK="1")
        self.assertIn(f"query.bibliographic={text}\n", self.read("curl"))
        self.assertEqual(self.read("fuzzel"), "10.1000/a\tA title — 2020 — 10.1000/a\n")
        self.assertEqual(self.read("papis"), "add --from doi 10.1000/a --no-edit --batch\n")

    def test_crossref_with_no_items_says_no_match(self):
        self.run_script("Nothing", "here", CURL_OUT='{"message":{"items":[]}}')
        self.assertEqual(self.read("notify"), "No Crossref match for: Nothing here\n")


if __name__ == "__main__":
    unittest.main()
