"""bash/codex-limits against a fake `codex app-server`."""

from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
# Like the real server, it answers request 2 only while its input is open:
# after the three requests, a read that times out means the input is still open.
CODEX = """#!/bin/bash
for _ in 1 2 3; do read -r _ || exit 0; done
read -r -t 0.5 _
(($? > 128)) || exit 0
printf '%s\\n' "$REPLIES"
"""
WINDOWS = (
    '"rateLimits":{"primary":{"usedPercent":10.4,"windowDurationMins":300,'
    '"resetsAt":0},"secondary":{"usedPercent":3,"windowDurationMins":10080,'
    '"resetsAt":null}}'
)


class CodexLimitsTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory(prefix="codex-limits-test-")
        self.addCleanup(temp.cleanup)
        self.bin = Path(temp.name)
        (self.bin / "timeout").symlink_to("/usr/bin/timeout")

    def run_limits(self, replies, *, codex=True):
        if codex:
            (self.bin / "codex").write_text(CODEX)
            (self.bin / "codex").chmod(0o755)
        env = {
            "PATH": str(self.bin),
            "REPLIES": "\n".join(replies),
            "LC_ALL": "C",
            "TZ": "UTC",
        }
        return subprocess.run(
            [sys.executable, ROOT / "bash/codex-limits"],
            env=env,
            capture_output=True,
            text=True,
            timeout=20,
            check=False,
        )

    def test_reply_found_by_id_among_other_lines(self):
        result = self.run_limits(
            [
                '{"id":1,"result":{}}',
                "not json",
                '{"method":"account/updated","params":{}}',
                '{"result":{' + WINDOWS + '},"id":2}',
            ]
        )
        self.assertEqual(
            result.stdout,
            "5 h: 10% used, resets Thu 00:00\nWeek: 3% used\n",
        )
        self.assertEqual(result.returncode, 0)

    def test_no_reply_to_request_2(self):
        result = self.run_limits(['{"id":1,"result":{}}'])
        self.assertEqual(result.stdout, "")
        self.assertIn("Codex did not answer", result.stderr)
        self.assertEqual(result.returncode, 1)

    def test_codex_missing(self):
        result = self.run_limits([], codex=False)
        self.assertEqual(result.stdout, "")
        self.assertEqual(result.returncode, 1)


if __name__ == "__main__":
    unittest.main()
