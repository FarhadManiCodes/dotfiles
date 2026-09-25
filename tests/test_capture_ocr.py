"""capture-ocr: one instance at a time, and the two modes behind Mod+Print / Mod+Shift+Print.

    python3 -B -m unittest discover -s tests -v

SingleInstanceTests run the script for real against fake slurp/notify-send on a
private PATH; slurp exiting 1 is the user pressing ESC, so none reaches grim or
the network. ModeTests run main() in-process with fake binaries and a fake
Gemini response, so they can see which prompt was sent.
"""
import importlib.machinery
import importlib.util
import io
import json
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import time
import unittest
from unittest import mock


SCRIPT = Path(__file__).resolve().parents[1] / "bash/capture-ocr"


class SingleInstanceTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory(prefix="capture-ocr-test-")
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.slurp_log = self.root / "slurp.log"
        self.notify_log = self.root / "notify.log"
        self.block = self.root / "block"
        self.fake("notify-send", f'echo "$*" >> {self.notify_log}')
        # Parked while the flag file exists, the way an open region selector is.
        # The flag is checked before logging, so once the log shows a call it has parked.
        self.fake("slurp", f"if [ -e {self.block} ]; then echo called >> {self.slurp_log}; "
                           f"exec /usr/bin/sleep 30; fi\necho called >> {self.slurp_log}\nexit 1")
        # Pinned, not inherited: only the fakes are on PATH.
        self.env = {"PATH": str(self.bin), "HOME": str(self.root),
                    "XDG_RUNTIME_DIR": str(self.root), "GOOGLE_API_KEY": "unused"}

    def fake(self, name, body):
        path = self.bin / name
        path.write_text(f"#!/bin/sh\n{body}\n")
        path.chmod(0o755)

    def slurp_calls(self):
        return len(self.slurp_log.read_text().splitlines()) if self.slurp_log.exists() else 0

    def start(self):
        proc = subprocess.Popen([sys.executable, "-B", str(SCRIPT)], env=self.env,
                                start_new_session=True,
                                stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        self.addCleanup(self.kill, proc)
        return proc

    def kill(self, proc):
        # The whole group, even after the script exits: its slurp may still be running.
        try:
            os.killpg(proc.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
        proc.communicate()

    def run_once(self):
        proc = self.start()
        out, err = proc.communicate(timeout=10)
        return proc.returncode, err.decode()

    def start_blocked(self):
        """A first run parked inside slurp."""
        self.block.touch()
        first = self.start()
        deadline = time.monotonic() + 10
        while self.slurp_calls() == 0:
            self.assertIsNone(first.poll(), "first run exited before reaching slurp")
            self.assertLess(time.monotonic(), deadline, "first run never reached slurp")
            time.sleep(0.05)
        self.block.unlink()
        return first

    def test_lone_run_reaches_selection(self):
        # Baseline: without it, the tests below would pass on a script that never selects.
        code, err = self.run_once()
        self.assertEqual((code, err), (0, ""))
        self.assertEqual(self.slurp_calls(), 1)

    def test_unusable_runtime_dir_runs_unlocked(self):
        # Set but missing: an unlocked run, not a traceback nobody sees.
        self.env["XDG_RUNTIME_DIR"] = str(self.root / "missing")
        code, err = self.run_once()
        self.assertEqual((code, err), (0, ""))
        self.assertEqual(self.slurp_calls(), 1)

    def test_second_run_during_first_only_says_so(self):
        first = self.start_blocked()
        code, err = self.run_once()
        self.assertEqual((code, err), (0, ""))
        self.assertEqual(self.slurp_calls(), 1, "second run opened another selector")
        self.assertIn("Already running", self.notify_log.read_text())
        self.assertIsNone(first.poll(), "first run should be left alone")

    def test_crashed_run_does_not_leave_a_stale_lock(self):
        # Only the script dies; its slurp lives on, as wl-copy's daemon outlives a normal run.
        # A lock inherited by a child would still be held, and the next run would do nothing.
        first = self.start_blocked()
        first.send_signal(signal.SIGKILL)
        first.wait()
        code, err = self.run_once()
        self.assertEqual((code, err), (0, ""))
        self.assertEqual(self.slurp_calls(), 2)


def load_script():
    loader = importlib.machinery.SourceFileLoader("capture_ocr", str(SCRIPT))
    module = importlib.util.module_from_spec(
        importlib.util.spec_from_loader("capture_ocr", loader))
    loader.exec_module(module)
    return module


class ModeTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory(prefix="capture-ocr-test-")
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name)
        bin_ = self.root / "bin"
        bin_.mkdir()
        self.slurp_log = self.root / "slurp.log"
        self.notify_log = self.root / "notify.log"
        self.clipboard = self.root / "clipboard"
        for name, body in [
                ("slurp", f"echo called >> {self.slurp_log}\necho '0,0 10x10'"),
                ("grim", "printf PNG"),
                ("wl-copy", f"/usr/bin/cat > {self.clipboard}"),
                ("notify-send", f'printf "%s\\n" "$*" >> {self.notify_log}')]:
            (bin_ / name).write_text(f"#!/bin/sh\n{body}\n")
            (bin_ / name).chmod(0o755)
        patcher = mock.patch.dict(os.environ, {"PATH": str(bin_), "HOME": str(self.root),
                                               "GOOGLE_API_KEY": "unused"}, clear=True)
        patcher.start()
        self.addCleanup(patcher.stop)
        self.ocr = load_script()
        self.ocr.single_instance = lambda: None  # covered by SingleInstanceTests
        self.sent = []

    def gemini(self, text, finish="STOP"):
        """Fake urlopen answering every request with `text`."""
        def urlopen(req, timeout):
            self.sent.append(json.loads(req.data))
            return io.BytesIO(json.dumps({"candidates": [{
                "content": {"parts": [{"text": text}]}, "finishReason": finish}]}).encode())
        return mock.patch.object(self.ocr.urllib.request, "urlopen", urlopen)

    def run_main(self, *args):
        with mock.patch.object(sys, "argv", ["capture-ocr", *args]):
            try:
                self.ocr.main()
                return 0
            except SystemExit as e:
                return e.code

    def prompt_sent(self):
        return self.sent[0]["contents"][0]["parts"][1]["text"]

    def test_default_transcribes(self):
        with self.gemini("Anfahrt"):
            self.assertEqual(self.run_main(), 0)
        self.assertEqual(self.prompt_sent(), self.ocr.OCR_PROMPT)
        self.assertEqual(self.clipboard.read_text(), "Anfahrt")
        self.assertIn("OCR Copied", self.notify_log.read_text())
        self.assertIn("Extracting text", self.notify_log.read_text())

    def test_translate_flag_translates(self):
        with self.gemini("Directions"):
            self.assertEqual(self.run_main("--translate"), 0)
        self.assertEqual(self.prompt_sent(), self.ocr.TRANSLATE_PROMPT)
        self.assertEqual(self.clipboard.read_text(), "Directions")
        self.assertIn("Translation Copied", self.notify_log.read_text())
        self.assertIn("Translating text", self.notify_log.read_text())

    def test_truncated_translation_says_so(self):
        with self.gemini("Direc", finish="MAX_TOKENS"):
            self.assertEqual(self.run_main("--translate"), 0)
        self.assertIn("Translation Copied - TRUNCATED", self.notify_log.read_text())

    def test_prompts_share_rules_and_hold_no_escapes(self):
        # A plain string once turned the rules' "\\tag" into a tab.
        for prompt in (self.ocr.OCR_PROMPT, self.ocr.TRANSLATE_PROMPT):
            self.assertTrue(prompt.endswith(self.ocr.RULES))
            self.assertNotIn("\t", prompt)
            self.assertIn("\\tag{...}", prompt)

    def test_lone_illegible_marker_is_no_text(self):
        with self.gemini(" [illegible]\n[illegible] "):
            self.assertEqual(self.run_main(), 0)
        self.assertFalse(self.clipboard.exists())
        self.assertIn("No text found", self.notify_log.read_text())

    def test_illegible_marker_inside_text_is_kept(self):
        with self.gemini("See [illegible] page"):
            self.assertEqual(self.run_main(), 0)
        self.assertEqual(self.clipboard.read_text(), "See [illegible] page")

    def test_unknown_arguments_fail_visibly_before_selecting(self):
        for args in (["--translte"], ["--translate", "junk"]):
            with self.subTest(args=args), self.gemini("unused"):
                self.assertEqual(self.run_main(*args), 1)
                self.assertIn(f"Unknown arguments: {' '.join(args)}",
                              self.notify_log.read_text())
        self.assertFalse(self.slurp_log.exists())
        self.assertEqual(self.sent, [])


if __name__ == "__main__":
    unittest.main()
