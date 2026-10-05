"""Exercise the real sleep hook with isolated systemctl and logger stubs."""
from pathlib import Path
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]


class FprintdResumeTests(unittest.TestCase):
  def run_hook(self, phase, status=0):
    with tempfile.TemporaryDirectory(prefix="fprintd-resume-test-") as directory:
      fixture = Path(directory)
      for command, body in {
        "systemctl": 'printf "%s\\n" "$*" >> "$CALLS"\n'
                     'if (( SYSTEMCTL_STATUS != 0 )); then\n'
                     '  echo "mock manager refused request" >&2\n'
                     'fi\nexit "$SYSTEMCTL_STATUS"\n',
        "logger": 'printf "%s\\n" "$*" >> "$LOGS"\n',
      }.items():
        stub = fixture / command
        stub.write_text("#!/bin/bash\n" + body)
        stub.chmod(0o755)
      calls, logs = fixture / "calls", fixture / "logs"
      result = subprocess.run(
        ["/bin/bash", str(ROOT / "system-sleep/fprintd-resume"), phase, "suspend"],
        env={"PATH": str(fixture), "LC_ALL": "C", "CALLS": str(calls),
             "LOGS": str(logs), "SYSTEMCTL_STATUS": str(status)},
        capture_output=True, text=True, timeout=5,
      )
      self.assertEqual(result.returncode, 0, result.stderr)
      self.assertEqual(result.stdout + result.stderr, "")
      return (calls.read_text() if calls.exists() else "",
              logs.read_text() if logs.exists() else "")

  def test_pre_does_not_request_restart(self):
    self.assertEqual(self.run_hook("pre"), ("", ""))

  def test_post_submits_asynchronous_conditional_restart(self):
    calls, logs = self.run_hook("post")
    self.assertEqual(calls, "--no-block try-restart fprintd.service\n")
    self.assertEqual(logs, "-t fprintd-resume post: submitted conditional restart request for fprintd.service\n")

  def test_submission_failure_is_logged(self):
    calls, logs = self.run_hook("post", status=1)
    self.assertEqual(calls, "--no-block try-restart fprintd.service\n")
    self.assertEqual(logs, "-t fprintd-resume post: FAILED to submit conditional restart request for fprintd.service: mock manager refused request\n")


if __name__ == "__main__":
  unittest.main()
