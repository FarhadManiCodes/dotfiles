"""capture-ocr runs one instance at a time: a second press while one is active does nothing.

    python3 -B -m unittest discover -s tests -v

The script runs for real against fake slurp/notify-send on a private PATH. slurp
exiting 1 is the user pressing ESC, so no run here reaches grim or the network.
"""
import os
from pathlib import Path
import signal
import subprocess
import sys
import tempfile
import time
import unittest


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
        # Set but missing: the docstring promises an unlocked run, not a traceback.
        self.env["XDG_RUNTIME_DIR"] = str(self.root / "missing")
        code, err = self.run_once()
        self.assertEqual((code, err), (0, ""))
        self.assertEqual(self.slurp_calls(), 1)

    def test_second_run_during_first_does_nothing(self):
        first = self.start_blocked()
        code, err = self.run_once()
        self.assertEqual((code, err), (0, ""))
        self.assertEqual(self.slurp_calls(), 1, "second run opened another selector")
        self.assertFalse(self.notify_log.exists(), "second run should stay silent")
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


if __name__ == "__main__":
    unittest.main()
