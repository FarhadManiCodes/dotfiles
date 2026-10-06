"""Exercise watched streams without touching the real clipboard or history."""
import json
import os
from pathlib import Path
import signal
import subprocess
import tempfile
import time
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / 'bash/cliphist-store-guard'
STORE = '''#!/usr/bin/python3
import json, os, pathlib, stat, sys, time
payload = sys.stdin.buffer.read()
runtime = pathlib.Path(os.environ['XDG_RUNTIME_DIR'])
with open(os.environ['CALLS'], 'a') as log:
    log.write(json.dumps({'args': sys.argv[1:], 'state': os.environ.get('CLIPBOARD_STATE'),
                         'payload': payload.hex(),
                         'modes': [stat.S_IMODE(p.stat().st_mode)
                                   for p in runtime.glob('cliphist-capture.*')]}) + '\\n')
time.sleep(float(os.environ.get('STORE_DELAY', '0')))
sys.exit(int(os.environ.get('STORE_STATUS', '0')))
'''


class CliphistStoreGuardTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory(prefix='cliphist-guard-test-')
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name)
        self.runtime = self.root / 'runtime'
        self.runtime.mkdir(mode=0o700)
        self.bin = self.root / 'bin'
        self.bin.mkdir()
        for name in ('mktemp', 'timeout', 'cat', 'rm'):
            (self.bin / name).symlink_to('/usr/bin/' + name)
        store = self.bin / 'cliphist'
        store.write_text(STORE)
        store.chmod(0o755)
        self.log = self.root / 'calls.jsonl'
        self.env = {'PATH': str(self.bin), 'HOME': str(self.root), 'LC_ALL': 'C',
                    'XDG_RUNTIME_DIR': str(self.runtime), 'CLIPBOARD_STATE': 'data',
                    'CALLS': str(self.log)}

    def run_guard(self, payload=b'', **env):
        return subprocess.run(['/bin/bash', str(SCRIPT)], input=payload,
                              env=dict(self.env, **env), capture_output=True, timeout=8)

    def calls(self):
        return [json.loads(line) for line in self.log.read_text().splitlines()] if self.log.exists() else []

    def assert_clean(self):
        self.assertEqual(list(self.runtime.iterdir()), [])

    def test_complete_text_binary_and_empty_streams(self):
        for payload in ('  café\nsecond line\n'.encode(), b'\x89PNG\r\n\x1a\n\x00\xff', b''):
            with self.subTest(payload=payload):
                self.log.unlink(missing_ok=True)
                result = self.run_guard(payload)
                self.assertEqual((result.returncode, result.stdout, result.stderr), (0, b'', b''))
                self.assertEqual(self.calls(), [{'args': ['store'], 'state': 'data',
                                                'payload': payload.hex(), 'modes': [0o600]}])
                self.assert_clean()

    def test_sensitive_copy_never_creates_a_file_or_stores(self):
        result = self.run_guard(b'synthetic secret', CLIPBOARD_STATE='sensitive')
        self.assertEqual((result.returncode, result.stderr), (0, b''))
        self.assertEqual(self.calls(), [])
        self.assert_clean()

    def test_clear_event_reaches_cliphist_with_empty_input(self):
        result = self.run_guard(b'ignored bytes', CLIPBOARD_STATE='clear')
        self.assertEqual(result.returncode, 0)
        self.assertEqual(self.calls(), [{'args': ['store'], 'state': 'clear', 'payload': '', 'modes': []}])
        self.assert_clean()

    def test_nil_event_preserves_empty_store_behavior(self):
        result = self.run_guard(CLIPBOARD_STATE='nil')
        self.assertEqual(result.returncode, 0)
        self.assertEqual(self.calls()[0]['state'], 'nil')
        self.assertEqual(self.calls()[0]['payload'], '')
        self.assert_clean()

    def test_unset_state_still_stores_data(self):
        env = dict(self.env)
        del env['CLIPBOARD_STATE']
        result = subprocess.run(['/bin/bash', str(SCRIPT)], input=b'complete',
                                env=env, capture_output=True, timeout=8)
        self.assertEqual(result.returncode, 0)
        self.assertIsNone(self.calls()[0]['state'])
        self.assert_clean()

    def test_stalled_and_partial_streams_timeout_then_next_copy_succeeds(self):
        for partial in (b'', b'incomplete synthetic copy'):
            with self.subTest(partial=partial):
                self.log.unlink(missing_ok=True)
                started = time.monotonic()
                proc = subprocess.Popen(['/bin/bash', str(SCRIPT)], env=self.env,
                                        stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
                try:
                    proc.stdin.write(partial)
                    proc.stdin.flush()
                    proc.wait(timeout=7)  # Keep the owner's stream open.
                    elapsed = time.monotonic() - started
                    stderr = proc.stderr.read()
                    self.assertEqual(proc.returncode, 124)
                    self.assertGreaterEqual(elapsed, 2.8)
                    self.assertLess(elapsed, 6)
                    self.assertIn(b'capture failed (exit 124)', stderr)
                    self.assertNotIn(b'incomplete synthetic copy', stderr)
                    self.assertEqual(proc.stdout.read(), b'')
                    self.assertEqual(self.calls(), [])
                    self.assert_clean()
                finally:
                    if proc.poll() is None:
                        proc.kill()
                        proc.wait()
                    for stream in (proc.stdin, proc.stdout, proc.stderr):
                        stream.close()
                self.assertEqual(self.run_guard(b'next complete copy').returncode, 0)
                self.assertEqual(self.calls()[0]['payload'], b'next complete copy'.hex())
                self.assert_clean()

    def test_database_write_can_outlast_capture_deadline(self):
        result = self.run_guard(b'complete', STORE_DELAY='3.2')
        self.assertEqual((result.returncode, result.stderr), (0, b''))
        self.assertEqual(len(self.calls()), 1)
        self.assert_clean()

    def test_staging_failure_never_stores(self):
        result = self.run_guard(b'private data', XDG_RUNTIME_DIR=str(self.root / 'missing'))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn(b'cannot stage capture', result.stderr)
        self.assertNotIn(b'private data', result.stderr)
        self.assertEqual(self.calls(), [])
        self.assert_clean()

    def test_missing_runtime_directory_has_no_shared_tmp_fallback(self):
        result = self.run_guard(b'private data', XDG_RUNTIME_DIR='')
        self.assertEqual(result.returncode, 1)
        self.assertIn(b'XDG_RUNTIME_DIR is unset', result.stderr)
        self.assertEqual(self.calls(), [])
        self.assert_clean()

    def test_storage_failure_preserves_status_and_cleans_up(self):
        result = self.run_guard(b'complete', STORE_STATUS='7')
        self.assertEqual(result.returncode, 7)
        self.assertIn(b'storage failed (exit 7)', result.stderr)
        self.assertEqual(len(self.calls()), 1)
        self.assert_clean()

    def test_read_failure_drops_partial_bytes_and_cleans_up(self):
        cat = self.bin / 'cat'
        cat.unlink()
        cat.write_text('#!/bin/bash\nprintf "partial"\nexit 9\n')
        cat.chmod(0o755)
        result = self.run_guard(b'copy')
        self.assertEqual(result.returncode, 9)
        self.assertIn(b'capture failed (exit 9)', result.stderr)
        self.assertEqual(self.calls(), [])
        self.assert_clean()

    def test_termination_cleans_up_staged_file(self):
        proc = subprocess.Popen(['/bin/bash', str(SCRIPT)], env=self.env, stdin=subprocess.PIPE,
                                stdout=subprocess.PIPE, stderr=subprocess.PIPE, start_new_session=True)
        try:
            deadline = time.monotonic() + 2
            while not list(self.runtime.iterdir()) and time.monotonic() < deadline:
                time.sleep(0.01)
            self.assertTrue(list(self.runtime.iterdir()), 'capture started')
            os.killpg(proc.pid, signal.SIGTERM)
            proc.wait(timeout=5)
            self.assertEqual(proc.returncode, 143)
            self.assertEqual(self.calls(), [])
            self.assert_clean()
        finally:
            if proc.poll() is None:
                os.killpg(proc.pid, signal.SIGKILL)
                proc.wait()
            for stream in (proc.stdin, proc.stdout, proc.stderr):
                stream.close()


if __name__ == '__main__':
    unittest.main()
