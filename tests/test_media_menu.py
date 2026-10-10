"""Media menu controls: isolated substitutes, no real players or D-Bus."""
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
    elif args[:2] == ['-a', 'status']:
        print(os.environ.get('STATUSES', ''), end='')
    elif args[-1:] == ['metadata']:
        print(os.environ.get('DEFAULT_PLAYER', 'mpv'))
    elif args[-2:] == ['metadata', 'mpris:length']:
        print(os.environ.get('LENGTH', '100000000'))
    elif args[-1:] == ['position']:
        print(os.environ.get('POSITION', '0'))
        sys.exit(int(os.environ.get('POSITION_STATUS', '0')))
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
    if 'get-property' in args:
        print(os.environ.get('CAN_PREVIOUS', 'b true'))
        sys.exit(int(os.environ.get('PROPERTY_STATUS', '0')))
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
        for tool in ('awk', 'printf', 'cat', 'timeout', 'tee'):
            real = Path('/usr/bin') / tool
            if real.exists():
                (self.bin / tool).symlink_to(real)
        self.env = {'PATH': str(self.bin), 'HOME': str(self.root), 'LC_ALL': 'C.UTF-8',
                    'CALLS': str(self.log), 'SELECTED': '⏹  Stop…',
                    'XDG_RUNTIME_DIR': str(self.runtime), 'NO_COLOR': '1'}

    def run_menu(self, args=(), **env):
        return subprocess.run(['/usr/bin/bash', str(SCRIPT), *args], env=dict(self.env, **env),
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

    def test_previous_restarts_after_three_seconds_for_single_or_multiple_tracks(self):
        for can_previous in ('b false', 'b true'):
            with self.subTest(can_previous=can_previous):
                self.log.unlink(missing_ok=True)
                result = self.run_menu(SELECTED='⏮  Prev', POSITION='3.01',
                                       CAN_PREVIOUS=can_previous,
                                       STATUSES='Paused\tmpv\nPlaying\tspotify_player\n')
                self.assertEqual(result.returncode, 0, result.stderr)
                commands = [c[1] for c in self.calls('playerctl')]
                self.assertIn(['-p', 'spotify_player', 'position', '0'], commands)
                self.assertNotIn(['-p', 'spotify_player', 'previous'], commands)

    def test_previous_near_start_uses_previous_track_if_available(self):
        for position in ('0', '3', '2.99'):
            with self.subTest(position=position):
                self.log.unlink(missing_ok=True)
                result = self.run_menu(SELECTED='⏮  Prev', POSITION=position)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(self.calls('playerctl')[-1][1], ['-p', 'mpv', 'previous'])

    def test_previous_without_previous_track_restarts_even_near_start(self):
        result = self.run_menu(SELECTED='⏮  Prev', POSITION='1.5', CAN_PREVIOUS='b false')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.calls('playerctl')[-1][1], ['-p', 'mpv', 'position', '0'])

    def test_unavailable_position_or_capability_keeps_native_previous(self):
        result = self.run_menu(SELECTED='⏮  Prev', POSITION='', POSITION_STATUS='1',
                               CAN_PREVIOUS='', PROPERTY_STATUS='1')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.calls('playerctl')[-1][1], ['-p', 'mpv', 'previous'])

    def progress_pipe(self):
        pipe = self.runtime / 'wob-playback.pipe'
        os.mkfifo(pipe)
        # Open read/write so the isolated reader cannot hang waiting for a writer.
        fd = os.open(pipe, os.O_RDWR | os.O_NONBLOCK)
        self.addCleanup(os.close, fd)
        return fd

    def test_menu_progress_shows_percentage_for_active_player(self):
        fd = self.progress_pipe()
        result = self.run_menu(SELECTED='▰  Playback Position', POSITION='25',
                               STATUSES='Paused\tmpv\nPlaying\tspotify_player\n')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(os.read(fd, 100), b'25\n')
        self.assertIn(['-p', 'spotify_player', 'metadata', 'mpris:length'],
                      [c[1] for c in self.calls('playerctl')])

    def test_both_seek_shortcuts_refresh_progress_on_the_same_player(self):
        fd = self.progress_pipe()
        for action, offset in (('seek-backward', '15-'), ('seek-forward', '15+')):
            with self.subTest(action=action):
                result = self.run_menu(args=(action,), POSITION='60',
                                       STATUSES='Paused\tmpv.instance-test\n')
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(os.read(fd, 100), b'60\n')
                self.assertIn(['-p', 'mpv.instance-test', 'position', offset],
                              [c[1] for c in self.calls('playerctl')])

    def test_pause_resume_from_menu_and_shortcut_also_shows_progress(self):
        fd = self.progress_pipe()
        for args in ((), ('play-pause',)):
            with self.subTest(args=args):
                result = self.run_menu(args=args, SELECTED='▶/⏸  Play/Pause', POSITION='40',
                                       STATUSES='Playing\tmpv.instance-test\n')
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(os.read(fd, 100), b'40\n')
                commands = [c[1] for c in self.calls('playerctl')]
                toggle_index = max(i for i, c in enumerate(commands) if c[-1] == 'play-pause')
                self.assertEqual(commands[toggle_index], ['-p', 'mpv.instance-test', 'play-pause'])
                self.assertEqual(commands[toggle_index + 1], ['-p', 'mpv.instance-test', 'position'])

    def test_progress_clamps_to_full_bar(self):
        fd = self.progress_pipe()
        result = self.run_menu(args=('progress',), POSITION='101')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(os.read(fd, 100), b'100\n')

    def test_unknown_duration_reports_unavailable_without_showing_false_progress(self):
        fd = self.progress_pipe()
        result = self.run_menu(args=('progress',), LENGTH='0')
        self.assertEqual(result.returncode, 1, result.stderr)
        with self.assertRaises(BlockingIOError):
            os.read(fd, 100)
        self.assertIn('duration unavailable', self.calls('notify-send')[0][1][-1])

    def test_missing_fifo_does_not_create_a_regular_file(self):
        result = self.run_menu(args=('progress',), POSITION='50')
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertFalse((self.runtime / 'wob-playback.pipe').exists())

    def test_fifo_without_reader_does_not_hang(self):
        os.mkfifo(self.runtime / 'wob-playback.pipe')
        result = self.run_menu(args=('progress',), POSITION='50')
        self.assertEqual(result.returncode, 124, result.stderr)


if __name__ == '__main__':
    unittest.main()
