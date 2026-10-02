"""sioyek-papis: what Alt+p in sioyek does with a selection.

    python3 -B -m unittest discover -s tests -v

The script runs for real against a throwaway papis library, with real yq, awk
and jq. papis, curl, fuzzel, sioyek and notify-send are fakes on a private PATH
that log how they were called; nothing touches the network or the real library.
"""
import json
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
        self.log = {n: self.root / f"{n}.log" for n in ("notify", "sioyek", "papis", "curl", "stdin", "fuzzel")}
        self.fake("notify-send", f'printf "%s\\n" "$2" >> {self.log["notify"]}')
        self.fake("sioyek", f'printf "%s\\n" "$*" >> {self.log["sioyek"]}')
        # papis add prints $PAPIS_OUT and exits $PAPIS_RC.
        self.fake("papis", f'printf "%s\\n" "$*" >> {self.log["papis"]}\n'
                           'printf "%s" "${PAPIS_OUT:-}"; exit "${PAPIS_RC:-0}"')
        # curl prints $CURL_OUT (Crossref) or $OPENALEX_OUT, or fails the way an offline
        # curl -sS does. Headers sent with -H @- arrive on stdin and are logged apart
        # from the arguments, as the real key must never appear among those.
        self.fake("curl", f'for a; do printf "%s\\n" "$a"; done >> {self.log["curl"]}\n'
                          f'case " $* " in *" @- "*) cat >> {self.log["stdin"]};; esac\n'
                          'offline() { echo "curl: (6) Could not resolve host" >&2; exit 6; }\n'
                          'case " $* " in *api.openalex.org*)\n'
                          '    [ -n "${OPENALEX_OUT:-}" ] || offline; printf "%s" "$OPENALEX_OUT"; exit 0;;\n'
                          'esac\n'
                          '[ -n "${CURL_OUT:-}" ] || offline\n'
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


    # ---- citations.json beside the open PDF ---------------------------------
    def host(self, references=None, markers=None):
        """The paper being read: a PDF with refinery's citations.json beside it."""
        d = self.papers / "host-2024"
        if not d.exists():
            self.paper("host-2024", title="The paper being read")
        refs = references or [
            {"number": "1", "citation_key": "[1]", "title": "Physics-informed learning", "year": 2020,
             "authors": [{"family": "Smith"}], "doi": "10.1103/PhysRevLett.1.2345"},
            {"number": "2", "citation_key": "[2]", "title": "Shielded   agents", "year": 2026,
             "authors": [{"family": "Lee"}]},
            {"number": "3", "citation_key": "[3]", "title": "Unknown operators", "year": 2019,
             "authors": [{"family": "Novak"}], "doi": "10.1000/novak"},
            {"number": "4", "citation_key": "[4]", "title": "No doi paper", "year": 2018,
             "authors": [{"family": "Brown"}]},
        ]
        marks = markers or [{"text": "[3]", "refs": [2]}, {"text": "[1,3]", "refs": [0, 2]}]
        (d / "paper.citations.json").write_text(json.dumps(
            {"references": refs, "linking": {"markers": marks}}))
        return str(d / "paper.pdf")

    def select(self, text, pdf=None, **env):
        return self.run_script("--file", pdf or self.host(), text, **env)

    def test_marker_for_a_reference_in_the_library_opens_it_offline(self):
        self.select("[1]")
        self.assertEqual(self.opened(), f"--new-window {self.papers}/smith-2020/paper.pdf\n")
        self.assertEqual(self.read("papis") + self.read("curl") + self.read("fuzzel"), "")

    def test_marker_for_a_reference_not_in_the_library_adds_it_by_doi(self):
        self.select("[3]")
        self.assertEqual(self.read("papis"), "add --from doi 10.1000/novak --no-edit --batch\n")
        self.assertEqual(self.read("curl"), "")

    def test_reference_without_doi_is_found_in_the_library_by_title(self):
        self.select("[2]")
        self.assertEqual(self.opened(), f"--new-window {self.papers}/lee-2026/paper.pdf\n")
        self.assertEqual(self.read("curl"), "")

    def test_reference_without_doi_searches_crossref_by_title_author_year(self):
        self.select("[4]", CURL_OUT='{"message":{"items":[]}}')
        self.assertIn("query.bibliographic=No doi paper Brown 2018\n", self.read("curl"))

    def test_reference_whose_preprint_is_in_the_library_opens_it_not_adds_a_duplicate(self):
        # The library holds the arXiv version (no doi); the reference prints the published doi.
        self.paper("alshiekh-2017", eprint="1708.08611", title="Safe RL via Shielding")
        pdf = self.host(references=[{"number": "1", "citation_key": "[1]", "title": "Safe RL via shielding",
                                     "year": 2018, "authors": [{"family": "Alshiekh"}],
                                     "doi": "10.1609/aaai.v32i1.11797"}], markers=[])
        self.select("[1]", pdf)
        self.assertEqual(self.opened(), f"--new-window {self.papers}/alshiekh-2017/paper.pdf\n")
        self.assertEqual(self.read("papis"), "")

    def test_reference_title_must_equal_a_library_title_not_sit_inside_one(self):
        self.paper("long-2021", title="Shielded agents in the wild")
        self.select("[2]", CURL_OUT='{"message":{"items":[]}}')   # "Shielded agents" is lee-2026's, exactly
        self.assertEqual(self.opened(), f"--new-window {self.papers}/lee-2026/paper.pdf\n")
        pdf = self.host(references=[{"number": "1", "title": "Shielded", "year": 2020,
                                     "authors": [{"family": "Kay"}]}], markers=[])
        self.select("[1]", pdf, CURL_OUT='{"message":{"items":[]}}')
        self.assertIn("query.bibliographic=Shielded Kay 2020\n", self.read("curl"))

    def test_range_is_offered_with_printed_labels_and_library_marks(self):
        self.select("[1-3]", PICK="3")
        self.assertEqual([line.split("\t", 1)[1] for line in self.read("fuzzel").splitlines()],
                         ["[1] Smith 2020 — Physics-informed learning  ✓",
                          "[2] Lee 2026 — Shielded agents  ✓",
                          "[3] Novak 2019 — Unknown operators"])
        self.assertEqual(self.read("papis"), "add --from doi 10.1000/novak --no-edit --batch\n")

    def test_marker_split_over_a_line_break_is_the_same_marker(self):
        self.select("[1,\n 3]", PICK="1")
        self.assertEqual(len(self.read("fuzzel").splitlines()), 2)
        self.assertEqual(self.opened(), f"--new-window {self.papers}/smith-2020/paper.pdf\n")

    def test_esc_in_the_reference_menu_does_nothing(self):
        self.select("[1,3]")
        self.assertEqual(self.read("notify") + self.read("sioyek") + self.read("papis"), "")

    def test_author_year_resolves_through_the_references(self):
        self.select("(Novak et al., 2019)")
        self.assertEqual(self.read("papis"), "add --from doi 10.1000/novak --no-edit --batch\n")

    def test_several_author_year_pieces_share_one_menu(self):
        self.select("(Smith and Jones, 2020; Novak et al., 2019)", PICK="2")
        self.assertEqual(len(self.read("fuzzel").splitlines()), 2)
        self.assertEqual(self.read("papis"), "add --from doi 10.1000/novak --no-edit --batch\n")

    def test_no_match_in_citations_falls_back_to_the_text_search(self):
        self.select("Some unknown title", CURL_OUT='{"message":{"items":[]}}')
        self.assertIn("query.bibliographic=Some unknown title\n", self.read("curl"))

    def test_missing_citations_file_keeps_todays_behaviour(self):
        pdf = str(self.paper("bare-2022") / "paper.pdf")
        self.run_script("--file", pdf, "[1]", CURL_OUT='{"message":{"items":[]}}')
        self.assertIn("query.bibliographic=[1]\n", self.read("curl"))

    def test_doi_in_the_selection_wins_over_citations(self):
        self.select("10.1000/new.123")
        self.assertEqual(self.read("papis"), "add --from doi 10.1000/new.123 --no-edit --batch\n")

    # ---- OpenAlex, the backup ------------------------------------------------
    KEY = "sekret-key-123"
    OPENALEX = ('{"results":[{"doi":"https://doi.org/10.1000/oa","title":"Open  result",'
                '"publication_year":2021},{"doi":null,"title":"No doi","publication_year":2020}]}')

    def give_key(self):
        secrets = self.root / ".config/paper-refinery/secrets"
        secrets.mkdir(parents=True)
        (secrets / "openalex.env").write_text(f"OPENALEX_API_KEY={self.KEY}\n")

    def test_openalex_is_asked_when_crossref_has_nothing_and_the_key_stays_off_argv(self):
        self.give_key()
        self.run_script("Some", "title", CURL_OUT='{"message":{"items":[]}}',
                        OPENALEX_OUT=self.OPENALEX, PICK="1")
        self.assertEqual(self.read("fuzzel"), "10.1000/oa\tOpen result — 2021 — 10.1000/oa\n")
        self.assertEqual(self.read("papis"), "add --from doi 10.1000/oa --no-edit --batch\n")
        self.assertIn(f"Authorization: Bearer {self.KEY}", self.read("stdin"))
        self.assertNotIn(self.KEY, self.read("curl") + self.read("notify"))

    def test_openalex_is_asked_when_crossref_is_unreachable(self):
        self.give_key()
        self.run_script("Some", "title", OPENALEX_OUT=self.OPENALEX, PICK="1")
        self.assertEqual(self.read("papis"), "add --from doi 10.1000/oa --no-edit --batch\n")

    def test_openalex_is_not_asked_when_crossref_has_hits(self):
        self.give_key()
        self.run_script("Some", "title", OPENALEX_OUT=self.OPENALEX, PICK="1",
                        CURL_OUT='{"message":{"items":[{"DOI":"10.1000/a","title":["A"]}]}}')
        self.assertNotIn("openalex", self.read("curl"))

    def test_nothing_from_either_provider_says_so(self):
        self.give_key()
        self.run_script("Nothing", "here", CURL_OUT='{"message":{"items":[]}}',
                        OPENALEX_OUT='{"results":[]}')
        self.assertEqual(self.read("notify"), "No Crossref or OpenAlex match for: Nothing here\n")

    def test_without_a_key_openalex_is_skipped_silently(self):
        self.run_script("Some", "title", OPENALEX_OUT=self.OPENALEX)
        self.assertNotIn("openalex", self.read("curl"))
        self.assertEqual(self.read("notify"),
                         "Crossref request failed: curl: (6) Could not resolve host\n")


if __name__ == "__main__":
    unittest.main()
