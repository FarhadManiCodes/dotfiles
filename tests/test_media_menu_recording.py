"""Exercise recording through the real media menu with isolated substitutes."""
import os
from pathlib import Path
import signal
import subprocess
import tempfile
import time
import unittest


SOURCE = Path(__file__).resolve().parents[1] / "bash/media-menu.sh"


class MediaMenuRecordingTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="toggle-record-test-")
        self.base = Path(self.tmp.name)
        self.home = self.base / "home"
        self.runtime = self.base / "runtime"
        self.bin = self.base / "bin"
        for directory in (self.home, self.runtime, self.bin):
            directory.mkdir()
        self.env = {
            "HOME": str(self.home), "XDG_RUNTIME_DIR": str(self.runtime),
            "PATH": f"{self.bin}:/usr/bin:/bin", "LC_ALL": "C",
            "NO_COLOR": "1", "FIXTURE_ROOT": str(self.base), "HOLD_START": "0", "PICK_RECORD": "1",
        }
        self.processes = []
        self.addCleanup(self.cleanup)
        # Give the fixture the real kernel process name the script checks,
        # without capturing audio or contacting PipeWire.
        recorder = self.base / "recorder.py"
        recorder.write_text('''import ctypes, os, pathlib, time
root = pathlib.Path(os.environ["FIXTURE_ROOT"])
if ctypes.CDLL(None).prctl(15, b"pw-record", 0, 0, 0) != 0:
    raise RuntimeError("cannot set fixture process name")
with (root / "recorders").open("a") as output:
    output.write(str(os.getpid()) + "\\n")
inherited = False
for descriptor in pathlib.Path("/proc/self/fd").iterdir():
    try:
        inherited |= os.readlink(descriptor).endswith("toggle-record.lock")
    except OSError:
        pass
(root / "inherited-lock").write_text(str(inherited))
while True:
    time.sleep(0.1)
''')
        self.stub("pw-record", 'exec /usr/bin/python3 "$FIXTURE_ROOT/recorder.py" "$@" >/dev/null 2>&1\n')
        self.stub("pactl", "printf 'fixture-sink\\n'\n")
        self.stub("fuzzel", '''menu=$(cat)
printf '%s\\n' "$menu" > "$FIXTURE_ROOT/menu"
if [[ $PICK_RECORD == 1 ]]; then
    printf '%s\\n' "$menu" | grep 'Recording$'
else
    exit 1  # cancel after observing the menu's status label
fi
''')
        self.stub("notify-send", '''printf '%s\\n' "$*" >> "$FIXTURE_ROOT/notices"
if [[ $HOLD_START == 1 && $* == *"Recording started"* ]]; then
    touch "$FIXTURE_ROOT/start-notification"
    while [[ ! -e $FIXTURE_ROOT/release ]]; do /usr/bin/sleep 0.01; done
fi
''')

    def stub(self, name, body):
        path = self.bin / name
        path.write_text("#!/bin/bash\n" + body)
        path.chmod(0o755)

    def cleanup(self):
        # Terminate only the processes this fixture explicitly launched.
        for process in self.processes:
            if process.poll() is None:
                os.killpg(process.pid, signal.SIGTERM)
            process.communicate(timeout=5)
        if (self.base / "recorders").exists():
            for pid in (self.base / "recorders").read_text().splitlines():
                try:
                    os.kill(int(pid), signal.SIGTERM)
                except ProcessLookupError:
                    pass
        self.tmp.cleanup()

    def run_toggle(self):
        return subprocess.run(["/bin/bash", str(SOURCE)],
                              env=self.env, text=True, capture_output=True, timeout=3)

    def assert_status(self, active):
        before = {p.name: p.read_bytes() for p in self.runtime.iterdir()}
        notices = self.base / "notices"
        previous_notices = notices.read_bytes() if notices.exists() else None
        result = subprocess.run(["/bin/bash", str(SOURCE)],
                                env=dict(self.env, PICK_RECORD="0"),
                                text=True, capture_output=True, timeout=3)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stderr, "")
        label = "🔴  Stop Recording" if active else "⏺  Start Recording"
        self.assertEqual((self.base / "menu").read_text().splitlines()[-1], label)
        self.assertEqual({p.name: p.read_bytes() for p in self.runtime.iterdir()}, before)
        self.assertEqual(notices.read_bytes() if notices.exists() else None,
                         previous_notices)

    def wait_for(self, path):
        deadline = time.monotonic() + 3
        while time.monotonic() < deadline:
            if path.exists():
                return
            time.sleep(0.01)
        self.fail(f"fixture did not produce {path.name}")

    def test_overlapping_toggle_is_ignored_and_menu_status_does_not_wait(self):
        self.env["HOLD_START"] = "1"
        first = subprocess.Popen(["/bin/bash", str(SOURCE)], env=self.env,
                                 text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                 start_new_session=True)
        self.processes.append(first)
        self.wait_for(self.base / "start-notification")
        self.assertIsNone(first.poll())
        pid = (self.runtime / "toggle-record.pid").read_text()
        self.assertEqual(self.run_toggle().returncode, 0)
        self.assertTrue((self.runtime / "toggle-record.pid").exists(),
                        "overlapping toggle stopped the recorder")
        self.assertEqual((self.runtime / "toggle-record.pid").read_text(), pid)
        self.assert_status(True)
        self.assertEqual((self.base / "recorders").read_text().splitlines(), [pid.strip()])
        (self.base / "release").touch()
        first.communicate(timeout=3)
        self.assertEqual(first.returncode, 0)
        # A later toggle must acquire the lock while the recorder is still alive.
        self.assertEqual((self.base / "inherited-lock").read_text(), "False")
        self.assertEqual(self.run_toggle().returncode, 0)
        self.assertFalse((self.runtime / "toggle-record.pid").exists())
        self.assertIn("Saved to", (self.base / "notices").read_text())

    def test_sequential_start_stop_and_restart(self):
        self.assertEqual(self.run_toggle().returncode, 0)
        self.assert_status(True)
        self.assertEqual(self.run_toggle().returncode, 0)
        self.assert_status(False)
        self.assertEqual(self.run_toggle().returncode, 0)
        self.assertEqual(len((self.base / "recorders").read_text().splitlines()), 2)
        self.assert_status(True)

    def test_cancelled_inactive_menu_is_read_only(self):
        self.assert_status(False)
        self.assertEqual(list(self.runtime.iterdir()), [])
        self.assertFalse((self.base / "notices").exists())


if __name__ == "__main__":
    unittest.main()
