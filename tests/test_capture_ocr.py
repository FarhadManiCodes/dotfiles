"""capture-ocr: one instance at a time, and the two modes behind Mod+Print / Mod+Shift+Print.

    python3 -B -m unittest discover -s tests -v

SingleInstanceTests run the script for real against fake slurp/notify-send on a
private PATH; slurp exiting 1 is the user pressing ESC, so none reaches grim or
the network. ModeTests run main() in-process with fake binaries and a fake
Gemini response, so they can see which prompt was sent. OfflineFallbackTests
run the script for real with Gemini made unreachable (https_proxy at a closed
port) and a fake llama-server that serves the local API.
"""
import importlib.machinery
import importlib.util
import io
import json
import os
from pathlib import Path
import signal
import struct
import subprocess
import sys
import tempfile
import time
import unittest
from unittest import mock
import zlib


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

    def test_gemini_http_error_fails_without_falling_back(self):
        # HTTPError subclasses URLError: an HTTP answer means Gemini was reached,
        # and a quota error must not silently switch to the offline model.
        def urlopen(req, timeout):
            raise self.ocr.urllib.error.HTTPError(
                req.full_url, 429, "Too Many Requests", {},
                io.BytesIO(b'{"error": {"message": "quota"}}'))
        fallback = mock.Mock(return_value=("offline text", False))
        with mock.patch.object(self.ocr.urllib.request, "urlopen", urlopen), \
                mock.patch.object(self.ocr, "local_transcribe", fallback, create=True):
            self.assertEqual(self.run_main(), 1)
        self.assertIn("Gemini returned 429. quota", self.notify_log.read_text())
        fallback.assert_not_called()

    def test_unknown_arguments_fail_visibly_before_selecting(self):
        for args in (["--translte"], ["--translate", "junk"]):
            with self.subTest(args=args), self.gemini("unused"):
                self.assertEqual(self.run_main(*args), 1)
                self.assertIn(f"Unknown arguments: {' '.join(args)}",
                              self.notify_log.read_text())
        self.assertFalse(self.slurp_log.exists())
        self.assertEqual(self.sent, [])


FAKE_LLAMA_SERVER = """#!/usr/bin/python3
import http.server, json, os, sys, time
from pathlib import Path
out = Path(os.environ["FAKE_DIR"])
args = sys.argv[1:]
if "--cache-list" in args and os.environ.get("FAKE_MODE") == "broken":
    sys.exit(2)
if "--cache-list" in args:
    print("number of models in cache: 1\\n   1. " + os.environ.get("FAKE_CACHE", ""))
    sys.exit(0)
(out / "server.pid").write_text(str(os.getpid()))
(out / "argv.json").write_text(json.dumps(args))
if os.environ.get("FAKE_MODE") == "crash":
    print("load_model: failed to load model", file=sys.stderr)
    print("llama_server: exiting due to model loading error", file=sys.stderr)
    sys.exit(1)

class Handler(http.server.BaseHTTPRequestHandler):
    def log_message(self, *a):
        pass

    def reply(self, code, payload):
        body = json.dumps(payload).encode()
        self.send_response(code)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        self.reply(200 if self.path == "/health" else 404, {})

    def do_POST(self):
        if self.headers.get("Authorization") != "Bearer " + os.environ["LLAMA_API_KEY"]:
            return self.reply(401, {})
        n = int(self.headers["Content-Length"])
        (out / "request.json").write_bytes(self.rfile.read(n))
        if os.environ.get("FAKE_MODE") == "hang":
            time.sleep(60)
        if os.environ.get("FAKE_MODE") == "http500":
            body = b"boom: out of memory"
            self.send_response(500)
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            return self.wfile.write(body)
        if os.environ.get("FAKE_MODE") == "garbage":
            body = os.environ.get("FAKE_RAW", "not json").encode()
            self.send_response(200)
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            return self.wfile.write(body)
        self.reply(200, {"choices": [{"message": {"content": os.environ["FAKE_REPLY"]},
                                      "finish_reason": os.environ.get("FAKE_FINISH", "stop")}]})

port = int(args[args.index("--port") + 1])
http.server.HTTPServer(("127.0.0.1", port), Handler).serve_forever()
"""


def png(width, height):
    """A valid 1-bit grayscale PNG; only its IHDR size matters to the script."""
    def chunk(kind, data):
        return (struct.pack(">I", len(data)) + kind + data
                + struct.pack(">I", zlib.crc32(kind + data)))
    rows = b"".join(b"\0" + b"\0" * ((width + 7) // 8) for _ in range(height))
    return (b"\x89PNG\r\n\x1a\n"
            + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 1, 0, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(rows)) + chunk(b"IEND", b""))


class OfflineFallbackTests(unittest.TestCase):
    MODEL = "ggml-org/GLM-OCR-GGUF:Q8_0"

    def setUp(self):
        temp = tempfile.TemporaryDirectory(prefix="capture-ocr-test-")
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name)
        bin_ = self.root / "bin"
        bin_.mkdir()
        (self.root / "capture.png").write_bytes(png(300, 100))
        self.notify_log = self.root / "notify.log"
        self.clipboard = self.root / "clipboard"
        for name, body in [
                ("slurp", "echo '0,0 300x100'"),
                ("grim", f"exec /usr/bin/cat {self.root / 'capture.png'}"),
                ("wl-copy", f"exec /usr/bin/cat > {self.clipboard}"),
                ("notify-send", f'printf "%s\\n" "$*" >> {self.notify_log}')]:
            (bin_ / name).write_text(f"#!/bin/sh\n{body}\n")
            (bin_ / name).chmod(0o755)
        (bin_ / "llama-server").write_text(FAKE_LLAMA_SERVER)
        (bin_ / "llama-server").chmod(0o755)
        # The watchdog needs bash and tail. Linked in rather than putting /usr/bin
        # on PATH, so a broken fake fails instead of running the real program.
        for tool in ("bash", "tail"):
            (bin_ / tool).symlink_to(f"/usr/bin/{tool}")
        self.env = {"PATH": str(bin_), "HOME": str(self.root),
                    "XDG_RUNTIME_DIR": str(self.root), "GOOGLE_API_KEY": "unused",
                    # Gemini is https: a closed proxy port makes it unreachable.
                    "https_proxy": "http://127.0.0.1:1", "no_proxy": "",
                    "FAKE_DIR": str(self.root), "FAKE_CACHE": self.MODEL,
                    "FAKE_REPLY": "Anfahrt"}

    def start(self, *args):
        proc = subprocess.Popen([sys.executable, "-B", str(SCRIPT), *args], env=self.env,
                                start_new_session=True,
                                stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        self.addCleanup(self.kill, proc)
        return proc

    def kill(self, proc):
        try:
            os.killpg(proc.pid, signal.SIGKILL)
        except ProcessLookupError:
            pass
        proc.communicate()
        pid = self.root / "server.pid"
        if pid.exists():  # the fake runs in its own session; never leave it behind
            try:
                os.kill(int(pid.read_text()), signal.SIGKILL)
            except ProcessLookupError:
                pass

    def run_script(self, *args):
        proc = self.start(*args)
        out, err = proc.communicate(timeout=30)
        return proc.returncode, err.decode()

    def notices(self):
        return self.notify_log.read_text() if self.notify_log.exists() else ""

    def server_alive(self):
        try:
            os.kill(int((self.root / "server.pid").read_text()), 0)
            return True
        except ProcessLookupError:
            return False

    def test_unreachable_gemini_falls_back_to_local_model(self):
        self.assertEqual(self.run_script(), (0, ""))
        self.assertEqual(self.clipboard.read_text(), "Anfahrt")
        self.assertIn("reading it offline", self.notices())
        self.assertIn("OCR Copied (offline)", self.notices())
        argv = json.loads((self.root / "argv.json").read_text())
        self.assertIn("--offline", argv)
        self.assertEqual(argv[argv.index("-hf") + 1], self.MODEL)
        self.assertEqual(argv[argv.index("--host") + 1], "127.0.0.1")
        request = json.loads((self.root / "request.json").read_text())
        self.assertEqual(request["messages"][0]["content"][1]["text"], "Text Recognition:")
        self.assertEqual(request["max_tokens"], 64 + 300 * 100 // 200)
        self.assertFalse(self.server_alive(), "server left running")

    def test_translation_does_not_fall_back(self):
        self.assertEqual(self.run_script("--translate")[0], 1)
        self.assertIn("translation needs the network", self.notices())
        self.assertFalse((self.root / "argv.json").exists())

    def test_uncached_model_says_how_to_get_it(self):
        self.env["FAKE_CACHE"] = "ggml-org/Qwen3-ASR-0.6B-GGUF:Q8_0"
        self.assertEqual(self.run_script()[0], 1)
        self.assertIn(f"llama-server -hf {self.MODEL}", self.notices())
        self.assertFalse((self.root / "argv.json").exists())

    def test_server_that_dies_at_startup_is_reported(self):
        self.env["FAKE_MODE"] = "crash"
        self.assertEqual(self.run_script()[0], 1)
        self.assertIn("failed to start", self.notices())
        self.assertIn("failed to load model", self.notices())
        self.assertIn("exiting due to model loading error", self.notices())
        self.assertNotIn("bash:", self.notices())

    def test_blank_outputs_are_no_text_but_symbols_are_kept(self):
        for reply, blank in [("---", True), ("\n```markdown\n\n```", True),
                             ("$=$", False), ("\u2192", False), ("```foo```", False)]:
            with self.subTest(reply=reply):
                self.env["FAKE_REPLY"] = reply
                self.notify_log.unlink(missing_ok=True)
                self.clipboard.unlink(missing_ok=True)
                self.assertEqual(self.run_script(), (0, ""))
                self.assertEqual("No text found" in self.notices(), blank)
                self.assertEqual(self.clipboard.exists(), not blank)

    def test_unreadable_reply_is_reported(self):
        self.env["FAKE_MODE"] = "garbage"
        for raw in ("not json", "[]", '{"choices": []}', '{"choices": ["x"]}',
                    '{"choices": [{"message": "s"}]}',
                    '{"choices": [{"message": {"content": ["a"]}}]}'):
            with self.subTest(raw=raw):
                self.env["FAKE_RAW"] = raw
                self.notify_log.unlink(missing_ok=True)
                code, err = self.run_script()
                self.assertEqual((code, err), (1, ""))
                self.assertIn("unreadable reply", self.notices())
                self.assertFalse(self.server_alive(), "server left running")

    def test_local_http_error_shows_its_body(self):
        self.env["FAKE_MODE"] = "http500"
        self.assertEqual(self.run_script()[0], 1)
        self.assertIn("Offline model returned 500: boom: out of memory", self.notices())

    def test_failing_cache_list_is_not_reported_as_missing_model(self):
        self.env["FAKE_MODE"] = "broken"
        self.assertEqual(self.run_script()[0], 1)
        self.assertIn("--cache-list failed", self.notices())
        self.assertNotIn("not downloaded", self.notices())

    def test_non_png_capture_fails_before_starting_a_server(self):
        (self.root / "capture.png").write_bytes(b"P6 not a png")
        self.assertEqual(self.run_script()[0], 1)
        self.assertIn("not a PNG", self.notices())
        self.assertFalse((self.root / "argv.json").exists())

    def test_output_limit_is_reported_as_truncated(self):
        self.env.update(FAKE_REPLY="Anf", FAKE_FINISH="length")
        self.assertEqual(self.run_script(), (0, ""))
        self.assertIn("OCR Copied (offline) - TRUNCATED", self.notices())

    def test_killed_caller_takes_the_server_down(self):
        # SIGKILL runs no finally: only the watchdog can stop the server.
        self.env["FAKE_MODE"] = "hang"
        proc = self.start()
        deadline = time.monotonic() + 20
        while not (self.root / "request.json").exists():
            self.assertLess(time.monotonic(), deadline, "never reached the local model")
            time.sleep(0.05)
        os.kill(proc.pid, signal.SIGKILL)
        proc.wait()
        deadline = time.monotonic() + 5  # tail --pid polls once a second
        while self.server_alive():
            self.assertLess(time.monotonic(), deadline, "server outlived its caller")
            time.sleep(0.1)


if __name__ == "__main__":
    unittest.main()
