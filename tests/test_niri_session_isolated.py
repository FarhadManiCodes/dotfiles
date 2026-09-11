"""Offline lifecycle tests: replace fixed client paths in a temporary script copy.

No runtime override exists in the installed launcher. Real flock and the shell's
signal handling are exercised; neither fake can contact a systemd manager.
"""
import json
import os
from pathlib import Path
import select
import signal
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "niri/niri-session-isolated"
MANAGED = {
    "XDG_SESSION_ID", "XDG_SEAT", "XDG_VTNR", "XDG_SESSION_TYPE",
    "XDG_CURRENT_DESKTOP", "XDG_SESSION_DESKTOP",
    "WAYLAND_DISPLAY", "DISPLAY", "NIRI_SOCKET",
}


class IsolatedSessionTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="niri-isolated-test-")
        self.addCleanup(self.tmp.cleanup)
        self.base = Path(self.tmp.name)
        self.runtime = self.base / "run" / str(os.getuid())
        self.runtime.mkdir(parents=True, mode=0o700)
        self.log = self.base / "calls.jsonl"
        self.config = self.base / "fixture.json"
        self.fixture = {
            "metadata": {"Id": "c42", "User": str(os.getuid()), "Remote": "no",
                         "Type": "wayland", "Seat": "seat0", "VTNr": "2"},
            "active": "inactive", "fail": "", "block": False,
            "signal_at": "",
        }
        self.env = {
            "XDG_SESSION_ID": "c42", "XDG_SEAT": "seat0", "XDG_VTNR": "2",
            "PATH": str(self.base / "hostile-path"), "SHELL": "/bad/login-shell",
            "HOME": "/bad/home", "ENV": "/bad/startup", "BASH_ENV": "/bad/startup",
            "IPYTHONDIR": "/shell/ipython", "CENTRAL_VENVS": "/shell/venvs",
            "OPENBLAS_NUM_THREADS": "99", "XDG_CONFIG_HOME": "/bad/config",
            "SYSTEMD_BUS_ADDRESS": "unix:path=/bad/manager",
            "DBUS_SESSION_BUS_ADDRESS": "unix:path=/bad/session",
            "DBUS_SYSTEM_BUS_ADDRESS": "unix:path=/bad/system",
            "XDG_RUNTIME_DIR": "/bad/runtime", "SYSTEMD_HOST": "bad-host",
        }
        fake_source = '''#!/usr/bin/python3
import json, os, pathlib, signal, sys
config = json.loads(pathlib.Path(CONFIG).read_text())
kind = pathlib.Path(sys.argv[0]).name
args = sys.argv[1:]
with open(LOG, "a") as stream:
    stream.write(json.dumps({"kind": kind, "args": args, "env": dict(os.environ)}) + "\\n")
if kind == "loginctl":
    if config["fail"] == "metadata":
        print("metadata failed", file=sys.stderr)
        sys.exit(17)
    assert args[:2] == ["show-session", "self"], args
    # loginctl takes one property per flag, unlike systemctl's comma list.
    properties = [a.removeprefix("--property=") for a in args if a.startswith("--property=")]
    print("\\n".join(k + "=" + v for k, v in config["metadata"].items() if k in properties))
    sys.exit(0)
if "show" in args:
    stage = "show"
elif "reset-failed" in args:
    stage = "reset"
elif "set-environment" in args:
    stage = "set"
elif "unset-environment" in args:
    stage = "clear" if "XDG_SESSION_ID" in args else "stale"
elif "niri-shutdown.target" in args:
    stage = "shutdown"
elif args == ["--user", "stop", "niri.service"]:
    stage = "stop"
elif args == ["--user", "--wait", "start", "niri.service"]:
    stage = "start"
else:
    raise RuntimeError(args)
if config["signal_at"] == stage:
    os.kill(os.getppid(), signal.SIGTERM)
if stage == "reset" and config["active"] != "failed":
    # A fresh manager may have no in-memory unit. ResetFailedUnit does not load it.
    print("Failed to reset failed state of unit niri.service: Unit niri.service not loaded.", file=sys.stderr)
    sys.exit(5)
if stage in config["fail"].split(","):
    print(stage + " failed", file=sys.stderr)
    sys.exit(17)
if stage == "show":
    assert args == ["--user", "show", "niri.service", "--property=ActiveState", "--value", "--no-pager"], args
    print(config["active"])
if stage == "start" and config["block"]:
    print("READY", flush=True)
    signal.pause()
'''
        fake_source = fake_source.replace("CONFIG", repr(str(self.config)))
        fake_source = fake_source.replace("LOG", repr(str(self.log)))
        source = SOURCE.read_text().replace("/run/user/", str(self.base / "run") + "/")
        for client in ("systemctl", "loginctl"):
            path = self.base / client
            path.write_text(fake_source)
            path.chmod(0o755)
            source = source.replace("/usr/bin/" + client, str(path))
        self.launcher = self.base / "launcher"
        self.launcher.write_text(source)

    def spawn(self):
        self.config.write_text(json.dumps(self.fixture))
        process = subprocess.Popen(["/bin/sh", str(self.launcher)], env=self.env,
                                   stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
                                   start_new_session=True)
        def reap():
            # Also reap fake clients if an assertion failed while the launcher waited.
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            process.communicate(timeout=5)
        self.addCleanup(reap)
        return process

    def run_launcher(self):
        process = self.spawn()
        out, err = process.communicate(timeout=5)
        return process.returncode, out, err

    def calls(self):
        return [json.loads(line) for line in self.log.read_text().splitlines()] if self.log.exists() else []

    def mutations(self):
        return [c["args"] for c in self.calls()
                if c["kind"] == "systemctl" and "show" not in c["args"]]

    def ready(self, process):
        self.assertTrue(select.select([process.stdout], [], [], 5)[0], "start never reached")
        self.assertEqual(process.stdout.readline(), "READY\n")

    def test_success_and_environment_boundary(self):
        self.assertEqual(self.run_launcher(), (0, "", ""))
        mutations = self.mutations()
        self.assertEqual([a[1] for a in mutations], ["unset-environment",
                         "set-environment", "--wait", "start", "stop", "unset-environment"])
        self.assertEqual(mutations[0][2:], ["WAYLAND_DISPLAY", "DISPLAY", "NIRI_SOCKET"])
        self.assertEqual(mutations[1][2:], ["XDG_SESSION_ID=c42", "XDG_SEAT=seat0",
                         "XDG_VTNR=2", "XDG_SESSION_TYPE=wayland", "XDG_CURRENT_DESKTOP=niri",
                         "XDG_SESSION_DESKTOP=niri-isolated"])
        self.assertEqual(mutations[-3], ["--user", "start", "--job-mode=replace-irreversibly",
                                        "niri-shutdown.target"])
        self.assertEqual(mutations[-2], ["--user", "stop", "niri.service"])
        self.assertEqual(set(mutations[-1][2:]), MANAGED)
        for call in self.calls():
            env = call["env"]
            self.assertLessEqual(set(env), {"PATH", "LC_ALL", "PWD", "SHLVL", "_", "XDG_RUNTIME_DIR",
                                           "DBUS_SESSION_BUS_ADDRESS", "LC_CTYPE"})
            self.assertEqual(env["PATH"], "/usr/bin:/bin")
            self.assertEqual(env["DBUS_SESSION_BUS_ADDRESS"], "unix:path=" + str(self.runtime / "bus"))

    def test_startup_failures_keep_status_and_cleanup(self):
        for stage in ("reset", "stale", "set", "start", "start,shutdown", "start,stop", "start,clear"):
            with self.subTest(stage=stage):
                self.log.unlink(missing_ok=True)
                self.fixture["fail"] = stage
                self.fixture["active"] = "failed" if stage == "reset" else "inactive"
                code, _, err = self.run_launcher()
                self.assertEqual(code, 17)
                self.assertIn("failed", err)
                self.assertTrue(any("niri-shutdown.target" in a for a in self.mutations()))

    def test_unreachable_manager_and_metadata_failure(self):
        for stage in ("show", "metadata"):
            with self.subTest(stage=stage):
                self.log.unlink(missing_ok=True)
                self.fixture["fail"] = stage
                self.assertEqual(self.run_launcher()[0], 17)
                self.assertEqual(self.mutations(), [])

    def test_invalid_inherited_metadata(self):
        for name in ("XDG_SESSION_ID", "XDG_SEAT", "XDG_VTNR"):
            for value in ("", "bad\nvalue", "$(touch /tmp/never-execute)", "--help"):
                with self.subTest(name=name, value=value):
                    original = self.env[name]
                    self.env[name] = value
                    self.assertNotEqual(self.run_launcher()[0], 0)
                    self.assertEqual(self.mutations(), [])
                    self.env[name] = original

    def test_logind_mismatch(self):
        for key, value in (("User", "99999"), ("Id", "c99"), ("Remote", "yes"),
                           ("Type", "tty"), ("Seat", "seat1"), ("VTNr", "3")):
            with self.subTest(key=key):
                original = self.fixture["metadata"][key]
                self.fixture["metadata"][key] = value
                self.assertNotEqual(self.run_launcher()[0], 0)
                self.assertEqual(self.mutations(), [])
                self.fixture["metadata"][key] = original

    def test_existing_session_rejected(self):
        for state in ("active", "activating", "deactivating", "reloading", "", "unknown"):
            with self.subTest(state=state):
                self.fixture["active"] = state
                self.assertNotEqual(self.run_launcher()[0], 0)
                self.assertEqual(self.mutations(), [])

    def test_failed_service_can_restart(self):
        self.fixture["active"] = "failed"
        self.assertEqual(self.run_launcher()[0], 0)
        self.assertEqual(self.mutations()[0], ["--user", "reset-failed", "niri.service"])

    def test_cleanup_failure_is_visible(self):
        for stage in ("shutdown", "stop", "clear"):
            with self.subTest(stage=stage):
                self.log.unlink(missing_ok=True)
                self.fixture["fail"] = stage
                code, _, err = self.run_launcher()
                self.assertEqual(code, 1)
                self.assertIn("failed", err)
                if stage in ("shutdown", "stop"):
                    self.assertIn("retaining session variables", err)
                    self.assertIn(["--user", "stop", "niri.service"], self.mutations())
                    self.assertNotIn("XDG_SESSION_ID", self.mutations()[-1])

    def test_missing_metadata_and_invalid_runtime(self):
        for key in tuple(self.fixture["metadata"]):
            with self.subTest(missing=key):
                value = self.fixture["metadata"].pop(key)
                self.assertNotEqual(self.run_launcher()[0], 0)
                self.assertEqual(self.mutations(), [])
                self.fixture["metadata"][key] = value
        self.runtime.chmod(0o755)
        self.assertNotEqual(self.run_launcher()[0], 0)
        self.assertEqual(self.mutations(), [])

    def test_termination_during_setup(self):
        for stage in ("reset", "stale", "set"):
            with self.subTest(stage=stage):
                self.log.unlink(missing_ok=True)
                self.fixture["signal_at"] = stage
                self.fixture["active"] = "failed" if stage == "reset" else "inactive"
                code, _, _ = self.run_launcher()
                self.assertEqual(code, 143)
                self.assertFalse(any("--wait" in a for a in self.mutations()))
                self.assertEqual(set(self.mutations()[-1][2:]), MANAGED)

    def test_signal_with_failed_shutdown_still_stops_service(self):
        self.fixture.update(block=True, fail="shutdown")
        process = self.spawn()
        self.ready(process)
        process.send_signal(signal.SIGTERM)
        _, err = process.communicate(timeout=5)
        self.assertEqual(process.returncode, 143)
        self.assertIn("retaining session variables", err)
        self.assertEqual(self.mutations()[-1], ["--user", "stop", "niri.service"])

    def test_duplicate_lock_and_signal_teardown(self):
        self.fixture["block"] = True
        first = self.spawn()
        self.ready(first)
        before = self.mutations()
        code, _, err = self.run_launcher()
        self.assertEqual(code, 1)
        self.assertIn("session lock", err)
        self.assertEqual(self.mutations(), before)
        first.send_signal(signal.SIGTERM)
        first.communicate(timeout=5)
        self.assertEqual(first.returncode, 143)
        self.assertEqual(set(self.mutations()[-1][2:]), MANAGED)
        self.fixture["block"] = False
        self.assertEqual(self.run_launcher()[0], 0)  # lock released, same inode reusable

    def test_other_signals(self):
        self.fixture["block"] = True
        for sig in (signal.SIGHUP, signal.SIGINT):
            with self.subTest(signal=sig):
                process = self.spawn()
                self.ready(process)
                process.send_signal(sig)
                process.communicate(timeout=5)
                self.assertEqual(process.returncode, 128 + sig)
                self.assertEqual(set(self.mutations()[-1][2:]), MANAGED)

    def test_launcher_syntax_including_embedded_shell(self):
        source = SOURCE.read_text()
        body = source.split("<<'SESSION'\n", 1)[1].rsplit("\nSESSION", 1)[0]
        for script in (source, body):
            subprocess.run(["/bin/sh", "-n"], input=script, text=True, check=True)
            lint = subprocess.run(["/usr/bin/shellcheck", "--shell=sh", "-"],
                                  input=script, text=True, capture_output=True)
            self.assertEqual(lint.returncode, 0, lint.stdout + lint.stderr)
        for forbidden in ("import-environment", "dbus-update-activation-environment",
                          "/dev/null", "source ", ".zshenv", ".zprofile"):
            self.assertNotIn(forbidden, source)

    def test_session_desktop_entry(self):
        entry = ROOT / "niri/niri-isolated.desktop"
        self.assertEqual(entry.read_text(), "[Desktop Entry]\n"
                         "Name=Niri (isolated environment)\n"
                         "Exec=/usr/local/bin/niri-session-isolated\n"
                         "Type=Application\nDesktopNames=niri\n")
        # DesktopNames is a display-manager extension, also in packaged niri.desktop.
        validation = subprocess.run(["/usr/bin/desktop-file-validate", str(entry)],
                                    capture_output=True, text=True)
        # Accept future validators that recognise DesktopNames, while rejecting
        # any other diagnostic from the installed validator.
        if validation.returncode:
            self.assertEqual(validation.stdout + validation.stderr,
                             f'{entry}: error: file contains key "DesktopNames" in group '
                             '"Desktop Entry", but keys extending the format should start with "X-"\n')
        standard = self.base / "standard.desktop"
        standard.write_text(entry.read_text().replace("DesktopNames=niri\n", ""))
        subprocess.run(["/usr/bin/desktop-file-validate", str(standard)], check=True)


if __name__ == "__main__":
    unittest.main()
