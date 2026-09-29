"""power-notify: charger, charge and battery-level notices, and when they appear.

    python3 -B -m unittest discover -s tests -v

udevadm and notify-send are fakes on a private PATH, and /sys/class/power_supply
is a fake directory. The fake `udevadm monitor` replays power_supply events in the
format it prints them (blocks of properties, a blank line after each; sequences
copied from a real unplug, cable re-seat and charge to the limit on 2026-09-29),
with pauses and sysfs changes in between, then exits, which ends the script.
The fake notify-send logs its arguments and prints a new id, as `-p` does.
"""
from pathlib import Path
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "bash/power-notify"


def event(name, **props):
    """One udev block, e.g. event("BAT0", STATUS="Charging", CAPACITY=64)."""
    lines = [f"UDEV  [7270.3] change   /devices/x/power_supply/{name} (power_supply)",
             "ACTION=change", "SUBSYSTEM=power_supply", f"POWER_SUPPLY_NAME={name}"]
    lines += [f"POWER_SUPPLY_{k}={v}" for k, v in props.items()]
    return "\n".join(lines) + "\n\n"


class PowerNotifyTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory(prefix="power-notify-test-")
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.log = self.root / "log"
        self.events = self.root / "events"
        self.events.mkdir()
        self.sysfs = self.root / "power_supply"
        # energy_full is tiny so that 1% takes 1 s at the assumed 30 W: the level
        # timer then waits (level - next alert + 1) seconds.
        self.set(AC="1", status="Charging", capacity="64", energy_full="1000000",
                 end="81")
        # Replays event files in name order: "N.sleep" pauses, "N.set" writes
        # "<file> <value>" into the fake sysfs, anything else is printed.
        self.fake("udevadm", 'printf "monitor will print the received events for:\\n'
                             'UDEV - the event which udev sends out after rule processing\\n\\n"\n'
                             'for f in "$EVENTS"/*; do\n'
                             '  case $f in *.sleep) sleep "$(cat "$f")" ;;\n'
                             '    *.set) read -r p v < "$f"; printf "%s\\n" "$v" > "$POWER_SYSFS/$p" ;;\n'
                             '    *) cat "$f" ;; esac\n'
                             'done')
        self.fake("notify-send", 'n=$(( $(cat "$LOG.id" 2>/dev/null || echo 0) + 1 ))\n'
                                 'echo "$n" > "$LOG.id"; echo "notify $*" >> "$LOG"; echo "$n"')
        # Pinned, not inherited: the fakes shadow the real tools.
        self.env = {"PATH": f"{self.bin}:/usr/bin", "HOME": str(self.root), "LC_ALL": "C.UTF-8",
                    "LOG": str(self.log), "EVENTS": str(self.events),
                    "POWER_SYSFS": str(self.sysfs)}
        self.n = 0

    def set(self, AC=None, status=None, capacity=None, energy_full=None, end=None):
        for path, value in (("AC/online", AC), ("BAT0/status", status),
                            ("BAT0/capacity", capacity), ("BAT0/energy_full", energy_full),
                            ("BAT0/charge_control_end_threshold", end)):
            if value is not None:
                f = self.sysfs / path
                f.parent.mkdir(parents=True, exist_ok=True)
                f.write_text(f"{value}\n")

    def fake(self, name, body):
        path = self.bin / name
        path.write_text(f"#!/bin/sh\n{body}\n")
        path.chmod(0o755)

    def play(self, *steps):
        """Queue events (str), pauses (seconds) and sysfs writes ({"BAT0/capacity": 29})."""
        for step in steps:
            self.n += 1
            if isinstance(step, dict):
                ((path, value),) = step.items()
                (self.events / f"{self.n:03}.set").write_text(f"{path} {value}")
            elif isinstance(step, str):
                (self.events / f"{self.n:03}").write_text(step)
            else:
                (self.events / f"{self.n:03}.sleep").write_text(str(step))

    def run_script(self):
        # Not captured: a pause left behind would hold the pipes open.
        return subprocess.run(["bash", str(SCRIPT)], env=self.env, stdout=subprocess.DEVNULL,
                              stderr=subprocess.DEVNULL, timeout=40).returncode

    def notices(self):
        return self.log.read_text().splitlines() if self.log.exists() else []

    def test_reseating_the_cable_is_not_charging_complete(self):
        # 2026-09-29 at 64%: AC 0 -> 1 within 1 s, BAT0 Charging -> Not charging -> Charging.
        self.play(event("BAT0", STATUS="Not charging", CAPACITY=64),
                  event("AC", ONLINE=0), 0.5, event("AC", ONLINE=1),
                  event("BAT0", STATUS="Charging", CAPACITY=64))
        self.run_script()
        notices = self.notices()
        self.assertFalse([n for n in notices if "complete" in n], notices)
        self.assertIn("Plugged in — 64%, charging", notices[-1])

    def test_reaching_the_limit_is_one_charging_complete(self):
        self.set(capacity="80")
        self.play(*[event("BAT0", STATUS="Not charging", CAPACITY=81)] * 4)
        self.run_script()
        self.assertEqual(self.notices(), ["notify -p -r 0 -a  -u normal -- \U000f0079  "
                                          "Charging complete — 81%"])

    def test_plugging_in_is_one_notice_updated_to_charging(self):
        self.set(AC="0", status="Discharging")
        self.play(event("AC", ONLINE=1), event("BAT0", STATUS="Not charging", CAPACITY=64),
                  0.5, event("BAT0", STATUS="Charging", CAPACITY=64))
        self.run_script()
        notices = self.notices()
        self.assertEqual(len(notices), 2, notices)
        self.assertIn("-r 0 -a  -u normal -- \U000f06a5  Plugged in — 64%", notices[0])
        self.assertIn("-r 1 -a  -u normal -- \U000f06a5  Plugged in — 64%, charging", notices[1])

    def test_unplugging_is_a_normal_notice(self):
        self.play(event("AC", ONLINE=0))
        self.run_script()
        self.assertEqual(len(self.notices()), 1)
        self.assertIn("-u normal -- \U000f007e  Unplugged — 64%", self.notices()[0])

    def test_usb_c_supply_events_are_ignored(self):
        self.play(event("ucsi-source-psy-USBC000:001", STATUS="Charging", ONLINE=1),
                  event("ucsi-source-psy-USBC000:001", STATUS="Not charging", ONLINE=0))
        self.run_script()
        self.assertEqual(self.notices(), [])

    def test_nothing_is_checked_while_plugged_in(self):
        # Even at 5%, plugged in means no level alerts.
        self.set(capacity="5")
        self.play(3)
        self.run_script()
        self.assertEqual(self.notices(), [])

    def test_level_is_read_on_a_timer_without_any_event(self):
        # On battery at 31%: the next check is due in (31 - 30 + 1) s.
        self.set(AC="0", status="Discharging", capacity="31")
        self.play(1, {"BAT0/capacity": 29}, 3)
        self.run_script()
        notices = self.notices()
        self.assertEqual(len(notices), 1, notices)
        self.assertIn("-u normal -- \U000f007b  Battery low — 29%", notices[0])

    def test_critical_and_danger_stay_on_screen(self):
        self.set(AC="0", status="Discharging", capacity="9")
        self.play(1, {"BAT0/capacity": 4}, 6)
        self.run_script()
        notices = self.notices()
        self.assertEqual(len(notices), 2, notices)
        self.assertIn("-r 0 -a  -u critical -- \U000f0083  Battery critical — 9%", notices[0])
        self.assertIn("-r 1 -a  -u critical -- \U000f008e  Battery danger — 4%", notices[1])

    def test_each_alert_once_per_discharge_and_again_after_plugging_in(self):
        self.set(AC="0", status="Discharging", capacity="29")
        self.play(3, event("AC", ONLINE=1), event("AC", ONLINE=0))
        self.run_script()
        lows = [n for n in self.notices() if "Battery low" in n]
        self.assertEqual(len(lows), 2, self.notices())

    def test_listener_ending_is_a_failure(self):
        # Under systemd, exit 1 is what makes Restart= and OnFailure= fire.
        self.assertEqual(self.run_script(), 1)


if __name__ == "__main__":
    unittest.main()
