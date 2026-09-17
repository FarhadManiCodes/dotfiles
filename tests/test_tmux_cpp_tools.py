"""Guard tmux-cpp-tools' only destructive path against deleting the wrong tree.

    python3 -B -m unittest discover -s tests -v

find_project_root's first pass returns the path it reads out of
build/CMakeCache.txt, and CMAKE_SOURCE_DIR is absolute, so a cache that travels
with a copied or restored project still names the tree it was built in. Every
other subcommand only builds or reads there; clean-all calls rm -rf.
"""
import re
from pathlib import Path
import subprocess
import tempfile
import unittest


SCRIPT = (Path(__file__).resolve().parents[1] / "bash/tmux-cpp-tools").read_text()


def func(name):
    match = re.search(rf"^{name}\(\) \{{.*?^\}}", SCRIPT, re.S | re.M)
    if not match:
        raise AssertionError(f"{name}() not found in bash/tmux-cpp-tools")
    return match.group(0)


HARNESS = "\n".join([
    "set -uo pipefail",
    "header() { :; }",
    "pause()  { :; }",
    "die()    { printf 'REFUSED: %s\\n' \"$1\" >&2; exit 1; }",
    func("find_project_root"),
    func("require_cmake"),
    func("require_clean_target"),
    "require_cmake",
    "require_clean_target",
    "echo ALLOWED",
])


class CleanAllTargetTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="cpp-tools-test-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)

    def project(self, name, source_dir=None, build=True):
        """A CMake project; source_dir fakes a cache naming another tree."""
        proj = self.root / name
        proj.mkdir(parents=True, exist_ok=True)
        (proj / "CMakeLists.txt").write_text(f"project({name})\n")
        if build:
            (proj / "build").mkdir(exist_ok=True)
            (proj / "build" / "CMakeCache.txt").write_text(
                f"CMAKE_SOURCE_DIR:STATIC={source_dir or proj}\n")
        return proj

    def run_in(self, cwd):
        return subprocess.run(["bash", "-c", HARNESS], cwd=cwd,
                              capture_output=True, text=True, timeout=10)

    def test_refuses_a_cache_naming_another_tree(self):
        victim = self.project("other")
        (victim / "build" / "artifact.txt").write_text("PRECIOUS")
        here = self.project("here", source_dir=victim)

        result = self.run_in(here)
        self.assertEqual(result.returncode, 1)
        self.assertIn("is not the project you are in", result.stderr)
        self.assertNotIn("ALLOWED", result.stdout)
        # The point of the guard: the other project is untouched.
        self.assertTrue((victim / "build" / "artifact.txt").is_file())

    def test_allows_an_ordinary_project(self):
        good = self.project("good")
        result = self.run_in(good)
        self.assertIn("ALLOWED", result.stdout)
        self.assertEqual(result.returncode, 0)

    def test_allows_from_a_subdirectory_of_the_project(self):
        good = self.project("good")
        sub = good / "src" / "deep"
        sub.mkdir(parents=True)
        self.assertIn("ALLOWED", self.run_in(sub).stdout)

    def test_refuses_to_delete_through_a_symlinked_build(self):
        proj = self.project("linked", build=False)
        (proj / "real").mkdir()
        (proj / "build").symlink_to("real")
        result = self.run_in(proj)
        self.assertEqual(result.returncode, 1)
        self.assertIn("is a symlink", result.stderr)

    def test_refuses_when_the_root_has_no_cmakelists(self):
        proj = self.project("nocmake")
        (proj / "CMakeLists.txt").unlink()
        result = self.run_in(proj)
        self.assertEqual(result.returncode, 1)
        # require_cmake fails first here; either refusal is correct, but it must
        # never reach the delete.
        self.assertNotIn("ALLOWED", result.stdout)


if __name__ == "__main__":
    unittest.main()
