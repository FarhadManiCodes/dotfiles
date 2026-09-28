"""Check opt-in Quadlet image updates without Podman, network, or live services."""

import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


SOURCE = Path(__file__).resolve().parents[1] / "zsh/functions/sysup.zsh"
ZSH = shutil.which("zsh")
AWK = shutil.which("awk")


class PodmanImageUpdateTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="sysup-podman-test-")
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.bin = self.root / "bin"
        self.bin.mkdir()
        (self.bin / "awk").symlink_to(AWK)
        self.log = self.root / "calls"
        self.marker = self.root / "pulled"
        self.quadlets = self.root / "config/containers/systemd"
        self.quadlets.mkdir(parents=True)
        self.image = "docker.io/library/postgres:18"
        self.quadlet("pg", self.image)
        self.env = dict(os.environ)
        self.env.pop("NO_COLOR", None)
        self.env.update(
            PATH=str(self.bin), HOME=str(self.root), XDG_CONFIG_HOME=str(self.root / "config"),
            XDG_RUNTIME_DIR=str(self.root), LC_ALL="C", SYSUP_TEST_LOG=str(self.log),
            SYSUP_PULL_MARKER=str(self.marker), SYSUP_BEFORE="old", SYSUP_AFTER="new",
            SYSUP_SERVICE_STATE="inactive", SYSUP_PULL_FAIL="",
        )

        for name in ("stat", "flock", "paru", "uv", "cargo", "claude"):
            self.script(name, f'''printf '{name} %s\\n' "$*" >> "$SYSUP_TEST_LOG"
exit 0
''')
        self.script("podman", '''
case "$1 $2" in
  'image inspect')
    printf 'inspect %s\\n' "$3" >> "$SYSUP_TEST_LOG"
    if [ -e "$SYSUP_PULL_MARKER" ]; then
      printf '%s\\n' "$SYSUP_AFTER"
    else
      printf '%s\\n' "$SYSUP_BEFORE"
    fi ;;
  'pull -q')
    printf 'pull %s\\n' "$3" >> "$SYSUP_TEST_LOG"
    [ -z "$SYSUP_PULL_FAIL" ] || exit 7
    printf 'yes\\n' > "$SYSUP_PULL_MARKER" ;;
  *) exit 2 ;;
esac
''')
        self.script("systemctl", '''
case "$1 $2" in
  '--user show')
    printf 'show %s\\n' "$3" >> "$SYSUP_TEST_LOG"
    printf '%s\\n' "$SYSUP_SERVICE_STATE" ;;
  '--user restart')
    printf 'restart %s\\n' "$3" >> "$SYSUP_TEST_LOG" ;;
  *) exit 2 ;;
esac
''')

    def script(self, name, body):
        path = self.bin / name
        path.write_text("#!/bin/sh\n" + body)
        path.chmod(0o755)

    def quadlet(self, name, image):
        (self.quadlets / f"{name}.container").write_text(
            f"[Container]\nImage={image}\n")

    def run_sysup(self, *args):
        code = '''
source "$1"
shift
for fn in _sysup_mirrorlist_check _sysup_bgutil _sysup_yts \\
          _sysup_prune_claude_versions _sysup_plugins _sysup_nvim_health \\
          _sysup_fwupd_refresh_if_stale _sysup_pacnew; do
  functions[$fn]=':'
done
sysup "$@"
'''
        return subprocess.run(
            [ZSH, "-f", "-c", code, "test", str(SOURCE), *args],
            env=self.env, capture_output=True, text=True, timeout=30,
        )

    def calls(self):
        return self.log.read_text().splitlines() if self.log.exists() else []

    def test_default_sysup_does_not_touch_images(self):
        result = self.run_sysup()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertNotIn("Container images", result.stdout)
        self.assertFalse(any(c.startswith(("inspect", "pull", "show", "restart"))
                             for c in self.calls()))

    def test_option_updates_stopped_quadlet_without_starting_it(self):
        result = self.run_sysup("--podman-images")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn(f"pull {self.image}", self.calls())
        self.assertIn("show pg.service", self.calls())
        self.assertFalse(any(c.startswith("restart ") for c in self.calls()))

    def test_option_restarts_only_changed_running_quadlet(self):
        self.env["SYSUP_SERVICE_STATE"] = "active"
        result = self.run_sysup("--podman-images")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("restart pg.service", self.calls())

        self.log.unlink()
        self.marker.unlink()
        self.env["SYSUP_AFTER"] = "old"
        result = self.run_sysup("--podman-images")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertFalse(any(c.startswith("restart ") for c in self.calls()))

    def test_shared_image_is_pulled_once_and_both_running_units_restart(self):
        self.quadlet("analytics", self.image)
        self.env["SYSUP_SERVICE_STATE"] = "active"
        result = self.run_sysup("--podman-images")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(self.calls().count(f"pull {self.image}"), 1)
        self.assertIn("restart pg.service", self.calls())
        self.assertIn("restart analytics.service", self.calls())

    def test_pull_failure_is_reported_without_restart(self):
        self.env["SYSUP_SERVICE_STATE"] = "active"
        self.env["SYSUP_PULL_FAIL"] = "yes"
        result = self.run_sysup("--podman-images")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("pull failed", result.stdout)
        self.assertFalse(any(c.startswith("restart ") for c in self.calls()))

    def test_unknown_option_does_no_update_work(self):
        result = self.run_sysup("--not-an-option")
        self.assertEqual(result.returncode, 2)
        self.assertIn("unknown option", result.stderr)
        self.assertEqual(self.calls(), [])


if __name__ == "__main__":
    unittest.main()
