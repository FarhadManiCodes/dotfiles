"""Check maintenance dispatch without updating packages or touching live caches."""

import os
from pathlib import Path
import subprocess
import tempfile
import unittest


FUNCTIONS = Path(__file__).resolve().parents[1] / "zsh/functions"


class MaintenanceShpoolTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="maintenance-shpool-test-")
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.env = dict(os.environ)
        for name in ("SHPOOL_SESSION_NAME", "SHPOOL_SESSION_DIR", "NO_COLOR"):
            self.env.pop(name, None)
        self.env.update(HOME=str(self.root), XDG_RUNTIME_DIR=str(self.root),
                        PATH="/usr/bin:/bin", LC_ALL="C")

    def run_zsh(self, code, *args):
        # Even if the dispatch guard regresses, stop at the first maintenance
        # step using stubs; never let a failing test start a real update/cleanup.
        preamble = '''
source "$1/sysup.zsh"
source "$1/sysclean.zsh"
systemd-inhibit() { return 0; }
_sysup_mirrorlist_check() { :; }
_sysup_pacnew() { :; }
paru() { print -r -- update-body; return 23; }
_sysup_prune_claude_versions() { print -r -- cleanup-body; exit 23; }
'''
        return subprocess.run(
            ["/usr/bin/zsh", "-f", "-c", preamble + code, "test", str(FUNCTIONS), *args],
            env=self.env, cwd=self.root, capture_output=True, text=True, timeout=15)

    def test_outside_session_dispatches_arguments_and_returns_client_status(self):
        for cmd, args in (("sysup", ["--podman-images"]),
                          ("sysclean", ["--all"]), ("sysclean", ["-a"])):
            with self.subTest(cmd=cmd, args=args):
                result = self.run_zsh('''
shift
keep() { printf '<%s>\\n' "$@"; return 27; }
"$@"
''', cmd, *args)
                self.assertEqual(result.returncode, 27, result.stderr)
                self.assertEqual(result.stdout.splitlines(),
                                 [f"<{arg}>" for arg in [cmd, *args]])

    def test_missing_keep_stops_before_any_maintenance(self):
        for cmd in ("sysup", "sysclean"):
            with self.subTest(cmd=cmd):
                result = self.run_zsh('"$2"', cmd)
                self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
                self.assertIn("shpool/keep is required", result.stderr)
                self.assertEqual(result.stdout, "")

    def test_existing_session_runs_without_nesting(self):
        self.env["SHPOOL_SESSION_NAME"] = "fixture-session"
        for cmd in ("sysup", "sysclean"):
            with self.subTest(cmd=cmd):
                result = self.run_zsh('''
keep() { print -r -- nested-session; exit 99; }
"$2"
''', cmd)
                self.assertEqual(result.returncode, 23, result.stdout + result.stderr)
                self.assertNotIn("nested-session", result.stdout)
                self.assertIn("update-body" if cmd == "sysup" else "cleanup-body",
                              result.stdout)

    def test_help_and_bad_update_options_do_not_start_session(self):
        for arg, status in (("--help", 0), ("--bad-option", 2)):
            with self.subTest(arg=arg):
                result = self.run_zsh('''
keep() { print -r -- nested-session; exit 99; }
sysup "$2"
''', arg)
                self.assertEqual(result.returncode, status)
                self.assertNotIn("nested-session", result.stdout)

    def test_keep_executes_argv_with_spaces_and_shell_syntax_literally(self):
        # Simulate shpool's --cmd launch; the fixture rc has no live side effects.
        bindir = self.root / "bin"
        bindir.mkdir()
        shpool = bindir / "shpool"
        shpool.write_text('''#!/bin/sh
[ "$1" = attach ] && [ "$2" = --cmd ] || exit 90
export SHPOOL_SESSION_NAME="$4"
exec /usr/bin/zsh -f -c 'eval "$1"' fixture "$3"
''')
        shpool.chmod(0o755)
        (self.root / ".zshrc").write_text(
            'fixture_command() { printf "<%s>\\n" "$@"; }\n')
        self.env["PATH"] = f"{bindir}:/usr/bin:/bin"
        result = self.run_zsh('''
source "$1/shpool.zsh"
keep fixture_command 'a b' '$(touch forbidden)' "semi;colon"
''')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.splitlines()[-3:],
                         ["<a b>", "<$(touch forbidden)>", "<semi;colon>"])
        self.assertFalse((self.root / "forbidden").exists())
        self.assertEqual(list(self.root.glob("keep.*.zsh")), [])


if __name__ == "__main__":
    unittest.main()
