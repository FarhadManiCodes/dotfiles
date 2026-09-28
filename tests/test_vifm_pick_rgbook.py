"""Exercise both rgbook callers with a private papis library and fake fzf/viewer."""

import json
from pathlib import Path
import re
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
ANSI = re.compile(r"\033\[[0-9;]*m")

FAKE_FZF = r'''#!/usr/bin/python3
import json
import os
from pathlib import Path
import re
import shlex
import subprocess
import sys

args = sys.argv[1:]
binds = [args[i + 1] for i, arg in enumerate(args[:-1]) if arg == "--bind"]
reload = next((item.removeprefix("start:reload:") for item in binds
               if item.startswith("start:reload:")), None)
preview = args[args.index("--preview") + 1]
query = os.environ["TEST_QUERY"]
if reload:
    command = reload.replace("{q}", shlex.quote(query))
    result = subprocess.run(["/bin/sh", "-c", command], capture_output=True, text=True)
    rows = result.stdout.splitlines()
else:
    result = None
    rows = sys.stdin.read().splitlines()
pick = os.environ.get("TEST_PICK", "")
selected = next((row for row in rows if pick and pick in re.sub(r"\x1b\[[0-9;]*m", "", row)), "")
preview_result = None
if selected:
    preview_command = preview.replace("{q}", shlex.quote(query)).replace(
        "{1}", shlex.quote(selected.split("\t", 1)[0])).replace(
        "{}", shlex.quote(selected))
    preview_result = subprocess.run(["/bin/sh", "-c", preview_command],
                                    capture_output=True, text=True)
Path(os.environ["FZF_LOG"]).write_text(json.dumps({
    "reload": reload, "preview": preview, "rows": rows,
    "stderr": result.stderr if result else "",
    "preview_output": preview_result.stdout if preview_result else None,
    "preview_stderr": preview_result.stderr if preview_result else None,
}))
if selected:
    key = os.environ.get("TEST_KEY", "")
    if key == "ctrl-d" and os.environ.get("TEST_CALLER") == "vifm":
        Path(os.environ["XDG_RUNTIME_DIR"], "vifm-pick", "cd").touch()
    if key and os.environ.get("TEST_CALLER") == "zsh":
        print(key)
    print(selected)

'''


class RgbookTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory(prefix="rgbook-test-")
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name)
        self.library = self.root / "papers'archive"
        self.library.mkdir()
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.fzf_log = self.root / "fzf.json"
        self.open_log = self.root / "open.log"
        self.vifm_log = self.root / "vifm.log"
        (self.bin / "fzf").write_text(FAKE_FZF)
        (self.bin / "fzf").chmod(0o755)
        (self.bin / "setsid").write_text(
            '#!/bin/sh\nshift\nprintf "%s\\n" "$@" > "$OPEN_LOG"\n'
        )
        (self.bin / "setsid").chmod(0o755)
        (self.bin / "sioyek").write_text(
            '#!/bin/sh\n{ printf "sioyek\\n"; printf "%s\\n" "$@"; } > "$OPEN_LOG"\n'
        )
        (self.bin / "sioyek").chmod(0o755)
        (self.bin / "pdf-meta").write_text(
            '#!/bin/sh\n[ "$PDF_META_FAIL" = 1 ] && exit 1\n'
            'if [ "$1" = preview ]; then\n'
            '  case "$2" in *.pdf) printf "Title: Sample\\nAuthor: Ada\\nPages: 3\\n" ;; *) exit 1 ;; esac\n'
            'else\n'
            '  case "$3" in 1) echo 186.000 ;; 2) echo 279.000 ;; 3) echo 421.000 ;; *) exit 1 ;; esac\n'
            'fi\n'
        )
        (self.bin / "pdf-meta").chmod(0o755)
        (self.bin / "vifm").write_text(
            '#!/bin/sh\nprintf "%s\\n" "$@" > "$VIFM_LOG"\n'
        )
        (self.bin / "vifm").chmod(0o755)
        self.alpha = self.library / "alpha/alpha.pdf"
        self.beta = self.library / "beta/beta.pdf"
        for pdf in (self.alpha, self.beta):
            pdf.parent.mkdir()
            pdf.touch()
        (self.alpha.with_suffix(".md")).write_text(
            "<page_number>1</page_number>\n"
            "Theorem 3: optimal start\n"
            "<page_number>2</page_number>\n"
            "optimal: first occurrence\n"
            "another optimal: on the same page\n"
            + ("prefix " * 90) + "DeepNeedle: after a colon " + ("suffix " * 90) + "\n"
        )
        (self.beta.with_suffix(".md")).write_text(
            "<page_number>3</page_number>\nOptimal conclusion\n"
        )
        (self.alpha.parent / "notes.md").write_text("<page_number>1</page_number>\nnotes-only\n")
        work = self.library / "unready/unready.refinery"
        work.mkdir(parents=True)
        (work / "refinery.md").write_text("<page_number>10</page_number>\nwork-only\n")
        self.env = {
            "PATH": f"{self.bin}:/usr/bin", "HOME": str(self.root),
            "LC_ALL": "C.UTF-8", "NO_COLOR": "", "RIPGREP_CONFIG_PATH": "/dev/null",
            "FZF_DEFAULT_OPTS": "", "PAPIS_PAPERS": str(self.library),
            "XDG_RUNTIME_DIR": str(self.root), "FZF_LOG": str(self.fzf_log),
            "OPEN_LOG": str(self.open_log), "VIFM_LOG": str(self.vifm_log),
            "PDF_META_FAIL": "0",
            "SCRIPT": str(ROOT / "zsh/functions/pdf.zsh"),
        }

    def run_caller(self, caller, query, pick="", key="", picker="rgbook"):
        env = dict(self.env, TEST_CALLER=caller, TEST_QUERY=query,
                   TEST_PICK=pick, TEST_KEY=key)
        if caller == "zsh":
            command = '''source "$SCRIPT"
_fzf_split() {
  if [[ "$1" == *$'\\n'* ]]; then
    key="${1%%$'\\n'*}"; selection="${1#*$'\\n'}"
  else
    key=""; selection="$1"
  fi
}
"$TEST_PICKER" "$TEST_QUERY"
wait
pwd > "$PWD_LOG"
'''
            env["PWD_LOG"] = str(self.root / "pwd.log")
            argv = ["zsh", "-f", "-c", command]
        else:
            argv = ["bash", str(ROOT / "bash/vifm-pick"), picker]
        env["TEST_PICKER"] = picker
        result = subprocess.run(argv, env=env, cwd=self.root,
                                capture_output=True, text=True, timeout=15)
        self.assertEqual(result.returncode, 0, result.stderr)
        data = json.loads(self.fzf_log.read_text())
        self.assertEqual(data["stderr"], "")
        return data, [ANSI.sub("", row) for row in data["rows"]]

    def test_search_page_dedup_colons_and_pdf_selection(self):
        for caller in ("zsh", "vifm"):
            with self.subTest(caller=caller):
                data, rows = self.run_caller(caller, "optimal", "alpha.pdf:Page 2")
                self.assertEqual(len(rows), 3)
                self.assertTrue(any("alpha.pdf:Page 1:Theorem 3: optimal start" in x for x in rows))
                self.assertEqual(sum("alpha.pdf:Page 2:" in x for x in rows), 1)
                self.assertTrue(any("beta.pdf:Page 3:" in x for x in rows))
                self.assertEqual(self.open_log.read_text().splitlines(),
                                 ["sioyek", "--page", "2", "--yloc", "279.000", str(self.alpha)])
                self.open_log.unlink()
                self.assertIn("rg --smart-case --context 3", data["preview"])
                self.assertIn("optimal", data["preview_output"].lower())
                self.assertEqual(data["preview_stderr"], "")

    def test_long_snippet_keeps_deep_match_in_view(self):
        for caller in ("zsh", "vifm"):
            with self.subTest(caller=caller):
                _, rows = self.run_caller(caller, "DeepNeedle", "alpha.pdf")
                self.assertEqual(len(rows), 1)
                self.assertIn("…", rows[0])
                self.assertIn("DeepNeedle: after a colon", rows[0])
                self.assertLess(len(rows[0]), 300)
                self.assertEqual(self.open_log.read_text().splitlines()[-2:],
                                 ["279.000", str(self.alpha)])
                self.open_log.unlink()

    def test_selected_page_geometry_and_helper_fallback(self):
        for caller in ("zsh", "vifm"):
            with self.subTest(caller=caller):
                self.run_caller(caller, "Optimal", "beta.pdf:Page 3")
                self.assertEqual(self.open_log.read_text().splitlines(),
                                 ["sioyek", "--page", "3", "--yloc", "421.000", str(self.beta)])
                self.open_log.unlink()
                self.env["PDF_META_FAIL"] = "1"
                self.run_caller(caller, "optimal", "alpha.pdf:Page 1")
                self.assertEqual(self.open_log.read_text().splitlines(),
                                 ["sioyek", "--page", "1", str(self.alpha)])
                self.open_log.unlink()
                self.env["PDF_META_FAIL"] = "0"

    def test_fbook_previews_use_shared_helper(self):
        for caller in ("zsh", "vifm"):
            with self.subTest(caller=caller):
                data, _ = self.run_caller(caller, "alpha", "alpha.pdf", picker="fbook")
                self.assertIn('pdf-meta preview "$SP/"{}', data["preview"])
                self.assertEqual(data["preview_output"],
                                 "Title: Sample\nAuthor: Ada\nPages: 3\n")
                self.assertEqual(self.open_log.read_text().splitlines()[-1], str(self.alpha))
                self.open_log.unlink()
        self.assertIn("fileviewer *.pdf pdf-meta preview %c", (ROOT / "vifm/vifmrc").read_text())

    def test_smart_case_empty_invalid_and_excluded_files(self):
        for caller in ("zsh", "vifm"):
            with self.subTest(caller=caller):
                _, rows = self.run_caller(caller, "Optimal")
                self.assertEqual(len(rows), 1)
                self.assertIn("beta.pdf:Page 3:", rows[0])
                for query in ("", "[", "notes-only", "work-only"):
                    _, rows = self.run_caller(caller, query)
                    self.assertEqual(rows, [], query)

    def test_navigation_keys(self):
        self.run_caller("zsh", "optimal", "alpha.pdf:Page 1", "ctrl-d")
        self.assertEqual((self.root / "pwd.log").read_text().strip(), str(self.alpha.parent))
        self.assertFalse(self.open_log.exists())
        self.run_caller("zsh", "optimal", "alpha.pdf:Page 1", "ctrl-o")
        self.assertEqual(self.vifm_log.read_text().strip(), str(self.alpha.parent))
        self.run_caller("vifm", "optimal", "alpha.pdf:Page 1", "ctrl-d")
        exchange = self.root / "vifm-pick"
        self.assertEqual((exchange / "action").read_text(), "cd")
        self.assertEqual((exchange / "path").read_text(), str(self.alpha.parent))
        self.assertFalse(self.open_log.exists())

    def test_search_and_formatter_are_mirrored(self):
        zsh, _ = self.run_caller("zsh", "optimal")
        bash, _ = self.run_caller("vifm", "optimal")
        self.assertEqual(zsh["reload"], bash["reload"])
        self.assertEqual(zsh["preview"], bash["preview"])


if __name__ == "__main__":
    unittest.main()
