"""Exercise the Cargo/Zig helper with fixtures; never download, build or install tools."""

import fcntl
import hashlib
import io
import json
import os
from pathlib import Path
import signal
import subprocess
import tarfile
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "bash/herdr-cargo"
COMMIT = "b" * 40
OLD_COMMIT = "a" * 40
REPO = "https://github.com/herdrdev/herdr"


class HerdrCargoTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="herdr-cargo-test-")
        self.addCleanup(self.tmp.cleanup)
        self.base = Path(self.tmp.name)
        self.home = self.base / "home with spaces"
        self.home.mkdir()
        self.root = self.home / ".cargo"
        self.bin = self.base / "bin"
        self.bin.mkdir()
        self.fixtures = self.base / "fixtures"
        self.fixtures.mkdir()
        self.cache = self.base / "cache with spaces"
        self.tempdir = self.base / "tmp"
        self.tempdir.mkdir()
        self.log = self.base / "calls.jsonl"
        self.fixture(
            "release.json",
            json.dumps(
                {"tag_name": "v0.9.5", "draft": False, "prerelease": False}
            ),
        )
        self.fixture(
            "release.yml",
            """steps:
  - name: Rust
    uses: dtolnay/rust-toolchain@commit
    with:
      toolchain: 1.99.1
  - name: Zig
    uses: vercel-labs/setup-zig@commit
    with:
      version: '0.16.0'
  - name: Bun
    uses: oven-sh/setup-bun@commit
    with:
      version: 1.3.14
""",
        )
        self.fixture(
            "build.zig.zon", '.{\n .minimum_zig_version = "0.16.0",\n}\n'
        )
        self.fixture(
            "Cargo.toml",
            '[package]\nname = "herdr"\nversion = "0.9.5"\n[dependencies]\n',
        )
        archive = self.fixtures / "zig.tar.xz"
        payload = b'#!/bin/sh\nprintf "%s\\n" "0.16.0"\n'
        with tarfile.open(archive, "w:xz") as bundle:
            entry = tarfile.TarInfo("zig-x86_64-linux-0.16.0/zig")
            entry.mode = 0o755
            entry.size = len(payload)
            bundle.addfile(entry, io.BytesIO(payload))
        self.zig_sha = hashlib.sha256(archive.read_bytes()).hexdigest()
        self.zig_index()
        # Deliberately construct the environment: no inherited Cargo roots,
        # flags, shell hooks, credentials, XDG directories or locale settings.
        self.env = {
            "HOME": str(self.home),
            "PATH": f"{self.bin}:/usr/bin:/bin",
            "CARGO_HOME": str(self.root),
            "XDG_CACHE_HOME": str(self.cache),
            "TMPDIR": str(self.tempdir),
            "LC_ALL": "C",
            "NO_COLOR": "1",
            "FIXTURES": str(self.fixtures),
            "CALL_LOG": str(self.log),
            "LIVE_ROOT": str(self.root),
            "TEST_COMMIT": COMMIT,
        }
        self.stub(
            "curl",
            """
import shutil
args = sys.argv[1:]
url = next(a for a in args if a.startswith("https://"))
out = args[args.index("--output") + 1]
name = ("release.json" if url.endswith("/releases/latest") else
        "zig-index.json" if url.endswith("/download/index.json") else
        "zig.tar.xz" if url.endswith(".tar.xz") else url.rsplit("/", 1)[-1])
log({"tool":"curl", "url":url})
if os.environ.get("FETCH_FAIL") == name:
    print("fixture download failure", file=sys.stderr)
    sys.exit(22)
shutil.copyfile(Path(os.environ["FIXTURES"]) / name, out)
""",
        )
        self.stub(
            "git",
            """
log({"tool":"git", "args":sys.argv[1:]})
if os.environ.get("HOLD_GIT"):
    import time
    Path(os.environ["HOLD_GIT"]).write_text("holding")
    time.sleep(60)
if os.environ.get("ANNOTATED"):
    print("c" * 40 + "\\trefs/tags/v0.9.5")
    print(os.environ["TEST_COMMIT"] + "\\trefs/tags/v0.9.5^{}")
else:
    print(os.environ["TEST_COMMIT"] + "\\trefs/tags/v0.9.5")
""",
        )
        self.stub(
            "rustc",
            """
if sys.argv[1:] == ["--print", "target-cpus"]:
    print("native - Select host (currently " + os.environ.get("HOST_CPU", "znver4") + ").")
else:
    print("rustc 1.99.1\\nhost: x86_64-unknown-linux-gnu")
""",
        )
        self.stub(
            "cargo",
            """
args = sys.argv[1:]
if args == ["--version"]:
    print("cargo 1.99.1")
    sys.exit(0)
root = Path(args[args.index("--root") + 1])
commit = args[args.index("--rev") + 1]
is_stage = root.name == "stage"
names = ("RUSTFLAGS", "CARGO_ENCODED_RUSTFLAGS", "CARGO_PROFILE_RELEASE_LTO",
         "CARGO_PROFILE_RELEASE_OPT_LEVEL", "CARGO_PROFILE_RELEASE_CODEGEN_UNITS",
         "CARGO_PROFILE_RELEASE_STRIP", "CARGO_PROFILE_RELEASE_PANIC",
         "CARGO_PROFILE_RELEASE_INCREMENTAL", "CARGO_INCREMENTAL", "CARGO_BUILD_JOBS",
         "LIBGHOSTTY_VT_OPTIMIZE", "LIBGHOSTTY_VT_SIMD", "ZIG",
         "CARGO_TARGET_DIR", "CARGO_BUILD_BUILD_DIR", "TMPDIR")
holders = [n for n in os.listdir("/proc/self/fd")
           if os.path.exists(f"/proc/self/fd/{n}") and os.readlink(f"/proc/self/fd/{n}").endswith(".herdr-cargo.lock")]
log({"tool":"cargo", "args":args, "lock_fds":holders, "env":{k:os.environ.get(k) for k in names}})
if os.environ.get("HOLD_BUILD") and is_stage:
    import time
    Path(os.environ["HOLD_BUILD"]).touch()
    time.sleep(60)
if os.environ.get("BUILD_FAIL") and is_stage:
    print("fixture compilation failure", file=sys.stderr)
    sys.exit(55)
if os.environ.get("FINAL_FAIL") and not is_stage:
    print("fixture Cargo install failure", file=sys.stderr)
    sys.exit(56)
version = "0.0.1" if os.environ.get("BAD_STAGE") and is_stage else "0.9.5"
(root / "bin").mkdir(parents=True, exist_ok=True)
binary = root / "bin/herdr"
binary.write_text("#!/bin/sh\\nprintf '%s\\n' 'herdr " + version + "'\\n")
binary.chmod(0o755)
key = "herdr 0.9.5 (git+https://github.com/herdrdev/herdr?rev=" + commit + "#" + commit + ")"
metadata = {"installs":{key:{"bins":["herdr"], "profile":"release"}}}
(root / ".crates2.json").write_text(json.dumps(metadata))
if os.environ.get("MUTATE_LIVE") and is_stage:
    with (Path(os.environ["LIVE_ROOT"]) / "bin/herdr").open("a") as stream:
        stream.write("# concurrent change\\n")
""",
        )

    def fixture(self, name, text):
        (self.fixtures / name).write_text(text)

    def zig_index(self, version="0.16.0", checksum=None):
        self.fixture(
            "zig-index.json",
            json.dumps(
                {
                    version: {
                        "x86_64-linux": {
                            "tarball": f"https://ziglang.org/download/{version}/zig-x86_64-linux-{version}.tar.xz",
                            "shasum": checksum or self.zig_sha,
                        }
                    }
                }
            ),
        )

    def stub(self, name, body):
        header = """#!/usr/bin/python3
import json, os, sys
from pathlib import Path
def log(value):
    with open(os.environ["CALL_LOG"], "a") as stream:
        stream.write(json.dumps(value) + "\\n")
"""
        path = self.bin / name
        path.write_text(header + body)
        path.chmod(0o755)

    def run_helper(self, *args):
        return subprocess.run(
            ["/bin/bash", str(SOURCE), *args],
            env=self.env,
            cwd=self.base,
            capture_output=True,
            text=True,
            timeout=15,
            check=False,
        )

    def calls(self, tool=None):
        rows = (
            [json.loads(line) for line in self.log.read_text().splitlines()]
            if self.log.exists()
            else []
        )
        return [r for r in rows if tool is None or r["tool"] == tool]

    def installed(self, version="0.9.4", commit=OLD_COMMIT, *, registry=False):
        (self.root / "bin").mkdir(parents=True)
        binary = self.root / "bin/herdr"
        binary.write_text(f"#!/bin/sh\nprintf '%s\\n' 'herdr {version}'\n")
        binary.chmod(0o755)
        source = (
            "registry+https://github.com/rust-lang/crates.io-index"
            if registry
            else f"git+{REPO}?tag=v{version}#{commit}"
        )
        key = f"herdr {version} ({source})"
        (self.root / ".crates2.json").write_text(
            json.dumps({"installs": {key: {"bins": ["herdr"]}}})
        )
        return binary.read_bytes()

    def assert_clean(self):
        self.assertEqual(list(self.tempdir.glob("herdr-cargo-check.*")), [])
        self.assertEqual(list((self.cache / "herdr-cargo").glob("build.*")), [])
        if self.root.exists():
            self.assertEqual(list(self.root.glob(".herdr-cargo.??????")), [])

    def test_default_is_read_only_check_and_cleans_metadata(self):
        result = self.run_helper()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Required Zig: 0.16.0", result.stdout)
        self.assertIn("Would build", result.stdout)
        self.assertFalse(self.root.exists())
        self.assertFalse(self.cache.exists())
        self.assertEqual(self.calls("cargo"), [])
        self.assertFalse(
            any(r["url"].endswith(".tar.xz") for r in self.calls("curl"))
        )
        self.assert_clean()

    def test_update_absent_skips_without_network_or_directories(self):
        result = self.run_helper("--update")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("skipping", result.stdout)
        self.assertEqual(self.calls(), [])
        self.assertFalse(self.root.exists())
        self.assertFalse(self.cache.exists())

    def test_install_stages_verifies_pins_and_records_fat_recipe(self):
        self.env.update(CARGO_ENCODED_RUSTFLAGS="poison", CARGO_INCREMENTAL="1")
        result = self.run_helper("--install")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        calls = self.calls("cargo")
        self.assertEqual(len(calls), 2)
        self.assertEqual(
            [call["lock_fds"] for call in calls], [[], []]
        )  # builds must not inherit the lock
        self.assertNotIn("--force", calls[0]["args"])
        self.assertIn("--force", calls[1]["args"])
        self.assertIn(str(self.root), calls[1]["args"])
        for call in calls:
            args, env = call["args"], call["env"]
            self.assertEqual(args[args.index("--git") + 1], REPO)
            self.assertEqual(args[args.index("--rev") + 1], COMMIT)
            self.assertEqual(args[args.index("--bin") + 1], "herdr")
            self.assertIn("--locked", args)
            self.assertEqual(env["CARGO_PROFILE_RELEASE_LTO"], "fat")
            self.assertEqual(env["CARGO_PROFILE_RELEASE_OPT_LEVEL"], "3")
            self.assertEqual(env["CARGO_PROFILE_RELEASE_CODEGEN_UNITS"], "1")
            self.assertEqual(env["CARGO_PROFILE_RELEASE_STRIP"], "symbols")
            self.assertEqual(env["CARGO_PROFILE_RELEASE_PANIC"], "unwind")
            self.assertEqual(env["RUSTFLAGS"], "-C target-cpu=znver4")
            self.assertIsNone(env["CARGO_ENCODED_RUSTFLAGS"])
            self.assertIsNone(env["CARGO_INCREMENTAL"])
            self.assertTrue(env["CARGO_TARGET_DIR"].startswith(str(self.cache)))
            self.assertEqual(
                env["CARGO_TARGET_DIR"], env["CARGO_BUILD_BUILD_DIR"]
            )
        self.assertEqual(
            calls[0]["env"]["CARGO_TARGET_DIR"],
            calls[1]["env"]["CARGO_TARGET_DIR"],
        )
        record = json.loads((self.root / ".herdr-cargo.json").read_text())
        self.assertEqual(record["commit"], COMMIT)
        self.assertEqual(record["zig"], "0.16.0")
        self.assertIn("lto=fat", record["recipe"])
        self.assertEqual(
            record["binary_sha256"],
            hashlib.sha256((self.root / "bin/herdr").read_bytes()).hexdigest(),
        )
        self.assert_clean()

    def test_matching_install_skips_compiler_and_archive_download(self):
        self.assertEqual(self.run_helper("--install").returncode, 0)
        before = (self.root / ".herdr-cargo.json").read_bytes()
        self.log.unlink()
        result = self.run_helper("--update")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("Already current", result.stdout)
        self.assertEqual(self.calls("cargo"), [])
        self.assertEqual(len(self.calls("curl")), 1)
        self.assertEqual((self.root / ".herdr-cargo.json").read_bytes(), before)
        self.assert_clean()

    def test_adopts_existing_official_tag_install(self):
        self.installed(version="0.9.5", commit=COMMIT)
        result = self.run_helper("--install")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(len(self.calls("cargo")), 2)
        self.assertTrue((self.root / ".herdr-cargo.json").exists())

    def test_changed_recipe_or_binary_is_rebuilt(self):
        self.assertEqual(self.run_helper("--install").returncode, 0)
        record_path = self.root / ".herdr-cargo.json"
        record = json.loads(record_path.read_text())
        record["recipe"] = "old recipe"
        record_path.write_text(json.dumps(record))
        self.log.unlink()
        self.assertEqual(self.run_helper("--update").returncode, 0)
        self.assertEqual(len(self.calls("cargo")), 2)
        with (self.root / "bin/herdr").open("a") as binary:
            binary.write("# changed\n")
        self.log.unlink()
        self.assertEqual(self.run_helper("--update").returncode, 0)
        self.assertEqual(len(self.calls("cargo")), 2)

    def test_annotated_tag_uses_peeled_commit(self):
        self.env["ANNOTATED"] = "1"
        result = self.run_helper("--install")
        self.assertEqual(result.returncode, 0, result.stderr)
        args = self.calls("cargo")[0]["args"]
        self.assertEqual(args[args.index("--rev") + 1], COMMIT)

    def test_failed_build_and_bad_staged_version_keep_old_install(self):
        before = self.installed()
        metadata = (self.root / ".crates2.json").read_bytes()
        for failure in ("BUILD_FAIL", "BAD_STAGE"):
            with self.subTest(failure=failure):
                self.env[failure] = "1"
                self.log.unlink(missing_ok=True)
                result = self.run_helper("--update")
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual((self.root / "bin/herdr").read_bytes(), before)
                self.assertEqual(
                    (self.root / ".crates2.json").read_bytes(), metadata
                )
                self.assertEqual(len(self.calls("cargo")), 1)
                self.assertFalse((self.root / ".herdr-cargo.json").exists())
                self.assert_clean()
                self.env.pop(failure)

    def test_checksum_failure_keeps_old_install_and_cleans_up(self):
        before = self.installed()
        self.zig_index(checksum="0" * 64)
        result = self.run_helper("--update")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.calls("cargo"), [])
        self.assertEqual((self.root / "bin/herdr").read_bytes(), before)
        self.assert_clean()

    def test_checksum_failure_writes_its_reason_for_the_caller(self):
        self.installed()
        self.zig_index(checksum="0" * 64)
        reason = self.base / "reason"
        self.env["HERDR_CARGO_REASON_FILE"] = str(reason)
        self.assertNotEqual(self.run_helper("--update").returncode, 0)
        self.assertEqual(reason.read_text(), "Zig archive checksum mismatch\n")

    def test_cargo_version_without_spaces_around_equals_is_read(self):
        self.fixture(
            "Cargo.toml",
            '[package]\nname = "herdr"\nversion="0.9.5"\n[dependencies]\n',
        )
        result = self.run_helper("--check")
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertNotIn("disagree", result.stderr)

    def test_stale_build_directories_are_swept_but_recent_ones_kept(self):
        self.installed()
        builds = self.cache / "herdr-cargo"
        stale, recent = builds / "build.stale1", builds / "build.recent"
        for path in (stale, recent):
            path.mkdir(parents=True)
        old = time.time() - 3 * 86400
        os.utime(stale, (old, old))
        self.assertEqual(self.run_helper("--update").returncode, 0)
        self.assertFalse(stale.exists())
        self.assertTrue(recent.exists())

    def test_download_failure_is_reported_and_cleans_up(self):
        self.env["FETCH_FAIL"] = "release.yml"
        result = self.run_helper("--check")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("fixture download failure", result.stderr)
        self.assertEqual(self.calls("cargo"), [])
        self.assert_clean()

    def test_newer_compiler_is_not_substituted_for_ci_pin(self):
        self.fixture(
            "zig-index.json",
            json.dumps(
                {
                    "0.18.0": {
                        "x86_64-linux": {
                            "tarball": "https://ziglang.org/download/0.18.0/zig-x86_64-linux-0.18.0.tar.xz",
                            "shasum": self.zig_sha,
                        }
                    }
                }
            ),
        )
        result = self.run_helper("--install")
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(self.calls("cargo"), [])
        self.assertFalse(
            any(r["url"].endswith(".tar.xz") for r in self.calls("curl"))
        )
        self.assert_clean()

    def test_changed_ci_format_and_inconsistent_minimum_fail_closed(self):
        for content in (
            "steps: []\n",
            (self.fixtures / "release.yml").read_text()
            + "  - uses: someone/setup-zig@commit\n    with:\n      version: 0.17.0\n",
        ):
            with self.subTest(content=content):
                self.fixture("release.yml", content)
                result = self.run_helper("--install")
                self.assertNotEqual(result.returncode, 0)
                self.assertIn("cannot determine", result.stderr)
                self.assertEqual(self.calls("cargo"), [])
                self.assert_clean()

    def test_engine_minimum_newer_than_ci_pin_is_rejected(self):
        self.fixture(
            "build.zig.zon", '.{\n .minimum_zig_version = "0.17.0",\n}\n'
        )
        result = self.run_helper("--check")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("older than the engine minimum", result.stderr)

    def test_prerelease_or_tag_version_mismatch_is_rejected(self):
        self.fixture(
            "release.json",
            json.dumps(
                {
                    "tag_name": "v0.9.6-preview.1",
                    "draft": False,
                    "prerelease": True,
                }
            ),
        )
        result = self.run_helper("--check")
        self.assertNotEqual(result.returncode, 0)
        self.fixture(
            "release.json",
            json.dumps(
                {"tag_name": "v0.9.5", "draft": False, "prerelease": False}
            ),
        )
        self.fixture("Cargo.toml", '[package]\nversion = "0.9.6"\n')
        result = self.run_helper("--check")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("version disagree", result.stderr)

    def test_foreign_install_and_symlink_are_not_overwritten(self):
        before = self.installed(registry=True)
        result = self.run_helper("--install")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("unrecognized", result.stderr)
        self.assertEqual((self.root / "bin/herdr").read_bytes(), before)
        (self.root / "bin/herdr").unlink()
        (self.root / "bin/herdr").symlink_to("/bin/true")
        result = self.run_helper("--install")
        self.assertNotEqual(result.returncode, 0)
        self.assertTrue((self.root / "bin/herdr").is_symlink())
        self.assertEqual(self.calls(), [])

    def test_newer_installed_release_is_not_downgraded(self):
        before = self.installed(version="0.9.6")
        result = self.run_helper("--update")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("refusing to downgrade", result.stderr)
        self.assertEqual(self.calls("cargo"), [])
        self.assertEqual((self.root / "bin/herdr").read_bytes(), before)

    def test_wrong_host_cpu_is_rejected_before_tool_download(self):
        self.env["HOST_CPU"] = "znver3"
        result = self.run_helper("--install")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Zen 4 host", result.stderr)
        self.assertFalse(
            any(r["url"].endswith(".tar.xz") for r in self.calls("curl"))
        )

    def test_concurrent_change_during_build_is_not_overwritten(self):
        before = self.installed()
        self.env["MUTATE_LIVE"] = "1"
        result = self.run_helper("--update")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("changed while the build", result.stderr)
        self.assertEqual(
            (self.root / "bin/herdr").read_bytes(),
            before + b"# concurrent change\n",
        )
        self.assertEqual(len(self.calls("cargo")), 1)
        self.assert_clean()

    def test_concurrent_helper_is_rejected(self):
        self.root.mkdir()
        with (self.root / ".herdr-cargo.lock").open("w") as lock:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            result = self.run_helper("--install")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("another herdr-cargo", result.stderr)
        self.assertEqual(self.calls(), [])

    def test_interrupt_cleans_temporary_work_and_keeps_old_install(self):
        before = self.installed()
        ready = self.base / "building"
        self.env["HOLD_BUILD"] = str(ready)
        proc = subprocess.Popen(
            ["/bin/bash", str(SOURCE), "--update"],
            env=self.env,
            cwd=self.base,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            start_new_session=True,
        )
        try:
            deadline = time.monotonic() + 10
            while (
                not ready.exists()
                and time.monotonic() < deadline
                and proc.poll() is None
            ):
                time.sleep(0.02)
            self.assertTrue(ready.exists())
            os.killpg(proc.pid, signal.SIGINT)
            proc.communicate(timeout=5)
            self.assertEqual(proc.returncode, 130)
            self.assertEqual((self.root / "bin/herdr").read_bytes(), before)
            self.assert_clean()
        finally:
            if proc.poll() is None:
                os.killpg(proc.pid, signal.SIGKILL)
                proc.communicate()

    def test_ctrl_c_reaches_a_slow_git_lookup_at_once(self):
        # The terminal's SIGINT goes to the foreground process group. Plain `timeout` starts its
        # child in a new group, so Ctrl-C then waited for the whole 90 s limit.
        held = self.base / "git-held"
        self.env["HOLD_GIT"] = str(held)
        proc = subprocess.Popen(
            ["/bin/bash", str(SOURCE), "--check"],
            env=self.env,
            cwd=self.base,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            start_new_session=True,
        )
        try:
            deadline = time.monotonic() + 10
            while (
                not held.exists()
                and time.monotonic() < deadline
                and proc.poll() is None
            ):
                time.sleep(0.02)
            self.assertTrue(held.exists())
            started = time.monotonic()
            os.killpg(proc.pid, signal.SIGINT)
            proc.communicate(timeout=5)
            self.assertEqual(proc.returncode, 130)
            self.assertLess(time.monotonic() - started, 3)
        finally:
            if proc.poll() is None:
                os.killpg(proc.pid, signal.SIGKILL)
                proc.communicate()

    def test_arguments_help_and_explicit_root(self):
        self.assertEqual(self.run_helper("--help").returncode, 0)
        self.assertNotEqual(
            self.run_helper("--install", "--check").returncode, 0
        )
        self.assertNotEqual(self.run_helper("--root").returncode, 0)
        self.assertNotEqual(self.run_helper("--typo").returncode, 0)
        self.assertEqual(self.calls(), [])
        other = self.base / "other root"
        result = self.run_helper("--install", "--root", str(other))
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertTrue((other / "bin/herdr").exists())
        self.assertFalse(self.root.exists())


if __name__ == "__main__":
    unittest.main()
