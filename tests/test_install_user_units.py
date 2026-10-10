"""Run the installer in a temporary home with all service/build commands stubbed."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
SOURCE = Path(os.environ.get("INSTALLER_UNDER_TEST", ROOT / "install.sh"))
DOTFILES = Path(os.environ.get("INSTALLER_DOTFILES", ROOT))


class InstallUserUnitsTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="install-user-units-")
        self.addCleanup(self.tmp.cleanup)
        self.base = Path(self.tmp.name)
        self.home = self.base / "home"
        self.home.mkdir()
        self.bin = self.base / "bin"
        self.bin.mkdir()
        self.calls = self.base / "systemctl-calls"
        self.stub("systemctl", '''printf '%s\\n' "$*" >> "$UNIT_CALLS"
if [[ $1 == --user && $2 == enable && " $FAIL_UNITS " == *" $3 "* ]]; then
  printf 'fixture enable failure: %s\\n' "$3" >&2
  exit 1
fi
exit 0
''')
        for command in ("git", "make", "gh", "uv", "podman", "update-desktop-database"):
            self.stub(command, "exit 0\n")
        # Construct the environment rather than inheriting shell hooks, locale,
        # XDG paths or flags that could redirect the fixture outside its home.
        self.env = {
            "HOME": str(self.home),
            "DOTFILES": str(DOTFILES),
            "XDG_CONFIG_HOME": str(self.home / ".config"),
            "XDG_DATA_HOME": str(self.home / ".local/share"),
            "PATH": f"{self.bin}:/usr/bin:/bin",
            "LC_ALL": "C",
            "NO_COLOR": "1",
            "UNIT_CALLS": str(self.calls),
            "FAIL_UNITS": "",
        }

    def stub(self, name, body):
        path = self.bin / name
        path.write_text("#!/bin/bash\n" + body)
        path.chmod(0o755)

    def run_install(self, failures=""):
        self.env["FAIL_UNITS"] = failures
        return subprocess.run(
            ["/bin/bash", str(SOURCE)], cwd=self.base, env=self.env,
            text=True, capture_output=True, timeout=20,
        )

    def test_success_reports_enabled_and_exits_zero(self):
        result = self.run_install()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Systemd user services installed and enabled", result.stdout)
        self.assertIn("Dotfiles installation complete!", result.stdout)
        self.assertNotIn("User units not enabled:", result.stderr)
        self.assertEqual(self.calls.read_text().splitlines()[0], "--user daemon-reload")
        self.assertIn("--user enable wob-playback.socket", self.calls.read_text().splitlines())
        self.assertEqual((self.home / '.config/wob/playback.ini').resolve(),
                         DOTFILES / 'wob/playback.ini')
        for suffix in ('service', 'socket'):
            self.assertEqual((self.home / f'.config/systemd/user/wob-playback.{suffix}').resolve(),
                             DOTFILES / f'systemd/user/wob-playback.{suffix}')

    def test_multiple_failures_preserve_diagnostics_and_finish_later_steps(self):
        result = self.run_install("mic-notify.service wob.socket")
        self.assertEqual(result.returncode, 1, result.stderr)
        calls = self.calls.read_text().splitlines()
        self.assertIn("--user enable ssh-agent.socket", calls)
        self.assertEqual(len([c for c in calls if c.startswith("--user enable ")]), 11)
        self.assertIn("fixture enable failure: mic-notify.service", result.stderr)
        self.assertIn("fixture enable failure: wob.socket", result.stderr)
        summary = result.stderr.split("User units not enabled:\n", 1)[1]
        self.assertEqual(summary, "  mic-notify.service\n  wob.socket\n")
        self.assertNotIn("Systemd user services installed and enabled", result.stdout)
        self.assertNotIn("Dotfiles installation complete!", result.stdout)
        self.assertIn("Agent skills linked", result.stdout)
        self.assertIn("sudo bash install-root.sh", result.stdout)
        self.assertTrue((self.home / ".agents/skills").is_dir())

    def test_successful_rerun_clears_previous_failures(self):
        self.assertEqual(self.run_install("ssh-agent.socket").returncode, 1)
        result = self.run_install()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Dotfiles installation complete!", result.stdout)
        self.assertNotIn("User units not enabled:", result.stderr)


if __name__ == "__main__":
    unittest.main()
