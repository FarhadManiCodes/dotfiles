"""Exercise bgutil updates with local Git releases and stubbed package downloads.

No network, live helper, uv installation, or system update is touched.
"""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


SOURCE = Path(__file__).resolve().parents[1] / "zsh/functions/sysup.zsh"
GIT = shutil.which("git")
MV = shutil.which("mv")


class BgutilUpdateTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory(prefix="sysup-bgutil-test-")
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        self.helper = self.root / "helper with spaces"
        self.upstream = self.root / "upstream"
        self.bin = self.root / "bin"
        self.bin.mkdir()
        self.log = self.root / "calls"
        self.env = dict(
            os.environ, PATH=f"{self.bin}:/usr/bin:/bin",
            BGUTIL_HELPER=str(self.helper), BGUTIL_UPSTREAM=str(self.upstream),
            BGUTIL_TOOLS=str(self.root / "tools"), BGUTIL_LOG=str(self.log),
            BGUTIL_PLUGIN="2.0.0", BGUTIL_FAIL="", BGUTIL_BUILD_VERSION="2.0.0",
            BGUTIL_NET="up",
            GIT_CONFIG_NOSYSTEM="1", GIT_CONFIG_GLOBAL="/dev/null",
            XDG_RUNTIME_DIR=str(self.root),
        )
        self.script(self.root / "tools/yt-dlp/bin/python", '''
[ "$BGUTIL_FAIL" = metadata ] && exit 1
printf '%s\n' "$BGUTIL_PLUGIN"
''')
        self.script(self.bin / "curl", '''
printf 'curl %s\n' "$*" >> "$BGUTIL_LOG"
[ "$BGUTIL_NET" = down ] && exit 7
exit 0
''')
        self.script(self.bin / "uv", '''
printf 'uv %s\n' "$*" >> "$BGUTIL_LOG"
[ "$*" = 'tool dir' ] || exit 1
printf '%s\n' "$BGUTIL_TOOLS"
''')
        self.script(self.bin / "git", f'''
if [ "$1" = clone ]; then
    printf 'clone %s\n' "$5" >> "$BGUTIL_LOG"
    [ "$BGUTIL_FAIL" = fetch ] && exit 1
    [ "$6" = https://github.com/Brainicism/bgutil-ytdlp-pot-provider.git ] || exit 1
    exec {GIT} clone --quiet --branch "$5" "$BGUTIL_UPSTREAM" "$7"
fi
exec {GIT} "$@"
''')
        self.script(self.bin / "npm", '''
printf 'npm %s\n' "$*" >> "$BGUTIL_LOG"
[ "$*" = 'ci --ignore-scripts --no-audit --no-fund' ] || exit 1
[ "$BGUTIL_FAIL" = npm ] && exit 1
if [ "$BGUTIL_FAIL" = concurrent_edit ]; then
    printf 'user edit\n' >> "$BGUTIL_HELPER/README"
fi
mkdir -p node_modules/.bin
ln -s ../../compiler.sh node_modules/.bin/tsc
''')
        self.script(self.bin / "mv", f'''
if [ "${{3##*/}}" = repo ]; then
    [ "$BGUTIL_FAIL" = swap ] && exit 1
    if [ "$BGUTIL_FAIL" = interrupt ]; then
        kill -TERM "$PPID"
        exit 1
    fi
fi
exec {MV} "$@"
''')
        self.write(self.helper / "README", "original helper\n")
        self.write(self.helper / ".gitignore", "server/build/\n")
        self.write(self.helper / "server/build/generate_once.js", 'console.log("1.3.1");\n')
        self.init_repo(self.helper)
        self.write(self.upstream / "README", "new helper\n")
        self.write(self.upstream / ".gitignore", "server/build/\nserver/node_modules/\n")
        self.script(self.upstream / "server/compiler.sh", '''
printf 'compile\n' >> "$BGUTIL_LOG"
[ "$BGUTIL_FAIL" = compile ] && exit 1
mkdir -p build
if [ "$BGUTIL_FAIL" = validation ]; then
    printf 'process.exit(1);\n' > build/generate_once.js
else
    # --version prints the version; a bare run stands in for token generation,
    # which BGUTIL_FAIL=token makes fail while leaving --version working.
    printf 'const v = "%s";\n' "$BGUTIL_BUILD_VERSION" > build/generate_once.js
    cat >> build/generate_once.js <<'JS'
if (process.argv.includes("--version")) { console.log(v); process.exit(0); }
if (process.env.BGUTIL_FAIL === "token") { process.exit(1); }
console.log('{"poToken":"stub"}');
JS
fi
''')
        self.init_repo(self.upstream)
        self.git(self.upstream, "tag", "2.0.0")

    def write(self, path, content):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content)

    def script(self, path, body):
        self.write(path, "#!/bin/sh\n" + body)
        path.chmod(0o755)

    def git(self, directory, *args):
        subprocess.run(
            [GIT, "-C", str(directory), "-c", "core.hooksPath=/dev/null",
             "-c", "user.name=Fixture", "-c", "user.email=fixture@example.invalid",
             *args], env=self.env, capture_output=True, check=True,
        )

    def init_repo(self, directory):
        self.git(directory, "init", "--quiet")
        self.git(directory, "add", ".")
        self.git(directory, "commit", "--quiet", "-m", "Fixture")

    def run_update(self, code='source "$1"; _sysup_bgutil "$2"'):
        return subprocess.run(
            ["zsh", "-f", "-c", code, "test", str(SOURCE), str(self.helper)],
            env=self.env, capture_output=True, text=True, timeout=30,
        )

    def calls(self):
        return self.log.read_text() if self.log.exists() else ""

    def backups(self):
        return list(self.root.glob("helper with spaces.update.*/previous"))

    def assert_original_preserved(self):
        self.assertEqual((self.helper / "README").read_text(), "original helper\n")
        self.assertFalse(list(self.root.glob("helper with spaces.update.*")))

    def test_matching_version_does_not_fetch_or_build(self):
        self.env["BGUTIL_PLUGIN"] = "1.3.1"
        result = self.run_update()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("already matches", result.stdout)
        self.assertEqual(self.calls(), "uv tool dir\n")
        self.assert_original_preserved()

    def test_absent_helper_is_not_installed(self):
        shutil.rmtree(self.helper)
        result = self.run_update()
        self.assertEqual(result.returncode, 0)
        self.assertIn("not installed", result.stdout)
        self.assertEqual(self.calls(), "")

    def test_upgrade_installs_exact_release_and_retains_backup(self):
        result = self.run_update()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual((self.helper / "README").read_text(), "new helper\n")
        self.assertIn('"2.0.0"', (self.helper / "server/build/generate_once.js").read_text())
        self.assertIn("clone 2.0.0\n", self.calls())
        self.assertEqual(len(self.backups()), 1)
        self.assertEqual((self.backups()[0] / "README").read_text(), "original helper\n")
        again = self.run_update()
        self.assertEqual(again.returncode, 0, again.stderr)
        self.assertEqual(self.calls().count("clone"), 1)

    def test_failed_updates_preserve_old_helper(self):
        for failure in ("metadata", "fetch", "npm", "compile", "validation", "swap", "interrupt"):
            with self.subTest(failure=failure):
                self.env["BGUTIL_FAIL"] = failure
                result = self.run_update()
                self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
                self.assert_original_preserved()

    def test_build_skips_install_scripts(self):
        result = self.run_update()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("npm ci --ignore-scripts --no-audit --no-fund\n", self.calls())

    def test_token_generation_is_the_gate_when_youtube_is_reachable(self):
        # --version alone passed during the --ignore-scripts evaluation from a
        # tree missing a native binary, so a build that compiles but cannot work
        # must not be promoted over a working helper.
        self.env["BGUTIL_FAIL"] = "token"
        result = self.run_update()
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertIn("cannot generate a token", result.stdout)
        self.assert_original_preserved()

    def test_unreachable_youtube_is_not_checked_rather_than_failed(self):
        # A dropped connection must not read as a bad build, or sysup fails and
        # leaves the version mismatch in place.
        self.env["BGUTIL_FAIL"] = "token"
        self.env["BGUTIL_NET"] = "down"
        result = self.run_update()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("NOT CHECKED", result.stdout)
        self.assertNotIn("verified:", result.stdout)
        # Still installed, on the version check alone, with the backup kept.
        self.assertEqual((self.helper / "README").read_text(), "new helper\n")
        self.assertEqual(len(self.backups()), 1)

    def test_successful_token_generation_is_reported(self):
        result = self.run_update()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertIn("verified: the new helper generated a token", result.stdout)
        # The happy path must not consult the network probe at all.
        self.assertNotIn("curl", self.calls())

    def test_wrong_built_version_is_not_installed(self):
        self.env["BGUTIL_BUILD_VERSION"] = "1.3.1"
        result = self.run_update()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("does not match", result.stdout)
        self.assert_original_preserved()

    def test_missing_release_does_not_fall_back_to_latest(self):
        self.env["BGUTIL_PLUGIN"] = "2.0.1"
        result = self.run_update()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("release fetch failed", result.stdout)
        self.assertIn("clone 2.0.1", self.calls())
        self.assert_original_preserved()

    def test_unusable_current_build_is_repaired(self):
        self.write(self.helper / "server/build/generate_once.js", "process.exit(1);\n")
        result = self.run_update()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual((self.helper / "README").read_text(), "new helper\n")
        self.assertEqual(len(self.backups()), 1)

    def test_local_edits_prevent_replacement(self):
        self.write(self.helper / "README", "user edit\n")
        result = self.run_update()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("local changes", result.stdout)
        self.assertNotIn("clone", self.calls())
        self.assertEqual((self.helper / "README").read_text(), "user edit\n")

    def test_edits_during_build_prevent_replacement(self):
        self.env["BGUTIL_FAIL"] = "concurrent_edit"
        result = self.run_update()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("checkout changed", result.stdout)
        self.assertIn("user edit", (self.helper / "README").read_text())
        self.assertFalse(self.backups())

    def test_helper_does_not_replace_parent_exit_trap(self):
        result = self.run_update('''
source "$1"
trap 'echo parent-cleanup' EXIT
_sysup_bgutil "$2" || exit 1
''')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.count("parent-cleanup"), 1)

    def test_sysup_stops_after_uv_if_helper_update_fails(self):
        result = self.run_update('''
source "$1"
systemd-inhibit() { return 0; }
_sysup_mirrorlist_check() { :; }
paru() { :; }
uv() { echo "uv $*"; }
_sysup_bgutil() { echo helper-failed; return 1; }
cargo() { echo must-not-run; }
sysup
''')
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertLess(result.stdout.index("uv tool upgrade --all"), result.stdout.index("helper-failed"))
        self.assertIn("mismatched", result.stdout)
        self.assertNotIn("must-not-run", result.stdout)
        self.assertNotIn("sysup done", result.stdout)


if __name__ == "__main__":
    unittest.main()
