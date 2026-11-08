"""The Internet item of bash/status-menu: Wi-Fi signal word from fake iw and sysfs."""

from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
LINK = """Connected to aa:bb:cc:dd:ee:ff (on wlan0)
\tSSID: Home
\tfreq: 5180
\tsignal: {link} dBm
\trx bitrate: 866.7 MBit/s
"""
DUMP = "Station aa:bb:cc:dd:ee:ff (on wlan0)\n{lines}"
FUZZEL = '#!/bin/sh\ncat >/dev/null\necho "Internet"\n'
IW = """#!/bin/sh
case "$*" in
  *link) printf '%s' "$LINK" ;;
  *"station dump") printf '%s' "$DUMP" ;;
esac
"""
IP = "#!/bin/sh\necho 'default via 10.0.0.1 dev wlan0'\n"
NOTIFY = '#!/bin/sh\nprintf "%s" "$4" >"$OUT"\n'  # args: -u low TITLE BODY


class StatusMenuWifiTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory(prefix="status-menu-wifi-test-")
        self.addCleanup(temp.cleanup)
        root = Path(temp.name)
        self.out = root / "notification"
        self.bin = root / "bin"
        self.bin.mkdir()
        for name, body in (
            ("fuzzel", FUZZEL),
            ("iw", IW),
            ("ip", IP),
            ("notify-send", NOTIFY),
        ):
            (self.bin / name).write_text(body)
            (self.bin / name).chmod(0o755)
        for name in ("awk", "basename", "cat", "grep", "sed"):
            (self.bin / name).symlink_to(f"/usr/bin/{name}")
        self.sysfs = root / "net"
        (self.sysfs / "wlan0").mkdir(parents=True)
        (self.sysfs / "wlan0/phy80211").touch()

    def notification(self, *, avg, link):
        lines = f"\tsignal:  \t{link} [{link}] dBm\n"
        if avg is not None:
            lines += f"\tsignal avg:\t{avg} dBm\n"
        lines += "\tbeacon signal avg:\t-51 dBm\n"
        env = {
            "PATH": str(self.bin),
            "LC_ALL": "C.UTF-8",
            "NET_SYSFS": str(self.sysfs),
            "OUT": str(self.out),
            "LINK": LINK.format(link=link),
            "DUMP": DUMP.format(lines=lines),
        }
        result = subprocess.run(
            ["/bin/bash", str(ROOT / "bash/status-menu")],
            env=env,
            capture_output=True,
            text=True,
            timeout=10,
            check=False,
        )
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stderr, "")
        return self.out.read_text()

    def test_signal_word_boundaries(self):
        cases = {
            -55: "excellent",
            -56: "very good",
            -61: "very good",
            -62: "good",
            -67: "good",
            -68: "fair",
            -75: "fair",
            -76: "weak",
            -85: "weak",
            -86: "very weak",
        }
        for dbm, word in cases.items():
            with self.subTest(dbm=dbm):
                text = self.notification(avg=dbm, link=-30)
                self.assertTrue(text.endswith(f" · {word} signal"), text)

    def test_two_lines_with_details_below_the_name(self):
        text = self.notification(avg=-59, link=-30)
        name, details = text.split("\\n")
        self.assertTrue(name.endswith("Home  (active)"), name)
        self.assertEqual(details, "     867 Mb/s · very good signal")

    def test_average_wins_over_the_last_frame(self):
        text = self.notification(avg=-80, link=-40)
        self.assertIn("weak signal", text)

    def test_link_reading_used_without_an_average(self):
        # The beacon average line must not be mistaken for the plain one.
        text = self.notification(avg=None, link=-70)
        self.assertTrue(text.endswith(" · fair signal"), text)

    def test_no_reading_leaves_only_the_bitrate(self):
        (self.bin / "iw").write_text(
            "#!/bin/sh\n"
            'case "$*" in *link) printf "Connected to x\\n\\tSSID: Home\\n'
            '\\trx bitrate: 100.0 MBit/s\\n" ;; esac\n'
        )
        self.notification(avg=None, link=0)
        self.assertTrue(self.out.read_text().endswith("\\n     100 Mb/s"))


if __name__ == "__main__":
    unittest.main()
