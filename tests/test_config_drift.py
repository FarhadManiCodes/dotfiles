"""Run isolated checker sections against temporary files and stubbed system tools.

    python3 -B -m unittest discover -s tests -v

No live configuration, package manager, tmux server or systemd manager is changed.
"""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest


SCRIPT = (Path(__file__).resolve().parents[1] / "bash/config-drift").read_text()


def section(start, end):
    return SCRIPT.split(start, 1)[1].split(end, 1)[0]


PREAMBLE = r'''
set -uo pipefail
export LC_ALL=C
shopt -s nullglob
issues=0
skipped=0
verbose=1
hdr() { :; }
ok() { printf 'OK %s\n' "$1"; }
warn() { printf 'WARN %s\n' "$1"; issues=$((issues+1)); }
skip() { printf 'SKIP %s\n' "$1"; skipped=$((skipped+1)); }
'''


class ConfigDriftTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="config-drift-test-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.env = dict(os.environ, df_dir=str(self.root), XDG_CONFIG_HOME=str(self.root / "live"))

    def write(self, name, content):
        path = self.root / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content)
        return path

    def run_section(self, code, setup=""):
        result = subprocess.run(
            ["bash", "-c", PREAMBLE + setup + "\n" + code + '\nprintf "COUNTS %s %s\\n" "$issues" "$skipped"\n'],
            env=self.env, capture_output=True, text=True, timeout=10, check=True,
        )
        self.assertEqual(result.stderr, "")
        return result.stdout

    def test_spotify(self):
        code = section('hdr "Spotify config matches the template"', '# ------------------------------------------------ /etc against its baselines')
        base = 'client_id = "SECRET_TEMPLATE"\nblank = ""\nnumber = 1\n[device]\nvolume = 70\nclient_id = "nested"\n'
        cases = [
            (base.replace("SECRET_TEMPLATE", "SECRET_LIVE"), None),
            ('# comment\n' + base.replace('number = 1', 'number=1 # same'), None),
            (base.replace('client_id = "SECRET_TEMPLATE"\n', ''), None),
            (base.replace('volume = 70', 'volume = 71'), 'different setting: "device"'),
            (base.replace('client_id = "nested"', 'client_id = "other"'), 'different setting: "device"'),
            (base.replace('blank = ""', 'blank = "nonempty"'), 'different setting: "blank"'),
            (base.replace('number = 1\n', ''), 'missing from live config: "number"'),
            ('extra = 1\n' + base, 'only in live config: "extra"'),
            (base.replace('number = 1', 'number = true'), 'different setting: "number"'),
            ('client_id = "SECRET_INVALID', 'not compared: live config'),
            (None, 'not compared: live config'),
        ]
        template = self.write('spotify-player/app.toml', base)
        live = self.root / 'live/spotify-player/app.toml'
        for value, expected in cases:
            with self.subTest(value=value):
                if value is None:
                    live.unlink(missing_ok=True)
                else:
                    self.write('live/spotify-player/app.toml', value)
                output = self.run_section(code)
                self.assertNotIn('SECRET', output)
                self.assertIn('COUNTS 0 0' if expected is None else 'COUNTS 1 0', output)
                if expected:
                    self.assertIn(expected, output)
                self.assertEqual(template.read_text(), base)
                self.assertEqual(live.read_text() if live.exists() else None, value)
        self.write('live/spotify-player/app.toml', base)
        for value in ['invalid = [', None]:
            if value is None:
                template.unlink()
            else:
                template.write_text(value)
            output = self.run_section(code)
            self.assertIn('not compared: template', output)
            self.assertIn('COUNTS 1 0', output)
        output = self.run_section(code, 'python3() { return 127; }')
        self.assertIn('not compared: Python check failed', output)

    def test_toml_nested_order_and_types(self):
        code = section('hdr "Spotify config matches the template"', '# ------------------------------------------------ /etc against its baselines')
        cases = [
            ('x = {a=1, b={c=2, d=3}}', 'x = {b={d=3, c=2}, a=1}', False),
            ('x = [nan, 2]', 'x = [nan, 2]', False),
            ('x = [1, 2]', 'x = [2, 1]', True),
            ('x = 1', 'x = 1.0', True),
            ('x = 2026-09-06', 'x = "2026-09-06"', True),
        ]
        for template, live, differs in cases:
            with self.subTest(template=template, live=live):
                self.write('spotify-player/app.toml', template)
                self.write('live/spotify-player/app.toml', live)
                self.assertIn(f'COUNTS {int(differs)} 0', self.run_section(code))

    def test_last_transaction_only_and_incomplete_transaction(self):
        code = section('# Standalone: inspect the last transaction. sysup supplies a device:inode:bytes\n', '# ------------------------------------------------- root configs installed')
        # Redirect the hard-coded log path to a fixture; retain the real parser.
        code = code.replace('plog=/var/log/pacman.log', 'plog="$df_dir/pacman.log"')
        old = '[old] [ALPM] transaction started\n[old] [ALPM-SCRIPTLET] ==> ERROR old\n'
        new = '[new] [ALPM] transaction started\n[new] [ALPM] transaction completed\n'
        self.write('pacman.log', old + new)
        output = self.run_section(code)
        self.assertIn('clean (new)', output)
        self.assertNotIn('ERROR old', output)
        self.write('pacman.log', '[new] [ALPM] transaction started\n')
        self.assertIn('no completion record', self.run_section(code))
        self.write('pacman.log', new + '[new] [ALPM-SCRIPTLET] ==> Building image\n')
        self.assertIn('never reported success', self.run_section(code))
        (self.root / 'pacman.log').unlink()
        self.assertIn('not readable', self.run_section(code))

    def test_update_transaction_window(self):
        code = section('# Standalone: inspect the last transaction. sysup supplies a device:inode:bytes\n', '# ------------------------------------------------- root configs installed')
        code = code.replace('plog=/var/log/pacman.log', 'plog="$df_dir/pacman.log"')
        old = '[old] [ALPM] transaction started\n[old] [ALPM-SCRIPTLET] ==> ERROR old\n'
        log = self.write('pacman.log', old)
        st = log.stat()
        boundary = f'{st.st_dev}:{st.st_ino}:{st.st_size}'
        setup = f'pacman_since={boundary}'
        failed = '[first] [ALPM] transaction started\n[first] [ALPM] transaction completed\n[first] [ALPM-SCRIPTLET] ==> ERROR failed hook\n'
        good = '[last] [ALPM] transaction started\n[last] [ALPM] transaction completed\n[last] [ALPM-SCRIPTLET] Initcpio image generation successful\n'
        for first, expected in [
            (failed, 'failed hook'),
            ('[first] [ALPM] transaction started\n', 'no completion record (first)'),
            ('[first] [ALPM] transaction started\n[first] [ALPM] transaction completed\n[first] [ALPM-SCRIPTLET] ==> Building image\n', 'never reported success (first)'),
        ]:
            with self.subTest(expected=expected):
                log.write_text(old + first + good)
                output = self.run_section(code, setup)
                self.assertIn(expected, output)
                self.assertIn('clean (last)', output)
                self.assertNotIn('ERROR old', output)
        log.write_text(old)
        self.assertIn('not readable', self.run_section(code, setup + '\ntail() { return 1; }'))
        self.assertIn('no new ALPM transaction', self.run_section(code, setup))
        log.write_text('')
        self.assertIn('coverage incomplete', self.run_section(code, setup))
        log.rename(self.root / 'rotated.log')
        self.write('pacman.log', old + good)
        self.assertIn('coverage incomplete', self.run_section(code, setup))
        self.assertIn('boundary unavailable', self.run_section(code, 'pacman_since=unavailable'))
        log.unlink()
        self.assertIn('coverage incomplete', self.run_section(code, setup))

    def test_sysup_boundary_and_failure_reporting(self):
        source = (Path(__file__).resolve().parents[1] / 'zsh/functions/sysup.zsh').read_text()
        stage = source.split('  echo "==> System & AUR (paru -Syu)"', 1)[1].split('  echo "==> uv tools"', 1)[0]
        final = source.split('  echo "==> Config drift"', 1)[1].split('  echo "==> sysup done"', 1)[0]
        helper = source.split('_sysup_pacnew() {', 1)[1].split('\n}', 1)[0]
        stage = stage.replace('/var/log/pacman.log', '"$HOME/pacman.log"')
        log = self.write('pacman.log', 'old log\n')
        st = log.stat()
        expected = f'--pacman-since {st.st_dev}:{st.st_ino}:{st.st_size}'
        checker = self.write('.local/bin/config-drift', '#!/bin/sh\nprintf "CHECK %s\\n" "$*"\nexit 9\n')
        checker.chmod(0o755)
        for status in (0, 42):
            with self.subTest(status=status):
                script = (
                    'paru() { print NEW >> "$HOME/pacman.log"; return ' + str(status) + '; }\n'
                    + '_sysup_pacnew() {' + helper + '\n}\n'
                    + 'run_update() {' + stage + '\necho LATER_STEPS\n' + final + '\nreturn 0\n}\n'
                    + 'run_update\nresult=$?\necho RESULT=$result\n'
                )
                log.write_text('old log\n')
                result = subprocess.run(['zsh', '-f', '-c', script],
                    env=dict(self.env, HOME=str(self.root)), capture_output=True, text=True, check=True, timeout=10)
                self.assertEqual(result.stderr, '')
                self.assertEqual(result.stdout.count('CHECK '), 1)
                self.assertIn('CHECK ' + expected, result.stdout)
                self.assertIn(f'RESULT={status}', result.stdout)
                self.assertEqual('LATER_STEPS' in result.stdout, status == 0)

    def test_expected_links(self):
        code = section('hdr "Symlink integrity"', '# ------------------------------------------------------- plugin staleness')
        self.env['HOME'] = str(self.root / 'home')
        live = self.root / 'live'
        live.mkdir()
        target = self.write('starship.toml', 'config')
        link = live / 'starship.toml'
        self.write('tracked', 'starship.toml\n')
        setup = 'git() { cat "$df_dir/tracked"; }'
        self.assertIn('missing expected symlink', self.run_section(code, setup))
        link.write_text('config')
        self.assertIn('detached (not a symlink)', self.run_section(code, setup))
        link.unlink()
        wrong = self.write('other.toml', 'config')
        link.symlink_to(wrong)
        self.assertIn('wrong symlink target', self.run_section(code, setup))
        link.unlink()
        link.symlink_to('../starship.toml')
        self.assertIn('COUNTS 0 0', self.run_section(code, setup))
        # Valid links unrelated to the installer may point outside the repo.
        external = self.write('home/external', 'external')
        (live / 'unmanaged').symlink_to(external)
        self.assertIn('COUNTS 0 0', self.run_section(code, setup))
        target.unlink()
        output = self.run_section(code, setup)
        self.assertIn('expected repo source unavailable', output)
        self.assertNotIn('expected config links match', output)
        target.write_text('config')
        link.unlink()
        link.symlink_to('absent')
        self.assertEqual(self.run_section(code, setup).count('dangling symlink:'), 1)
        self.assertIn('cannot list tracked files', self.run_section(code, 'git() { return 1; }'))

    def test_directory_and_special_link_mappings(self):
        code = section('hdr "Symlink integrity"', '# ------------------------------------------------------- plugin staleness')
        self.env['HOME'] = str(self.root / 'home')
        mappings = {
            'nvim': 'live/nvim',
            'vim/vimrc': 'live/vim',
            'pcmanfm-qt/settings.conf': 'live/pcmanfm-qt/default/settings.conf',
            'containers/pg.container': 'live/containers/systemd/pg.container',
            'applications/example.desktop': 'home/.local/share/applications/example.desktop',
            'ptpython/config.py': 'home/.config/ptpython/config.py',
            'skills/example/SKILL.md': 'home/.claude/skills/example',
            'zsh/.zshrc': 'home/.zshrc',
        }
        for rel, dest in mappings.items():
            if rel == 'nvim':
                source = self.root / rel
                source.mkdir()
            else:
                source = self.write(rel, 'config')
            if rel in ('vim/vimrc', 'skills/example/SKILL.md'):
                source = source.parent
            link = self.root / dest
            link.parent.mkdir(parents=True, exist_ok=True)
            link.symlink_to(source)
        self.write('tracked', '\n'.join(mappings))
        setup = 'git() { cat "$df_dir/tracked"; }'
        self.assertIn('COUNTS 0 0', self.run_section(code, setup))
        link = self.root / 'live/nvim'
        link.unlink()
        link.symlink_to(self.root / 'vim')
        self.assertIn('wrong symlink target', self.run_section(code, setup))
        link.unlink()
        link.mkdir()
        self.assertIn('detached (not a symlink)', self.run_section(code, setup))

    def test_optional_and_copy_link_exceptions(self):
        code = section('hdr "Symlink integrity"', '# ------------------------------------------------------- plugin staleness')
        self.env['HOME'] = str(self.root / 'home')
        (self.root / 'live').mkdir()
        names = ['spotify-player/app.toml', 'etc/vconsole.conf', 'pam/swaylock',
                 'README.md', 'foliate/settings.dconf', 'firefox/userChrome.css']
        for rel in names:
            self.write(rel, 'config')
        self.write('home/.vimrc', 'generated bootstrap')
        self.write('live/spotify-player/app.toml', 'local copy')
        self.write('tracked', '\n'.join(names))
        setup = 'git() { cat "$df_dir/tracked"; }'
        self.assertIn('COUNTS 0 0', self.run_section(code, setup))
        self.write('home/.mozilla/firefox/profiles.ini', '[Install123]\nDefault=example.default\n')
        self.assertIn('missing expected symlink', self.run_section(code, setup))
        dest = self.root / 'home/.mozilla/firefox/example.default/chrome/userChrome.css'
        dest.parent.mkdir(parents=True)
        dest.symlink_to(self.root / 'firefox/userChrome.css')
        self.assertIn('COUNTS 0 0', self.run_section(code, setup))

    def test_root_comparison_status(self):
        code = 'check_root() {' + section('check_root() {', '# README.md documents')
        code += '\ncheck_root "$df_dir/source" "$df_dir/destination"\n'
        self.write('source', 'same')
        self.write('destination', 'same')
        self.assertIn('COUNTS 0 0', self.run_section(code, 'drift=0'))
        self.write('destination', 'different')
        output = self.run_section(code, 'drift=0')
        self.assertIn('review both before syncing', output)
        self.assertNotIn('copy it back', output)
        output = self.run_section(code, 'drift=0\ncmp() { return 2; }')
        self.assertIn('comparison failed', output)
        self.assertNotIn('differs from', output)
        (self.root / 'source').unlink()
        self.assertIn('unreadable or missing', self.run_section(code, 'drift=0'))

    def test_baseline_differences_and_partial_scan(self):
        code = 'check_baseline() {' + section('check_baseline() {', '# Keep producer exit statuses')
        self.write('baseline', '# comment\n/etc/b\n/etc/a\n/etc/a\n')
        run = code + '\ncheck_baseline test "$df_dir/baseline" "$observed" "$complete"\n'
        output = self.run_section(run, "etc_base=0; observed=$'/etc/c\\n/etc/a'; complete=1")
        self.assertIn('+ /etc/c', output)
        self.assertIn('- /etc/b', output)
        output = self.run_section(run, "etc_base=0; observed=$'/etc/c\\n/etc/a'; complete=0")
        self.assertIn('+ /etc/c', output)
        self.assertNotIn('- /etc/b', output)
        self.write('baseline', '')
        output = self.run_section(run, "etc_base=0; observed=''; complete=1")
        self.assertIn('COUNTS 0 0', output)
        (self.root / 'baseline').unlink()
        self.assertIn('baseline not compared', self.run_section(run, "etc_base=0; observed=''; complete=1"))

    def test_failed_pacman_inventory(self):
        code = section('hdr "/etc against its baselines"', '# ------------------------------------------------------ symlink integrity')
        output = self.run_section(code, 'pacman() { return 1; }; find() { printf "/etc/example\\n"; }')
        self.assertIn('unowned files not compared', output)
        self.assertIn('modified files not compared', output)
        self.assertNotIn('OK', output)

    def test_pacman_backup_header_and_continuation_paths(self):
        code = section('hdr "/etc against its baselines"', '# ------------------------------------------------------ symlink integrity')
        self.write('etc/unowned.txt', '')
        self.write('etc/modified.txt', '/etc/one\n/etc/two\n')
        stub = r'''
find() { printf '/etc/one\n/etc/two\n'; }
pacman() {
  if [[ $1 == -Qlq ]]; then
    printf '/etc/one\n/etc/two\n'
  else
    printf 'Backup Files    : /etc/one [modified]\n                  /etc/two [modified]\n'
  fi
}
'''
        output = self.run_section(code, stub)
        self.assertIn('COUNTS 0 0', output)
        self.assertNotIn('Backup Files', output)

    def test_pacdiff_failure_is_not_empty_success(self):
        code = section('hdr "Pending .pacnew"', '# ------------------------------------------------- last pacman transaction')
        self.assertIn('none pending', self.run_section(code, 'pacdiff() { return 0; }'))
        output = self.run_section(code, 'pacdiff() { return 1; }')
        self.assertIn('pacdiff failed', output)
        self.assertNotIn('none pending', output)

    def test_user_units_batched_and_status_checked(self):
        code = section('hdr "systemd user units verify"', '# ------------------------------------------------------------------ summary')
        self.write('systemd/user/a.service', '[Service]\nExecStart=/bin/true\n')
        self.write('systemd/user/b.timer', '[Timer]\nOnBootSec=1\n')
        stub = 'systemd-analyze() { [[ $1 == --user && $2 == verify && $# == 4 ]]; }'
        self.assertIn('2 user unit files verify clean', self.run_section(code, stub))
        output = self.run_section(code, 'systemd-analyze() { return 1; }')
        self.assertIn('verification needs attention (exit 1)', output)
        self.assertNotIn('verify clean', output)


if __name__ == '__main__':
    unittest.main()
