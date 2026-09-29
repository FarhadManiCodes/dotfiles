"""mic-notify: one notice for the microphone, active then released, monitors ignored.

    python3 -B -m unittest discover -s tests -v

pactl and notify-send are fakes on a private PATH. `pactl subscribe` replays event
lines in the format pactl prints them (sequences like a real parecord on
2026-09-29), with pauses and edits to the fake source-output list in between, then
exits, which ends the script. `pactl list … short` prints fake tab-separated tables
and logs the call. The fake notify-send logs its arguments and prints a new id, as
`-p` does.
"""
from pathlib import Path
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "bash/mic-notify"

# Index 57 is a monitor, 58 and 59 are microphones, as on this laptop.
SOURCES = ("57\talsa_output.pci-0000_64_00.6.HiFi__Speaker__sink.monitor\tPipeWire\ts32le 2ch 48000Hz\tSUSPENDED\n"
           "58\talsa_input.pci-0000_64_00.6.HiFi__Mic2__source\tPipeWire\ts32le 2ch 48000Hz\tSUSPENDED\n"
           "59\talsa_input.pci-0000_64_00.6.HiFi__Mic1__source\tPipeWire\ts32le 2ch 48000Hz\tSUSPENDED\n")


def recording(idx, source):
    """One source-outputs short line: index, source index, client, driver, spec."""
    return f"{idx}\t{source}\t80\tPipeWire\ts16le 2ch 44100Hz\n"


def events(kind, idx, changes=0):
    return "".join([f"Event '{kind}' on source-output #{idx}\n"] +
                   [f"Event 'change' on source-output #{idx}\n"] * changes)


class MicNotifyTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory(prefix="mic-notify-test-")
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.log = self.root / "log"
        self.events = self.root / "events"
        self.events.mkdir()
        (self.root / "sources").write_text(SOURCES)
        self.outputs = self.root / "outputs"
        self.outputs.write_text("")
        # Replays event files in name order: "N.sleep" pauses, "N.set" replaces the
        # source-output list, anything else is printed, then a pause for the script
        # to check before the list changes (a real recording outlives its event).
        self.fake("pactl", 'case $1 in\n'
                           '  subscribe) for f in "$EVENTS"/*; do\n'
                           '      case $f in *.sleep) sleep "$(cat "$f")" ;;\n'
                           '        *.set) cp "$f" "$FAKE/outputs" ;;\n'
                           '        *) cat "$f"; sleep 0.1 ;; esac\n'
                           '    done ;;\n'
                           '  list) echo "list $2" >> "$LOG"\n'
                           '    if [ "$2" = sources ]; then cat "$FAKE/sources"; else cat "$FAKE/outputs"; fi ;;\n'
                           'esac')
        self.fake("notify-send", 'n=$(( $(cat "$LOG.id" 2>/dev/null || echo 0) + 1 ))\n'
                                 'echo "$n" > "$LOG.id"; echo "notify $*" >> "$LOG"; echo "$n"')
        # Pinned, not inherited: the fakes shadow the real tools.
        self.env = {"PATH": f"{self.bin}:/usr/bin", "HOME": str(self.root), "LC_ALL": "C.UTF-8",
                    "LOG": str(self.log), "EVENTS": str(self.events), "FAKE": str(self.root)}
        self.n = 0

    def fake(self, name, body):
        path = self.bin / name
        path.write_text(f"#!/bin/sh\n{body}\n")
        path.chmod(0o755)

    def play(self, *steps):
        """Queue events (str), pauses (seconds) and source-output lists (list of lines)."""
        for step in steps:
            self.n += 1
            if isinstance(step, list):
                (self.events / f"{self.n:03}.set").write_text("".join(step))
            elif isinstance(step, str):
                (self.events / f"{self.n:03}").write_text(step)
            else:
                (self.events / f"{self.n:03}.sleep").write_text(str(step))

    def run_script(self):
        return subprocess.run(["bash", str(SCRIPT)], env=self.env, stdout=subprocess.DEVNULL,
                              stderr=subprocess.DEVNULL, timeout=20).returncode

    def log_lines(self, prefix):
        lines = self.log.read_text().splitlines() if self.log.exists() else []
        return [line for line in lines if line.startswith(prefix)]

    def test_active_then_released_in_one_notice(self):
        self.play([recording(86, 59)], events("new", 86, changes=5),
                  [], events("remove", 86))
        self.run_script()
        self.assertEqual(self.log_lines("notify"), [
            "notify -p -r 0 -a  -u critical --  Microphone active",
            "notify -p -r 1 -a  -u normal --  Microphone released"])

    def test_change_events_do_not_trigger_a_check(self):
        self.play([recording(86, 59)], events("new", 86, changes=5))
        self.run_script()
        # One check at start and one for 'new': two tables each.
        self.assertEqual(len(self.log_lines("list")), 4)

    def test_recording_a_monitor_is_silent(self):
        self.play([recording(101, 57)], events("new", 101, changes=3),
                  [], events("remove", 101))
        self.run_script()
        self.assertEqual(self.log_lines("notify"), [])

    def test_two_recordings_are_one_notice_released_after_the_last(self):
        self.play([recording(86, 59)], events("new", 86),
                  [recording(86, 59), recording(90, 58)], events("new", 90),
                  [recording(90, 58)], events("remove", 86),
                  [], events("remove", 90))
        self.run_script()
        notices = self.log_lines("notify")
        self.assertEqual(len(notices), 2, notices)
        self.assertIn("Microphone active", notices[0])
        self.assertIn("-r 1 -a  -u normal -- \uf131 Microphone released", notices[1])

    def test_in_use_at_start_is_shown(self):
        self.outputs.write_text(recording(86, 59))
        self.run_script()
        self.assertEqual(self.log_lines("notify"),
                         ["notify -p -r 0 -a  -u critical --  Microphone active"])

    def test_listener_ending_is_a_failure(self):
        # Under systemd, exit 1 is what makes Restart= and OnFailure= fire.
        self.assertEqual(self.run_script(), 1)


if __name__ == "__main__":
    unittest.main()
