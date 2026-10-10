"""The media menu's Stop: isolated substitutes, no real players or D-Bus."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / 'bash/media-menu.sh'

# Absolute interpreter and a private PATH: a missing substitute cannot fall
# through to the host's players, D-Bus or compositor.
FAKE = '''#!/usr/bin/python3
import json, os, pathlib, sys
name = pathlib.Path(sys.argv[0]).name
args = sys.argv[1:]
stdin = sys.stdin.read() if name == 'fuzzel' else ''
with open(os.environ['CALLS'], 'a') as log:
    log.write(json.dumps([name, args, stdin]) + '\\n')
if name == 'playerctl':
    if args[:2] == ['-a', 'metadata']:
        print(os.environ.get('PLAYERS', ''), end='')
    sys.exit(0)
if name == 'fuzzel':
    prompt = args[args.index('--prompt') + 1]
    if prompt == 'Media > ':
        print(os.environ['SELECTED'])
        sys.exit(0)
    pick = os.environ.get('PICK', '')
    lines = [l for l in stdin.splitlines() if pick and pick in l]
    if not lines:
        sys.exit(1)  # Esc
    print(lines[0])
    sys.exit(0)
if name == 'busctl':
    sys.exit(int(os.environ.get('QUIT_STATUS', '0')))
sys.exit(0)
'''

MPV = 'mpv\tPaused · Fukuyama on Trump\n'
SPOTIFY = 'spotify_player\tPlaying · A song\n'
FIREFOX = 'firefox.instance_1_813\tPlaying · A tab\n'


class MediaMenuStopTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory(prefix='media-menu-test-')
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name)
        self.bin = self.root / 'bin'
        self.bin.mkdir()
        self.runtime = self.root / 'runtime'
        self.runtime.mkdir()
        self.log = self.root / 'calls.jsonl'
        for name in ('fuzzel', 'playerctl', 'busctl', 'notify-send'):
            path = self.bin / name
            path.write_text(FAKE)
            path.chmod(0o755)
        for tool in ('awk', 'printf', 'cat'):
            real = Path('/usr/bin') / tool
            if real.exists():
                (self.bin / tool).symlink_to(real)
        self.env = {'PATH': str(self.bin), 'HOME': str(self.root), 'LC_ALL': 'C.UTF-8',
                    'CALLS': str(self.log), 'SELECTED': '⏹  Stop…',
                    'XDG_RUNTIME_DIR': str(self.runtime), 'NO_COLOR': '1'}

    def run_menu(self, **env):
        return subprocess.run(['/usr/bin/bash', str(SCRIPT)], env=dict(self.env, **env),
                              capture_output=True, text=True, timeout=10)

    def calls(self, name=None):
        if not self.log.exists():
            return []
        calls = [json.loads(line) for line in self.log.read_text().splitlines()]
        return [c for c in calls if name is None or c[0] == name]

    def test_lists_each_player_by_what_it_plays_and_quits_the_one_picked(self):
        result = self.run_menu(PLAYERS=MPV + SPOTIFY, PICK='Fukuyama')
        self.assertEqual(result.returncode, 0, result.stderr)
        stop_menu = self.calls('fuzzel')[1]
        self.assertEqual(stop_menu[2].splitlines(),
                         ['mpv · Paused · Fukuyama on Trump', 'spotify_player · Playing · A song'])
        self.assertEqual(self.calls('busctl'),
                         [['busctl', ['--user', 'call', 'org.mpris.MediaPlayer2.mpv',
                                      '/org/mpris/MediaPlayer2', 'org.mpris.MediaPlayer2', 'Quit'], '']])
        self.assertNotIn(['-p', 'mpv', 'stop'], [c[1] for c in self.calls('playerctl')])

    def test_firefox_is_never_offered(self):
        result = self.run_menu(PLAYERS=FIREFOX + MPV, PICK='·')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.calls('fuzzel')[1][2].splitlines(), ['mpv · Paused · Fukuyama on Trump'])
        self.assertNotIn('firefox', json.dumps(self.calls('busctl')))

    def test_only_firefox_playing_says_there_is_nothing_to_stop(self):
        result = self.run_menu(PLAYERS=FIREFOX, PICK='·')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(len(self.calls('fuzzel')), 1)  # no Stop list
        self.assertEqual(self.calls('notify-send')[0][1][-1], 'No player to stop')
        self.assertEqual(self.calls('busctl'), [])

    def test_a_player_that_cannot_quit_is_stopped(self):
        result = self.run_menu(PLAYERS=SPOTIFY, PICK='song', QUIT_STATUS='1')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn(['-p', 'spotify_player', 'stop'], [c[1] for c in self.calls('playerctl')])

    def test_esc_in_the_list_stops_nothing(self):
        result = self.run_menu(PLAYERS=MPV, PICK='')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.calls('busctl'), [])
        self.assertNotIn('stop', json.dumps([c[1] for c in self.calls('playerctl')]))


if __name__ == '__main__':
    unittest.main()
