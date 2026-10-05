"""Power-menu requests use isolated substitutes; no real power or mount actions."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / 'bash/powermenu'

# Absolute interpreter and private PATH: a missing substitute cannot fall through
# to the host's systemctl, inhibitor, compositor or session manager.
FAKE = '''#!/usr/bin/python3
import json, os, pathlib, subprocess, sys
name = pathlib.Path(sys.argv[0]).name
args = sys.argv[1:]
with open(os.environ['CALLS'], 'a') as log:
    log.write(json.dumps([name, args, os.environ.get('INHIBITED', '')]) + '\\n')
if name == 'fuzzel':
    prompt = args[args.index('--prompt') + 1]
    print(os.environ['SELECTED'] if prompt == 'Power: ' else os.environ['CONFIRM'])
    sys.exit(int(os.environ.get('FUZZEL_STATUS', '0')))
if name == 'systemd-inhibit':
    status = int(os.environ.get('INHIBIT_STATUS', '0'))
    if status:
        print('inhibitor acquisition denied', file=sys.stderr)
        sys.exit(status)
    env = dict(os.environ, INHIBITED='yes')
    # All flags precede the child's absolute script path.
    child = next(i for i, arg in enumerate(args) if not arg.startswith('--'))
    result = subprocess.run(args[child:], env=env)
    with open(os.environ['CALLS'], 'a') as log:
        log.write(json.dumps(['inhibitor-released', [], '']) + '\\n')
    sys.exit(result.returncode)
if name == 'systemctl':
    teardown = args == ['--user', 'stop', 'rclone@*']
    status = int(os.environ.get('STOP_STATUS' if teardown else 'REQUEST_STATUS', '0'))
    if status and not os.environ.get('SILENT_FAILURE'):
        print('rclone stop failed' if teardown else 'power request denied', file=sys.stderr)
    sys.exit(status)
if name == 'notify-send':
    sys.exit(int(os.environ.get('NOTIFY_STATUS', '0')))
'''


class PowerMenuTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory(prefix='powermenu-test-')
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name)
        self.bin = self.root / 'bin'
        self.bin.mkdir()
        self.log = self.root / 'calls.jsonl'
        for name in ('fuzzel', 'systemd-inhibit', 'systemctl', 'notify-send', 'niri', 'loginctl'):
            path = self.bin / name
            path.write_text(FAKE)
            path.chmod(0o755)
        (self.bin / 'realpath').symlink_to('/usr/bin/realpath')
        self.link = self.bin / 'powermenu'
        self.link.symlink_to(SCRIPT)
        self.env = {'PATH': str(self.bin), 'HOME': str(self.root), 'LC_ALL': 'C.UTF-8',
                    'CALLS': str(self.log), 'SELECTED': '🛑 Shutdown', 'CONFIRM': 'Yes'}

    def run_menu(self, *args, **env):
        return subprocess.run([str(self.link), *args], env=dict(self.env, **env),
                              capture_output=True, text=True, timeout=10)

    def calls(self):
        return [json.loads(line) for line in self.log.read_text().splitlines()] if self.log.exists() else []

    def test_confirmed_requests_are_ordered_inside_inhibitor(self):
        for selected, action in [('🛑 Shutdown', 'poweroff'), ('🔄 Reboot', 'reboot')]:
            with self.subTest(action=action):
                self.log.unlink(missing_ok=True)
                result = self.run_menu(SELECTED=selected)
                self.assertEqual((result.returncode, result.stderr), (0, ''))
                calls = self.calls()
                self.assertEqual([c[0] for c in calls],
                                 ['fuzzel', 'fuzzel', 'systemd-inhibit', 'systemctl',
                                  'systemctl', 'inhibitor-released'])
                self.assertEqual(calls[2][1], ['--what=sleep:idle:handle-lid-switch',
                                             '--mode=block', str(SCRIPT), '--inhibited', action])
                self.assertEqual(calls[3], ['systemctl', ['--user', 'stop', 'rclone@*'], 'yes'])
                self.assertEqual(calls[4], ['systemctl', [action], 'yes'])

    def test_canceled_confirmation_never_starts_teardown(self):
        for selected in ('🛑 Shutdown', '🔄 Reboot'):
            for answer in ('No', ''):
                with self.subTest(selected=selected, answer=answer):
                    self.log.unlink(missing_ok=True)
                    self.run_menu(SELECTED=selected, CONFIRM=answer)
                    self.assertEqual([c[0] for c in self.calls()], ['fuzzel', 'fuzzel'])

    def assert_failure(self, env, status, diagnostic, system_calls):
        result = self.run_menu(**env)
        self.assertEqual(result.returncode, status)
        self.assertIn(diagnostic, result.stderr)
        calls = self.calls()
        self.assertEqual([c for c in calls if c[0] == 'systemctl'], system_calls)
        notice = calls[-1]
        self.assertEqual(notice[0], 'notify-send')
        self.assertEqual(notice[1][:3], ['-u', 'critical', 'Power request failed'])
        self.assertIn(diagnostic, notice[1][3])
        self.assertIn(f'exit {status}', notice[1][3])
        self.assertEqual(notice[2], '', 'notification runs after inhibitor release')

    def test_inhibitor_failure_never_stops_mounts(self):
        self.assert_failure({'INHIBIT_STATUS': '13'}, 13, 'inhibitor acquisition denied', [])

    def test_teardown_failure_prevents_each_request(self):
        for selected in ('🛑 Shutdown', '🔄 Reboot'):
            with self.subTest(selected=selected):
                self.log.unlink(missing_ok=True)
                self.assert_failure({'SELECTED': selected, 'STOP_STATUS': '7'}, 7, 'rclone stop failed',
                                    [['systemctl', ['--user', 'stop', 'rclone@*'], 'yes']])

    def test_final_request_failure_preserves_diagnostic_and_status(self):
        for selected, action in [('🛑 Shutdown', 'poweroff'), ('🔄 Reboot', 'reboot')]:
            with self.subTest(action=action):
                self.log.unlink(missing_ok=True)
                self.assert_failure({'SELECTED': selected, 'REQUEST_STATUS': '9'}, 9,
                                    'power request denied',
                                    [['systemctl', ['--user', 'stop', 'rclone@*'], 'yes'],
                                     ['systemctl', [action], 'yes']])

    def test_notification_failure_does_not_replace_operation_status(self):
        self.assert_failure({'STOP_STATUS': '7', 'NOTIFY_STATUS': '42'}, 7, 'rclone stop failed',
                            [['systemctl', ['--user', 'stop', 'rclone@*'], 'yes']])

    def test_silent_failure_has_notification_fallback(self):
        result = self.run_menu(STOP_STATUS='7', SILENT_FAILURE='yes')
        self.assertEqual(result.returncode, 7)
        self.assertIn('No diagnostic output', self.calls()[-1][1][3])

    def test_invalid_arguments_fail_before_any_external_command(self):
        for args in [('--inhibited',), ('--inhibited', 'suspend'),
                     ('--inhibited', 'poweroff', 'extra'), ('--other', 'poweroff'),
                     ('reboot',), ('--inhibited', '')]:
            with self.subTest(args=args):
                result = self.run_menu(*args)
                self.assertEqual(result.returncode, 2)
                self.assertIn('Usage:', result.stderr)
                self.assertEqual(self.calls(), [])

    def test_other_actions_retain_existing_behavior(self):
        for selected, expected in [
                ('🔒 Lock', [['loginctl', ['lock-session'], '']]),
                ('💤 Suspend', [['systemctl', ['suspend'], '']]),
                ('🚪 Logout', [['systemctl', ['--user', 'stop', 'rclone@*'], ''],
                              ['niri', ['msg', 'action', 'quit'], '']])]:
            with self.subTest(selected=selected):
                self.log.unlink(missing_ok=True)
                result = self.run_menu(SELECTED=selected)
                self.assertEqual(result.returncode, 0)
                self.assertEqual([c for c in self.calls() if c[0] != 'fuzzel'], expected)


if __name__ == '__main__':
    unittest.main()
