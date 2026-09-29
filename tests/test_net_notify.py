"""net-notify: which network notices reach mako, and when.

    python3 -B -m unittest discover -s tests -v

dbus-monitor, iwctl and notify-send are fakes on a private PATH, and
/sys/class/net is a fake directory. The fake dbus-monitor logs its match rules and
replays iwd, networkd and logind signals (in the format dbus-monitor prints them,
networkd's copied from a real cable plug/unplug) with pauses in between, then
exits, which ends the script. The fake notify-send logs its arguments and prints a new id, as `-p` does.
"""
from pathlib import Path
import subprocess
import tempfile
import time
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "bash/net-notify"


def signal(interface, prop, value):
    return (f"signal time=1.0 sender=:1.9 -> destination=(null destination) serial=1 "
            f"path=/net/connman/iwd/0/4; interface=org.freedesktop.DBus.Properties; "
            f"member=PropertiesChanged\n"
            f'   string "net.connman.iwd.{interface}"\n'
            f"   array [\n      dict entry(\n"
            f'         string "{prop}"\n'
            f"         variant             {value}\n"
            f"      )\n   ]\n   array [\n   ]\n")


def state(value):
    return signal("Station", "State", f'string "{value}"')


POWERED_OFF = signal("Device", "Powered", "boolean false")


def carrier(value):
    """networkd on the wired link: "carrier" on plug-in, "no-carrier" on unplug."""
    return ("signal time=1.0 sender=:1.5 -> destination=(null destination) serial=3 "
            "path=/org/freedesktop/network1/link/_32; interface=org.freedesktop.DBus.Properties; "
            "member=PropertiesChanged\n"
            '   string "org.freedesktop.network1.Link"\n'
            "   array [\n      dict entry(\n"
            '         string "CarrierState"\n'
            f'         variant             string "{value}"\n'
            "      )\n      dict entry(\n"
            '         string "OperationalState"\n'
            f'         variant             string "{value}"\n'
            "      )\n   ]\n   array [\n   ]\n")


def sleep_signal(going_to_sleep):
    """logind's PrepareForSleep: true before suspend, false after wake."""
    return ("signal time=1.0 sender=:1.3 -> destination=(null destination) serial=2 "
            "path=/org/freedesktop/login1; interface=org.freedesktop.login1.Manager; "
            f"member=PrepareForSleep\n   boolean {str(going_to_sleep).lower()}\n")


class NetNotifyTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory(prefix="net-notify-test-")
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.log = self.root / "log"
        self.events = self.root / "events"
        # Each event file is replayed in name order; "N.sleep" files pause and
        # "N.ssid" files change the network iwctl reports.
        self.events.mkdir()
        self.fake("dbus-monitor", 'printf "%s\\n" "$@" > "$LOG.rules"\n'
                                  'for f in "$EVENTS"/*; do\n'
                                  '  case $f in *.sleep) sleep "$(cat "$f")" ;;\n'
                                  '    *.ssid) cp "$f" "$SSID" ;; *) cat "$f" ;; esac\n'
                                  'done')
        self.fake("notify-send", 'n=$(( $(cat "$LOG.id" 2>/dev/null || echo 0) + 1 ))\n'
                                 'echo "$n" > "$LOG.id"; echo "notify $*" >> "$LOG"; echo "$n"\n'
                                 'date +%s.%N >> "$LOG.time"')
        self.fake("iwctl", 'case $* in\n'
                           '  "device list") printf "  wlan0  aa:bb  on  phy0  station\\n" ;;\n'
                           '  "station wlan0 show") printf "  Connected network     %s   \\n" "$(cat "$SSID")" ;;\n'
                           'esac')
        # wlan0 (index 3) and a wired enp1s0f0 (index 2), as on this laptop.
        self.sysfs = self.root / "net"
        for name, index, wireless in (("wlan0", 3, True), ("enp1s0f0", 2, False)):
            d = self.sysfs / name
            (d / "device").mkdir(parents=True)
            (d / "type").write_text("1\n")
            (d / "ifindex").write_text(f"{index}\n")
            if wireless:
                (d / "wireless").mkdir()
        # Pinned, not inherited: the fakes shadow the real tools.
        self.env = {"PATH": f"{self.bin}:/usr/bin", "HOME": str(self.root), "LC_ALL": "C.UTF-8",
                    "LOG": str(self.log), "EVENTS": str(self.events),
                    "SSID": str(self.root / "ssid"), "NET_SYSFS": str(self.sysfs)}
        (self.root / "ssid").write_text("Home Net")
        self.n = 0

    def fake(self, name, body):
        path = self.bin / name
        path.write_text(f"#!/bin/sh\n{body}\n")
        path.chmod(0o755)

    def play(self, *steps):
        """Queue signals (str) and pauses (seconds, number) for the fake dbus-monitor."""
        for step in steps:
            self.n += 1
            if isinstance(step, dict):
                (self.events / f"{self.n:03}.ssid").write_text(step["ssid"])
            elif isinstance(step, str):
                (self.events / f"{self.n:03}").write_text(step)
            else:
                (self.events / f"{self.n:03}.sleep").write_text(str(step))

    def run_script(self, **env):
        # Not captured: a watcher left behind would hold the pipes open (under systemd
        # the cgroup kill ends it).
        return subprocess.run(["bash", str(SCRIPT)], env={**self.env, **env},
                              stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                              timeout=40).returncode

    def notices(self):
        return self.log.read_text().splitlines() if self.log.exists() else []

    def test_resume_blip_says_nothing(self):
        # Order seen at every resume: sleep, iwd drops, wake, back ~2 s later.
        self.play(sleep_signal(True), state("disconnected"), sleep_signal(False), 2,
                  state("connecting"), state("connected"))
        self.run_script()
        self.assertEqual(self.notices(), [])

    def test_waking_up_on_a_different_network_says_so(self):
        self.play(sleep_signal(True), state("disconnected"), sleep_signal(False),
                  {"ssid": "Office"}, state("connected"))
        self.run_script()
        notices = self.notices()
        self.assertEqual(len(notices), 1, notices)
        self.assertIn("Connected — Office", notices[0])

    def test_still_down_10s_after_wake_gives_one_notice_then_connected(self):
        self.play(sleep_signal(True), state("disconnected"), sleep_signal(False), 5,
                  state("disconnected"), 6, state("connected"))
        self.run_script()
        notices = self.notices()
        self.assertEqual(len(notices), 2, notices)
        self.assertIn("-r 0 -a  -u critical -- ⚠  WiFi disconnected", notices[0])
        # "Connected" takes the sticky notice's place (fake ids count from 1).
        self.assertIn("-r 1 ", notices[1])
        self.assertIn("Connected — Home Net", notices[1])

    def test_drop_while_awake_is_reported_at_once_and_once(self):
        # Failed reconnect attempts report "disconnected" again and again.
        self.play(state("disconnected"), state("disconnected"), 3, state("disconnected"))
        start = time.time()
        self.run_script()
        notices = self.notices()
        self.assertEqual(len(notices), 1, notices)
        self.assertIn("WiFi disconnected", notices[0])
        sent = float(Path(f"{self.log}.time").read_text().split()[0])
        self.assertLess(sent - start, 2)

    def test_turning_wifi_off_replaces_the_disconnect_notice(self):
        self.play(state("disconnected"), POWERED_OFF)
        self.run_script()
        notices = self.notices()
        self.assertEqual(len(notices), 2, notices)
        self.assertIn("-r 1 -a  -u critical -- ⚠  WiFi turned off", notices[1])

    def test_hostile_ssid_is_text_not_an_option(self):
        self.fake("iwctl", 'case $* in\n'
                           '  "device list") printf "  wlan0  aa:bb  on  phy0  station\\n" ;;\n'
                           '  *) printf "  Connected network     --hint=int:x:1\\n" ;;\n'
                           'esac')
        self.play(state("connected"))
        self.run_script()
        self.assertIn("-- ", self.notices()[0])

    def test_ethernet_notices_replace_each_other(self):
        self.play(carrier("carrier"), 0.2, carrier("no-carrier"))
        self.run_script()
        rules = Path(f"{self.log}.rules").read_text()
        self.assertIn("path='/org/freedesktop/network1/link/_32'", rules)
        notices = self.notices()
        self.assertEqual(len(notices), 2, notices)
        self.assertIn("-r 0 -a  -u normal -- \U000f0200  Ethernet connected", notices[0])
        self.assertIn("-r 1 -a  -u critical -- \U000f0200  Ethernet disconnected", notices[1])

    def test_no_wired_device_means_no_ethernet_rule(self):
        import shutil
        shutil.rmtree(self.sysfs / "enp1s0f0")
        self.run_script()
        self.assertNotIn("network1", Path(f"{self.log}.rules").read_text())

    def test_listener_ending_is_a_failure(self):
        # Under systemd, exit 1 is what makes Restart= and OnFailure= fire.
        self.play(state("connected"))
        self.assertEqual(self.run_script(), 1)

if __name__ == "__main__":
    unittest.main()
