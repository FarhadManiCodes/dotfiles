"""Check what Ctrl-C does in sysup, in a real interactive zsh on a pty.

An interactive shell is the only faithful setting: zsh aborts a function on SIGINT differently in
`zsh -c`, and the terminal delivers the signal to the whole foreground process group.
"""

import os
from pathlib import Path
import pty
import re
import select
import subprocess
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "zsh/functions/sysup.zsh"

STEPS = (
    "_sysup_mirrorlist_check _sysup_bgutil _sysup_yts _sysup_herdr _sysup_prune_claude_versions "
    "_sysup_plugins _sysup_nvim_health _sysup_fwupd_refresh_if_stale _sysup_pacnew"
)


class Terminal:
    """An interactive `zsh -f -i` on a pty running one script, with a real Ctrl-C key."""

    def __init__(self, env, cwd):
        self.pid, self.fd = pty.fork()
        if self.pid == 0:
            os.chdir(cwd)
            os.execvpe("zsh", ["zsh", "-f", "-i"], env)
        self.out = ""
        self.read(0.6)

    def read(self, seconds):
        end = time.monotonic() + seconds
        while time.monotonic() < end:
            if select.select([self.fd], [], [], 0.05)[0]:
                try:
                    data = os.read(self.fd, 4096)
                except OSError:
                    return
                self.out += data.decode(errors="replace").replace("\r", "")

    def type(self, line):
        os.write(self.fd, line.encode() + b"\n")

    def wait_for(self, what, seconds=10, after=0):
        """Wait for text on the terminal (past offset `after`), or for a file (a step whose output
        is captured) to exist."""
        seen = (
            (lambda: what.exists())
            if isinstance(what, Path)
            else (lambda: what in self.out[after:])
        )
        end = time.monotonic() + seconds
        while not seen() and time.monotonic() < end:
            self.read(0.05)
        if not seen():
            raise AssertionError(f"never saw {what!r} in:\n{self.out}")

    def ctrl_c(self):
        os.write(self.fd, b"\x03")

    def close(self):
        for sig in (15, 9):
            try:
                os.kill(self.pid, sig)
            except OSError:
                break
        try:
            os.waitpid(self.pid, 0)
        except OSError:
            pass
        os.close(self.fd)


class SysupCtrlCTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="sysup-ctrl-c-")
        self.addCleanup(self.tmp.cleanup)
        self.base = Path(self.tmp.name)
        self.log = self.base / "calls"
        self.runtime = self.base / "run"
        self.runtime.mkdir()
        bin_dir = self.base / "bin"
        bin_dir.mkdir()
        self.inhibitor_pid = self.base / "inhibitor.pid"
        inhibit = bin_dir / "systemd-inhibit"
        # like the real one: run the command that follows the options
        inhibit.write_text(
            f'#!/bin/sh\necho $$ > {self.inhibitor_pid}\nwhile [ "${{1#--}}" != "$1" ]; do shift; done\nexec "$@"\n'
        )
        inhibit.chmod(0o755)
        self.uv = bin_dir / "uv"
        self.uv.write_text('#!/bin/sh\necho "5 passed in 0.1s"\n')
        self.uv.chmod(0o755)
        self.env = {
            "HOME": str(self.base),
            "PATH": f"{bin_dir}:/usr/bin:/bin",
            "LC_ALL": "C",
            "NO_COLOR": "1",
            "TERM": "dumb",
            "TEST_LOG": str(self.log),
            "XDG_RUNTIME_DIR": str(self.runtime),
            "SHPOOL_SESSION_NAME": "fixture",
        }

    def start(self, stubs, args=""):
        """Start sysup with `stubs` after the defaults on a terminal; returns (terminal, output offset)."""
        script = self.base / "driver.zsh"
        script.write_text(f"""source {SOURCE}
for fn in {STEPS}; do functions[$fn]=':'; done
paru() {{ return 0; }}
uv() {{ return 0; }}
cargo() {{ return 0; }}
claude() {{ print -r -- CLAUDE-RAN >> "$TEST_LOG"; }}
{stubs}
""")
        term = Terminal(self.env, self.base)
        self.addCleanup(term.close)
        term.type("PS1=''")
        term.read(0.2)
        start = len(term.out)
        term.type(f"source {script}; sysup {args}; echo RC=$?")
        return term, start

    def run_sysup(self, stubs, args="", presses=()):
        """Run sysup with `stubs`. Each press is (what to wait for before it, what the terminal must
        show after it): events, not sleeps, so a loaded machine only makes the test slower."""
        term, start = self.start(stubs, args)
        for waiting_for, shows in presses:
            term.wait_for(waiting_for)
            mark = len(term.out)
            term.ctrl_c()
            term.wait_for(shows, after=mark)
        term.type("echo END-$((1+1))")
        term.wait_for("END-2")
        return term.out[start:]

    def ran(self):
        return self.log.read_text().split() if self.log.exists() else []

    def test_first_ctrl_c_skips_the_running_step_and_the_next_one_runs(self):
        out = self.run_sysup(
            "_sysup_plugins() { print PLUGINS-START; sleep 30; }",
            presses=[("PLUGINS-START", "Ctrl-C: skipping")],
        )
        self.assertIn(
            "!! Ctrl-C: skipping the running command in Editor & shell plugins",
            out,
        )
        self.assertEqual(
            out.count(
                "!! skipped with Ctrl-C: the running command in Editor & shell plugins"
            ),
            1,
            out,
        )
        self.assertIn("==> Neovim health", out)
        lines = out.splitlines()
        self.assertIn("==> sysup finished with warnings", lines)
        self.assertNotIn("==> sysup done", lines)
        self.assertIn("RC=1", lines)
        self.assertNotIn("failed", out)

    def test_second_ctrl_c_within_the_window_stops_everything_and_cleans_up(
        self,
    ):
        out = self.run_sysup(
            f"""
_sysup_herdr() {{ print -r -- partial > "$HERDR_CARGO_REASON_FILE"; }}
_sysup_plugins() {{ print PLUGINS-START; sleep 30; }}
_sysup_nvim_health() {{ print NVIM-START; sleep 30; }}
_sysup_fwupd_refresh_if_stale() {{ print -r -- LATER-STEP >> "$TEST_LOG"; }}
""",
            presses=[
                ("PLUGINS-START", "Ctrl-C: skipping"),
                ("NVIM-START", "second Ctrl-C"),
            ],
        )
        self.assertIn("!! second Ctrl-C — stopping sysup", out)
        self.assertNotIn("LATER-STEP", self.ran())
        self.assertNotIn("finished with warnings", out)
        self.assertNotIn("==> sysup done", out)
        self.assertEqual(
            out.count(
                "!! skipped with Ctrl-C: the running command in Editor & shell plugins"
            ),
            1,
            out,
        )  # repeated once
        self.assertEqual(
            [
                p.name
                for p in self.runtime.iterdir()
                if p.name.startswith("sysup-herdr-reason")
            ],
            [],
        )
        pid = int(self.inhibitor_pid.read_text())
        time.sleep(0.3)
        self.assertFalse(
            Path(f"/proc/{pid}").exists(), "the sleep inhibitor outlived sysup"
        )

    def test_a_stopped_run_releases_the_lock_and_removes_its_handler(self):
        self.run_sysup(
            """
_sysup_plugins() { print PLUGINS-START; sleep 30; }
_sysup_nvim_health() { print NVIM-START; sleep 30; }
""",
            presses=[
                ("PLUGINS-START", "Ctrl-C: skipping"),
                ("NVIM-START", "second Ctrl-C"),
            ],
        )
        # a second sysup in the same shell must neither be locked out nor inherit the handler
        lock = subprocess.run(
            ["flock", "-n", str(self.runtime / "sysup.lock"), "true"]
        )
        self.assertEqual(lock.returncode, 0, "the lock file is still held")

    def test_the_handler_does_not_outlive_a_finished_run(self):
        out = self.run_sysup(
            "", args="; print -r -- HANDLER=${+functions[TRAPINT]}"
        )
        self.assertIn("HANDLER=0", out)

    def test_bgutil_is_never_skipped(self):
        out = self.run_sysup(
            """
_sysup_bgutil() { print BG-START; sleep 30; }
_sysup_yts() { print -r -- YTS-RAN >> "$TEST_LOG"; }
""",
            presses=[("BG-START", "skipping is unsafe")],
        )
        self.assertIn("skipping is unsafe — stopping sysup", out)
        self.assertNotIn("YTS-RAN", self.ran())
        self.assertNotIn("CLAUDE-RAN", self.ran())
        self.assertNotIn("bgutil update failed", out)

    def paru_stubs(self, since, boundary="print -r -- 1:2:100"):
        return f'''
stat() {{ {boundary}; }}
tail() {{ print -r -- "{since}"; }}
paru() {{ print PARU-START; sleep 30; }}
'''

    def test_ctrl_c_in_paru_before_the_install_skips_it_and_continues(self):
        out = self.run_sysup(
            self.paru_stubs("[ALPM] running pacman"),
            presses=[("PARU-START", "Ctrl-C: skipping")],
        )
        self.assertIn(
            "!! skipped with Ctrl-C: the running command in System & AUR (paru -Syu); nothing was installed",
            out,
        )
        self.assertEqual(self.ran(), ["CLAUDE-RAN"], out)
        self.assertNotIn("paru failed", out)
        self.assertIn("==> sysup finished with warnings", out)

    def test_a_failing_log_search_counts_as_started(self):
        # grep exits 2 on an error: that must not read as "nothing started"
        out = self.run_sysup(
            self.paru_stubs("[ALPM] running pacman") + "grep() { return 2; }\n",
            presses=[("PARU-START", "skipping is unsafe")],
        )
        self.assertIn("skipping is unsafe — stopping sysup", out)
        self.assertEqual(self.ran(), [], out)

    def test_ctrl_c_in_paru_after_the_install_began_stops_sysup(self):
        out = self.run_sysup(
            self.paru_stubs("[ALPM] transaction started"),
            presses=[("PARU-START", "skipping is unsafe")],
        )
        self.assertIn("skipping is unsafe — stopping sysup", out)
        self.assertEqual(self.ran(), [], out)
        self.assertNotIn("finished with warnings", out)

    def test_ctrl_c_in_paru_after_the_log_was_rotated_or_truncated_stops_sysup(
        self,
    ):
        # The recorded offset means nothing in a different or shorter file, so "nothing started"
        # cannot be concluded from it.
        seen = self.base / "stat-seen"
        for label, later in (("rotated", "9:9:500"), ("truncated", "1:2:10")):
            with self.subTest(label):
                seen.unlink(missing_ok=True)
                self.log.unlink(missing_ok=True)
                boundary = f"if [[ -e {seen} ]]; then print -r -- {later}; else touch {seen}; print -r -- 1:2:100; fi"
                out = self.run_sysup(
                    self.paru_stubs("[ALPM] running pacman", boundary=boundary),
                    presses=[("PARU-START", "skipping is unsafe")],
                )
                self.assertIn("skipping is unsafe — stopping sysup", out)
                self.assertEqual(self.ran(), [], out)

    def test_a_trapint_of_the_users_own_is_put_back(self):
        out = self.run_sysup(
            "TRAPINT() { print USER-HANDLER; }",
            args="; print -r -- RESTORED:${functions[TRAPINT]}",
        )
        restored = [
            l for l in out.splitlines() if l.startswith("RESTORED:")
        ]  # not the echoed command line
        self.assertEqual(len(restored), 1, out)
        self.assertIn("USER-HANDLER", restored[0])

    def test_ctrl_c_in_paru_with_an_unreadable_log_position_stops_sysup(self):
        out = self.run_sysup(
            self.paru_stubs("[ALPM] running pacman", boundary="return 1"),
            presses=[("PARU-START", "skipping is unsafe")],
        )
        self.assertIn("skipping is unsafe — stopping sysup", out)
        self.assertEqual(self.ran(), [], out)

    def test_ctrl_c_with_no_command_running_skips_nothing(self):
        # A key press in a pure-shell moment must not turn a complete run into a warned one.
        out = self.run_sysup(
            """
_sysup_plugins() { print PLUGINS-START; while (( SECONDS < 3 )); do :; done; }
""",
            presses=[("PLUGINS-START", "nothing to skip")],
        )
        self.assertNotIn("skipped with Ctrl-C", out)
        self.assertIn("==> sysup done", out.splitlines())
        self.assertIn("RC=0", out.splitlines())

    def test_a_skip_does_not_hide_a_later_real_failure_in_the_same_step(self):
        out = self.run_sysup(
            """
_sysup_podman_images() { print POD-START; sleep 30; print second image failed; return 1; }
""",
            args="--podman-images",
            presses=[("POD-START", "Ctrl-C: skipping")],
        )
        self.assertIn("!! container image update failed", out)
        self.assertIn(
            "!! skipped with Ctrl-C: the running command in Container images (podman)",
            out,
        )
        self.assertIn("RC=1", out.splitlines())

    def test_the_inhibitor_ends_with_the_shell_however_the_shell_dies(self):
        # Neither the always block nor an EXIT trap runs on SIGHUP or SIGKILL (shpool kill). The
        # inhibitor ends because the kernel hangs up the pty session; a leftover sleep:idle block
        # inhibitor would hold off suspend until reboot.
        term, _ = self.start(
            "_sysup_plugins() { print PLUGINS-START; sleep 30; }"
        )
        term.wait_for("PLUGINS-START")
        pid = int(self.inhibitor_pid.read_text())
        self.assertTrue(Path(f"/proc/{pid}").exists())
        os.kill(term.pid, 9)
        end = time.monotonic() + 5
        while Path(f"/proc/{pid}").exists() and time.monotonic() < end:
            time.sleep(0.05)
        self.assertFalse(
            Path(f"/proc/{pid}").exists(),
            "the sleep inhibitor outlived the sysup shell",
        )

    def test_ctrl_c_skips_one_suite_of_the_own_tool_tests(self):
        for name in ("mathunicode", "paper-refinery", "audio_text"):
            (self.base / "projects" / name).mkdir(parents=True)
            (self.base / "projects" / name / "pyproject.toml").write_text("")
        started = self.base / "uv-started"
        self.uv.write_text(
            f'#!/bin/sh\ncase "$PWD" in *mathunicode) touch {started}; exec sleep 30 ;; esac\n'
            'echo "5 passed in 0.1s"\n'
        )
        out = self.run_sysup(
            "", args="--test-tools", presses=[(started, "Ctrl-C: skipping")]
        )
        self.assertIn("mathunicode: skipped", out)
        self.assertIn("paper-refinery: 5 passed in 0.1s", out)
        self.assertIn("audio_text: 5 passed in 0.1s", out)
        self.assertEqual(
            out.count(
                "!! skipped with Ctrl-C: the running command in Own tools: tests against the newest dependencies"
            ),
            1,
            out,
        )
        self.assertIn("==> sysup finished with warnings", out)
        self.assertEqual(list(self.runtime.glob("sysup-tool-tests.*")), [])

    def test_the_tool_tests_do_not_fire_the_shells_directory_hooks(self):
        (self.base / "projects" / "mathunicode").mkdir(parents=True)
        (self.base / "projects" / "mathunicode" / "pyproject.toml").write_text(
            ""
        )
        out = self.run_sysup(
            """
chpwd() { print -r -- CHPWD-RAN >> "$TEST_LOG"; }
""",
            args="--test-tools",
        )
        self.assertIn("mathunicode: 5 passed in 0.1s", out)
        self.assertNotIn("CHPWD-RAN", self.ran())

    def test_a_stop_in_the_tool_tests_still_reports_the_suites_that_had_finished(
        self,
    ):
        for name in ("mathunicode", "paper-refinery", "audio_text"):
            (self.base / "projects" / name).mkdir(parents=True)
            (self.base / "projects" / name / "pyproject.toml").write_text("")
        paper, audio = self.base / "paper-started", self.base / "audio-started"
        self.uv.write_text(f"""#!/bin/sh
case "$PWD" in
  *mathunicode) echo "1 failed, 4 passed in 0.1s"; exit 1 ;;
  *paper-refinery) touch {paper}; exec sleep 30 ;;
  *audio_text) touch {audio}; exec sleep 30 ;;
esac
""")
        out = self.run_sysup(
            "",
            args="--test-tools",
            presses=[(paper, "Ctrl-C: skipping"), (audio, "second Ctrl-C")],
        )
        self.assertIn(
            "!! tests failed with the latest dependencies: mathunicode", out
        )
        self.assertNotIn("finished with warnings", out)


class TimeoutForegroundTests(unittest.TestCase):
    def test_every_timeout_keeps_its_command_in_the_foreground_process_group(
        self,
    ):
        # A plain `timeout` puts its command in a new process group, which a terminal Ctrl-C never
        # reaches. Every sysup module and the helper are scanned, any flag form included.
        files = [
            ROOT / "zsh/functions/sysup.zsh",
            ROOT / "bash/herdr-cargo",
            *sorted((ROOT / "zsh/functions/sysup").glob("*.zsh")),
        ]
        call = re.compile(r"(?<![\w-])timeout (?!--foreground )[-0-9]")
        for path in files:
            for number, line in enumerate(path.read_text().splitlines(), 1):
                if not line.lstrip().startswith("#"):
                    self.assertIsNone(
                        call.search(line),
                        f"{path.name}:{number}: {line.strip()}",
                    )
        uses = [
            p.name for p in files if "timeout --foreground" in p.read_text()
        ]
        self.assertGreaterEqual(
            len(uses), 3, uses
        )  # the scan found the calls it protects


if __name__ == "__main__":
    unittest.main()
