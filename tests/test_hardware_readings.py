"""On-demand sensor callers with isolated sensor, battery and notification inputs."""

import json
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SNAPSHOT = {
    "k10temp-pci-abcd": {"Tctl": {"temp1_input": 39.25}},
    "amdgpu-pci-abcd": {"edge": {"temp1_input": 36}},
    "nvme-pci-abcd": {"Composite": {"temp1_input": 38.85}},
    "thinkpad-isa-0000": {
        "fan1": {"fan1_input": 0},
        "fan2": {"fan2_input": 1200},
        "CPU": {"temp1_input": 99},
        "pwm1": {"pwm1": 127.5},
    },
    "acpi_fan-isa-0000": {"fan1": {"fan1_input": 9999}},
    "acpitz-acpi-0": {"temp1": {"temp1_input": 99}},
}

FAKE = """#!/usr/bin/python3
import json, os, pathlib, sys
name = pathlib.Path(sys.argv[0]).name
args = sys.argv[1:]
with open(os.environ['CALLS'], 'a') as log:
    log.write(json.dumps([name, args]) + '\\n')
if name == 'sensors':
    print(os.environ['SNAPSHOT'], end='')
    print('unavailable unrelated sensor', file=sys.stderr)
    sys.exit(int(os.environ.get('SENSOR_STATUS', '0')))
if name == 'jq':
    os.execv('/usr/bin/jq', ['jq', *args])
if name == 'fuzzel':
    menu = sys.stdin.read()
    assert 'Temperatures' in menu and 'CPU Temp' not in menu
    print(os.environ.get('SELECTED', 'Temperatures'))
if name == 'cat':
    # Only batt's battery files; never read the live machine in these tests.
    values = {'status': 'Discharging', 'capacity': '75', 'power_now': '10000000',
              'energy_now': '30000000'}
    assert args[0].startswith('/sys/class/power_supply/BAT0/')
    print(values[pathlib.Path(args[0]).name])
if name == '[':
    assert args == ['!', '-d', '/sys/class/power_supply/BAT0', ']']
    sys.exit(1)  # Fake BAT0 exists, so its negated directory test is false.
"""


class HardwareReadingsTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory(prefix="hardware-readings-test-")
        self.addCleanup(temp.cleanup)
        self.bin = Path(temp.name)
        self.log = self.bin / "calls.jsonl"
        for name in ("sensors", "jq", "fuzzel", "notify-send", "cat", "["):
            path = self.bin / name
            path.write_text(FAKE)
            path.chmod(0o755)
        (self.bin / "hardware-readings").symlink_to(
            ROOT / "bash/hardware-readings"
        )
        (self.bin / "awk").symlink_to("/usr/bin/awk")
        self.env = {
            "PATH": str(self.bin),
            "HOME": str(self.bin),
            "LC_ALL": "C.UTF-8",
            "CALLS": str(self.log),
            "SNAPSHOT": json.dumps(SNAPSHOT),
        }

    def calls(self, name):
        return [
            args
            for command, args in map(
                json.loads, self.log.read_text().splitlines()
            )
            if command == name
        ]

    def run_caller(self, caller, snapshot, **env):
        self.log.unlink(missing_ok=True)
        if caller == "notification":
            command = ["/bin/bash", str(ROOT / "bash/status-menu")]
        else:
            # Disable only the directory-test builtin, substituting our fake BAT0.
            command = [
                "/usr/bin/zsh",
                "-f",
                "-c",
                'source "$1"; disable "["; batt',
                "test-batt",
                str(ROOT / "zsh/helpers.zsh"),
            ]
        result = subprocess.run(
            command,
            env=dict(self.env, SNAPSHOT=snapshot, **env),
            capture_output=True,
            text=True,
            timeout=10,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stderr, "")
        self.assertEqual(self.calls("sensors"), [["-j"]])
        self.assertEqual(len(self.calls("jq")), 1)
        if caller == "notification":
            notifications = self.calls("notify-send")
            self.assertEqual(len(notifications), 1)
            self.assertEqual(
                notifications[0][:3], ["-u", "low", " Temperatures"]
            )
            return notifications[0][3]
        self.assertEqual(self.calls("notify-send"), [])
        self.assertIn("Level:    75%", result.stdout)
        self.assertIn("Time:     3h 0m remaining", result.stdout)
        return result.stdout

    def assert_readings(self, snapshot, values, *, warning=False, **env):
        for caller in ("notification", "batt"):
            with self.subTest(caller=caller):
                output = self.run_caller(caller, snapshot, **env)
                if caller == "notification":
                    expected = (
                        f"CPU {values[0]} • GPU {values[1]} • SSD {values[2]}\n"
                        f"Fan 1 {values[3]} • Fan 2 {values[4]}"
                    )
                    if warning:
                        expected += "\nSensor readings unavailable"
                    self.assertEqual(output, expected)
                else:
                    for label, value in zip(
                        ("CPU", "GPU", "NVMe", "Fan 1", "Fan 2"),
                        values,
                        strict=True,
                    ):
                        self.assertIn(f"{label + ':':<10}{value}\n", output)
                    self.assertEqual(
                        "Sensor readings unavailable" in output, warning
                    )

    def test_normal_readings_zero_fan_and_no_duplicates(self):
        self.assert_readings(
            json.dumps(SNAPSHOT),
            ["39.3°C", "36.0°C", "38.9°C", "0 RPM", "1200 RPM"],
        )

    def test_valid_json_survives_sensor_failure_status(self):
        self.assert_readings(
            json.dumps(SNAPSHOT),
            ["39.3°C", "36.0°C", "38.9°C", "0 RPM", "1200 RPM"],
            SENSOR_STATUS="1",
        )

    def test_missing_gpu(self):
        snapshot = {
            k: v for k, v in SNAPSHOT.items() if not k.startswith("amdgpu-")
        }
        self.assert_readings(
            json.dumps(snapshot),
            ["39.3°C", "N/A", "38.9°C", "0 RPM", "1200 RPM"],
        )

    def test_null_empty_and_nonnumeric_values(self):
        snapshot = {
            "k10temp-pci-0000": {"Tctl": {"temp1_input": None}},
            "amdgpu-pci-0000": {"edge": {}},
            "nvme-pci-0000": {"Composite": {"temp1_input": "unavailable"}},
            "thinkpad-isa-0000": {"fan1": {"fan1_input": None}, "fan2": {}},
        }
        self.assert_readings(json.dumps(snapshot), ["N/A"] * 5)

    def test_missing_chips(self):
        self.assert_readings("{}", ["N/A"] * 5)

    def test_zero_temperatures_and_both_fans_stopped(self):
        snapshot = json.loads(json.dumps(SNAPSHOT))
        snapshot["amdgpu-pci-abcd"]["edge"]["temp1_input"] = 0
        snapshot["thinkpad-isa-0000"]["fan2"]["fan2_input"] = 0
        self.assert_readings(
            json.dumps(snapshot),
            ["39.3°C", "0.0°C", "38.9°C", "0 RPM", "0 RPM"],
        )

    def test_unparseable_output(self):
        for snapshot in ("", "{broken", "null", "[]", "{}\n{}"):
            with self.subTest(snapshot=snapshot):
                self.assert_readings(snapshot, ["N/A"] * 5, warning=True)

    def test_canceled_and_other_menu_selection_do_not_read_sensors(self):
        (self.bin / "free").write_text(
            '#!/bin/sh\nprintf "Mem: 16Gi 4Gi 12Gi 0B 0B 12Gi\\n"\n'
        )
        (self.bin / "free").chmod(0o755)
        for selected in ("", "Memory"):
            with self.subTest(selected=selected):
                self.log.unlink(missing_ok=True)
                result = subprocess.run(
                    ["/bin/bash", str(ROOT / "bash/status-menu")],
                    env=dict(self.env, SELECTED=selected),
                    capture_output=True,
                    text=True,
                    timeout=10,
                    check=False,
                )
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(self.calls("sensors"), [])
                self.assertEqual(self.calls("jq"), [])
                self.assertEqual(
                    len(self.calls("notify-send")), int(bool(selected))
                )


if __name__ == "__main__":
    unittest.main()
