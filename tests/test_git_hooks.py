"""Run the real git-hooks in disposable repositories, committing as a user would.

    python3 -B -m unittest discover -s tests

Each test copies the hook files into a new repository with its own Git
configuration file, XDG_RUNTIME_DIR and cache directory, and installs the hook
stub there; this checkout's .git and caches are never used. The tools the hook
needs (prek, shfmt, ShellCheck, jscpd, ruff, zsh, llama-server and its model)
must be installed: a missing one fails a test, never skips it.
"""

import os
from pathlib import Path
import re
import shutil
import signal
import subprocess
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]
TOOLING = (
    ".editorconfig",
    ".pre-commit-config.yaml",
    ".shellcheckrc",
    "ruff.toml",
    "git-hooks/bootstrap",
    "git-hooks/checks",
    "git-hooks/hook",
    "git-hooks/report.py",
)
MODEL = "jina-code-embeddings-0.5b-F16.gguf"
RESULT = re.compile(r"^(\S.*?)\.{3,}(Passed|Failed|Skipped)", re.MULTILINE)

# Hook names, as .pre-commit-config.yaml gives them.
WHITESPACE = "whitespace"
SHELL = "shell syntax, ShellCheck and shfmt"
RUFF = "ruff lint and format"
MASKED = "masked return codes (report only)"
INDICATORS = "long chains and lines (report only)"
CLONES = "clones (report only)"
CANDIDATES = "clone candidates for judgment (report only)"
MEASURE = "size and complexity against the base (report only)"

PROXIES = (
    "http_proxy",
    "HTTP_PROXY",
    "https_proxy",
    "HTTPS_PROXY",
    "all_proxy",
    "ALL_PROXY",
)
GOOD_BASH = '#!/bin/bash\nset -eu\nprintf "%s\\n" "$1"\n'
# A function over jscpd's 50-token minimum, valid Bash and Zsh, and clean for
# every check, so two copies are a clone and nothing else.
CLONE_SHELL = """set -eu

summarise() {
  local file=$1 total=0 count=0 line
  while IFS= read -r line; do
    case $line in
      '#'* | '') continue ;;
    esac
    total=$((total + ${#line}))
    count=$((count + 1))
  done <"$file"
  printf '%s: %d lines, %d characters\\n' "$file" "$count" "$total"
}

summarise "$1"
"""
CLONE_PYTHON = '''"""Fixture module."""


def load(path, defaults):
    result = dict(defaults)
    with open(path, encoding="utf-8") as handle:
        for raw in handle:
            line = raw.strip()
            if not line or line.startswith("#"):
                continue
            key, _, value = line.partition("=")
            result[key.strip()] = value.strip()
    return result
'''
# A test body unlike the production fixtures, so a copy pairs only with a test.
TEST_PYTHON = """import unittest


class Fixture(unittest.TestCase):
    def test_parse(self):
        pairs = [line.partition("=") for line in ("a=1", "b=2", "c=3")]
        self.assertEqual([key for key, _, _ in pairs], ["a", "b", "c"])
        self.assertEqual([value for _, _, value in pairs], ["1", "2", "3"])
        self.assertTrue(all(sep == "=" for _, sep, _ in pairs))
"""
# A renamed copy of CLONE_PYTHON's function, for --similarity.
SIMILAR_PYTHON = '''"""Fixture module."""


def read_settings(filename, base):
    settings = dict(base)
    with open(filename, encoding="utf-8") as stream:
        for row in stream:
            entry = row.strip()
            if not entry or entry.startswith("#"):
                continue
            name, _, val = entry.partition("=")
            settings[name.strip()] = val.strip()
    return settings
'''
# One function written two ways, for --semantic: jina scored the pair 0.95
# (2026-10-25). A shorter Counter version falls below jscpd's function minimum.
COUNT_LOOP = '''def count_words(text, ignored):
    """Words of text by how often they occur, most frequent first."""
    counts = {}
    for raw in text.lower().split():
        word = raw.strip(".,;:!?")
        if not word or word in ignored:
            continue
        if word in counts:
            counts[word] += 1
        else:
            counts[word] = 1
    return sorted(counts.items(), key=lambda item: item[1], reverse=True)
'''
COUNT_COUNTER = '''from collections import Counter


def count_words(text, ignored):
    """Words of text by how often they occur, most frequent first."""
    tally = Counter()
    for token in text.lower().split():
        cleaned = token.strip(".,;:!?")
        if cleaned and cleaned not in ignored:
            tally[cleaned] += 1
    return tally.most_common()
'''

# Stands in for git-hooks/checks: reports what the bootstrap handed it, and
# exits with the staged exit-status file's number.
PROBE = """#!/bin/bash
echo "checks=MARKER mode=$1"
echo "index=$(git rev-parse --path-format=absolute --git-path index)"
echo "base=${CHECKS_BASE:-} scope=$CHECKS_SCOPE"
echo "tree=$(git write-tree)"
git diff --name-only | sed 's/^/unstaged: /'
git ls-files --others | sed 's/^/untracked: /'
if [[ -n ${PROBE_MARK:-} && -f pause ]]; then
  touch "$PROBE_MARK"
  sleep 30
fi
exit "$(cat exit-status 2>/dev/null || echo 0)"
"""


def results(out):
    """{hook name: Passed|Failed|Skipped} from prek's output."""
    return dict(RESULT.findall(out))


def clean_env():
    """The invoking shell's environment without what could change a check's result."""
    env = {
        k: v
        for k, v in os.environ.items()
        if not k.startswith(("GIT_", "CHECKS_", "PREK_", "RUFF_", "LLAMA_"))
    }
    shell_startup = ("BASH_ENV", "ENV", "SHELLOPTS", "BASHOPTS")
    for name in ("SHELLCHECK_OPTS", "SKIP", *shell_startup, *PROXIES):
        env.pop(name, None)
    return env


def section(out, name):
    """The output of the hook called name, up to the next hook's result line."""
    start = out.index(name + ".")
    following = RESULT.search(out, out.index("\n", start))
    return out[start : following.start() if following else len(out)]


class Case(unittest.TestCase):
    def assert_fails(self, code, out, message):
        self.assertNotEqual(code, 0, out)
        self.assertIn(message, out)

    def assert_clone(self, out, first, second):
        pattern = r"clone \([a-z]+, \d+ lines[^)]*\): {}:\d+-\d+ <-> {}:\d+-\d+"
        names = [re.escape(first), re.escape(second)]
        self.assertTrue(
            re.search(pattern.format(*names), out)
            or re.search(pattern.format(*reversed(names)), out),
            f"no clone {first} <-> {second} in:\n{out}",
        )


class HookCase(Case):
    """A repository holding the hook files, committed and with the hook installed."""

    checks = None  # replaces git-hooks/checks when set

    def setUp(self):
        tmp = tempfile.TemporaryDirectory(prefix="git-hooks-test-")
        self.addCleanup(tmp.cleanup)
        self.tmp = Path(tmp.name)
        self.runtime = self.tmp / "runtime"
        self.runtime.mkdir(mode=0o700)
        self.cache = self.tmp / "cache"
        (self.cache / "llama.cpp").mkdir(parents=True)
        real_cache = Path(
            os.environ.get("XDG_CACHE_HOME") or Path.home() / ".cache"
        )
        (self.cache / "llama.cpp" / MODEL).symlink_to(
            real_cache / "llama.cpp" / MODEL
        )
        self.stubs = self.tmp / "stubs"
        self.stubs.mkdir()
        gitconfig = self.tmp / "gitconfig"
        gitconfig.write_text(
            "[user]\n\tname = Test\n\temail = test@example.com\n[init]\n\tdefaultBranch = master\n"
        )
        self.env = clean_env()
        self.env.update(
            GIT_CONFIG_GLOBAL=str(gitconfig),
            GIT_CONFIG_NOSYSTEM="1",
            XDG_RUNTIME_DIR=str(self.runtime),
            XDG_CACHE_HOME=str(self.cache),
            XDG_CONFIG_HOME=str(self.tmp / "config"),
            PATH=f"{self.stubs}:{os.environ['PATH']}",
            LC_ALL="C.UTF-8",
            NO_COLOR="1",
        )
        self.repo = self.tmp / "repo"
        self.init_repo(self.repo)
        self.git("commit", "-q", "--no-verify", "-m", "tooling")

    def init_repo(self, repo):
        repo.mkdir()
        self.git("init", "-q", cwd=repo)
        for name in TOOLING:
            target = repo / name
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(ROOT / name, target)
        if self.checks:
            (repo / "git-hooks/checks").write_text(self.checks)
        for hook in ("pre-commit", "pre-merge-commit"):
            shutil.copy2(ROOT / "git-hooks/hook", repo / ".git/hooks" / hook)
            (repo / ".git/hooks" / hook).chmod(0o755)
        self.git("add", "-A", cwd=repo)

    def path_without(self, missing):
        """A PATH holding every tool on the real one except missing."""
        bin_dir = self.tmp / f"without-{missing}"
        bin_dir.mkdir()
        for directory in os.environ["PATH"].split(":"):
            for tool in (
                Path(directory).glob("*") if Path(directory).is_dir() else ()
            ):
                link = bin_dir / tool.name
                if (
                    tool.name != missing
                    and not link.exists()
                    and os.access(tool, os.X_OK)
                ):
                    link.symlink_to(tool)
        return str(bin_dir)

    def write(self, name, text, *, executable=False):
        path = self.repo / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)
        if executable:
            path.chmod(0o755)
        return path

    def run_command(self, *args, cwd=None, env=None, timeout=300):
        proc = subprocess.run(
            args,
            cwd=cwd or self.repo,
            env=env or self.env,
            capture_output=True,
            text=True,
            timeout=timeout,
            check=False,
        )
        return proc.returncode, proc.stdout + proc.stderr

    def git(self, *args, cwd=None):
        code, out = self.run_command("git", *args, cwd=cwd)
        self.assertEqual(code, 0, out)
        return out.strip()

    def commit(self, *args, cwd=None, env=None):
        """Commit through the hook; every path given is staged first."""
        return self.run_command(
            "git", "commit", "-m", "change", *args, cwd=cwd, env=env
        )

    def stage_and_commit(self, *names, env=None):
        self.git("add", "--", *names)
        return self.commit(env=env)

    def head(self):
        return self.git("rev-parse", "HEAD")

    def tree_state(self, root=None):
        """Content, mode and mtime of every file outside .git."""
        root = root or self.repo
        state = {}
        for path in sorted(root.rglob("*")):
            if ".git" in path.relative_to(root).parts or path.is_dir():
                continue
            info = path.lstat()
            data = (
                os.readlink(path)  # noqa: PTH115 - pathlib tidies the target; the snapshot must see it as stored
                if path.is_symlink()
                else path.read_bytes()
            )
            state[str(path.relative_to(root))] = (
                data,
                info.st_mode,
                info.st_mtime_ns,
            )
        return state

    def snapshots(self):
        return sorted(self.runtime.glob("herdr-hook.*"))

    def assert_blocked(self, code, out, hook):
        self.assertNotEqual(code, 0, out)
        self.assertEqual(results(out).get(hook), "Failed", out)

    def assert_passed(self, code, out):
        self.assertEqual(code, 0, out)
        self.assertNotIn("Failed", results(out).values(), out)
        self.assertEqual(self.snapshots(), [])


class Blocking(HookCase):
    """Each kind of violation blocks a commit; its corrected form passes."""

    def test_clean_files_of_every_dialect_pass(self):
        self.write("bash/tool", GOOD_BASH, executable=True)
        self.write(
            "bin/posix", '#!/bin/sh\nprintf "%s\\n" "$1"\n', executable=True
        )
        self.write(
            "zsh/functions/greet.zsh",
            'greet() {\n  print -r -- "hello $1"\n}\n',
        )
        self.write("zsh/aliases", "alias ll='ls -l'\n")
        self.write("py/mod.py", CLONE_PYTHON)
        self.write(
            "bin/helper",
            '#!/usr/bin/env python3\nprint("hello")\n',
            executable=True,
        )
        code, out = self.stage_and_commit(".")
        self.assert_passed(code, out)
        for hook in (WHITESPACE, SHELL, RUFF):
            self.assertEqual(results(out)[hook], "Passed", out)

    def test_bash_syntax_error_blocks(self):
        self.write("bash/tool", "#!/bin/bash\nif then\n", executable=True)
        code, out = self.stage_and_commit("bash/tool")
        self.assert_blocked(code, out, SHELL)
        self.assertIn("bash/tool", out)
        # Only the shell check fails; the report lists the file as not measured.
        self.assertEqual(results(out)[INDICATORS], "Passed", out)
        self.assertIn(
            "chains not measured (shfmt cannot parse them): bash/tool",
            section(out, INDICATORS),
        )

    def test_merge_bringing_in_a_syntax_error_blocks(self):
        self.git("switch", "-q", "-c", "side")
        self.write("bash/tool", "#!/bin/bash\nif then\n", executable=True)
        self.git("add", "bash/tool")
        self.git("commit", "-q", "--no-verify", "-m", "side")
        self.git("switch", "-q", "master")
        self.write("main", "main\n")
        self.git("add", "main")
        self.git("commit", "-q", "--no-verify", "-m", "main")
        before = self.head()
        code, out = self.run_command(
            "git", "merge", "--no-ff", "-m", "merge", "side"
        )
        self.assert_blocked(code, out, SHELL)
        self.assertIn("bash/tool", section(out, SHELL))
        self.assertEqual(self.head(), before)

    def test_shellcheck_finding_blocks(self):
        self.write("bash/tool", "#!/bin/bash\necho $1\n", executable=True)
        code, out = self.stage_and_commit("bash/tool")
        self.assert_blocked(code, out, SHELL)
        self.assertIn("SC2086", out)

    def test_exported_shellcheck_opts_cannot_pass_a_finding(self):
        self.write("bash/tool", "#!/bin/bash\necho $1\n", executable=True)
        code, out = self.stage_and_commit(
            "bash/tool", env=self.env | {"SHELLCHECK_OPTS": "-e SC2086"}
        )
        self.assert_blocked(code, out, SHELL)

    def test_exported_skip_cannot_pass_a_blocking_check(self):
        self.write("bash/tool", "#!/bin/bash\necho $1\n", executable=True)
        self.git("add", "bash/tool")
        for name in ("SKIP", "PREK_SKIP"):
            code, out = self.commit(env=self.env | {name: "shell"})
            self.assert_blocked(code, out, SHELL)

    def test_crlf_shebang_is_selected(self):
        self.write("bash/tool", "#!/bin/bash\r\necho hi\r\n", executable=True)
        code, out = self.stage_and_commit("bash/tool")
        self.assert_blocked(code, out, SHELL)
        self.assertIn("SC1017", out)

    def test_sh_script_is_checked_as_sh(self):
        self.write(
            "bin/posix",
            '#!/bin/sh\nif [[ -n "$1" ]]; then echo yes; fi\n',
            executable=True,
        )
        code, out = self.stage_and_commit("bin/posix")
        self.assert_blocked(code, out, SHELL)
        self.assertIn("SC3010", out)

    def test_env_dash_s_shebang_is_selected(self):
        self.write(
            "bin/tool", "#!/usr/bin/env -S bash -e\necho $1\n", executable=True
        )
        code, out = self.stage_and_commit("bin/tool")
        self.assert_blocked(code, out, SHELL)
        self.assertIn("SC2086", out)

    def test_tab_indented_extensionless_script_fails_formatting_and_its_fix_passes(
        self,
    ):
        self.write(
            "bash/tool",
            '#!/bin/bash\nif [[ -n "$1" ]]; then\n\techo "$1"\nfi\n',
            executable=True,
        )
        code, out = self.stage_and_commit("bash/tool")
        self.assert_blocked(code, out, SHELL)
        self.write(
            "bash/tool",
            '#!/bin/bash\nif [[ -n "$1" ]]; then\n  echo "$1"\nfi\n',
            executable=True,
        )
        code, out = self.stage_and_commit("bash/tool")
        self.assert_passed(code, out)

    def test_zsh_startup_file_without_shebang_is_parsed(self):
        self.write("zsh/.zshenv", "if [[ -n $HOME ]]; then\n")
        code, out = self.stage_and_commit("zsh/.zshenv")
        self.assert_blocked(code, out, SHELL)
        self.assertIn("zsh/.zshenv", out)

    def test_zshrc_is_parsed_but_not_format_checked(self):
        self.write("zsh/.zshrc", "if true; then\n    print -r -- hello\nfi\n")
        code, out = self.stage_and_commit("zsh/.zshrc")
        self.assert_passed(code, out)
        self.write("zsh/.zshrc", "if true; then\n")
        code, out = self.stage_and_commit("zsh/.zshrc")
        self.assert_blocked(code, out, SHELL)

    def test_dot_sh_file_without_shebang_fails(self):
        self.write("lib/part.sh", 'printf "%s\\n" "$1"\n')
        code, out = self.stage_and_commit("lib/part.sh")
        self.assert_blocked(code, out, SHELL)
        self.assertIn("lib/part.sh has no Bash or sh shebang", out)

    def test_extensionless_file_without_shebang_is_not_checked_but_reported_when_executable(
        self,
    ):
        self.write("bin/notes", "if then (\n", executable=True)
        code, out = self.stage_and_commit("bin/notes")
        self.assert_passed(code, out)
        self.assertIn(
            "executable without a shebang, not checked: bin/notes", out
        )

    def test_executable_with_an_unread_interpreter_is_reported(self):
        for shebang in (
            "#!/usr/bin/env -S -u FOO python3",
            "#!/usr/bin/env -S uv run --script",
        ):
            with self.subTest(shebang=shebang):
                self.write(
                    "bin/runner", shebang + '\nprint("hi")\n', executable=True
                )
                code, out = self.stage_and_commit("bin/runner")
                self.assert_passed(code, out)
                self.assertIn(
                    f"executable in no checked dialect, not checked: bin/runner ({shebang})",
                    out,
                )

    def test_executable_file_selected_by_path_is_not_reported_as_unchecked(
        self,
    ):
        self.write(
            "zsh/functions/greet.zsh",
            'greet() {\n  print -r -- "hello $1"\n}\n',
            executable=True,
        )
        code, out = self.stage_and_commit("zsh/functions/greet.zsh")
        self.assert_passed(code, out)
        self.assertNotIn("not checked", out)

    def test_path_with_spaces_is_checked(self):
        self.write("bash/my tool", "#!/bin/bash\necho $1\n", executable=True)
        code, out = self.stage_and_commit("bash/my tool")
        self.assert_blocked(code, out, SHELL)
        self.assertIn("bash/my tool", out)

    def test_tmux_files_are_out_of_scope(self):
        self.write("tmux/helper.sh", "#!/bin/bash\nif then\n")
        self.write("bash/tmux-cpp-tools", "#!/bin/bash\nif then\n")
        code, out = self.stage_and_commit("tmux", "bash/tmux-cpp-tools")
        self.assert_passed(code, out)

    def test_renamed_file_is_checked_under_its_new_name_and_a_deleted_one_is_not(
        self,
    ):
        self.write("bash/old", "#!/bin/bash\necho $1\n", executable=True)
        self.git("add", "bash/old")
        self.git("commit", "-q", "--no-verify", "-m", "unchecked")
        self.git("mv", "bash/old", "bash/new")
        code, out = self.commit()
        self.assert_blocked(code, out, SHELL)
        self.assertIn("bash/new", out)
        self.git("rm", "-q", "--cached", "bash/new")
        code, out = self.commit()
        self.assert_passed(code, out)

    def test_unchanged_files_are_not_checked(self):
        self.write("bash/bad", "#!/bin/bash\necho $1\n", executable=True)
        self.git("add", "bash/bad")
        self.git("commit", "-q", "--no-verify", "-m", "unchecked")
        self.write("bash/good", GOOD_BASH, executable=True)
        code, out = self.stage_and_commit("bash/good")
        self.assert_passed(code, out)
        self.assertNotIn("SC2086", out)

    def test_changing_the_rules_checks_every_file(self):
        self.write("bash/bad", "#!/bin/bash\necho $1\n", executable=True)
        self.git("add", "bash/bad")
        self.git("commit", "-q", "--no-verify", "-m", "unchecked")
        for rules in (".shellcheckrc", ".gitattributes", "git-hooks/checks"):
            with self.subTest(rules=rules):
                path = self.repo / rules
                path.write_text(
                    (path.read_text() if path.exists() else "")
                    + "# a comment\n"
                )
                code, out = self.stage_and_commit(rules)
                self.assert_blocked(code, out, SHELL)
                self.assertIn("bash/bad", section(out, SHELL))
                self.git("reset", "-q", "--hard")

    def test_trailing_whitespace_blocks(self):
        self.write("notes.txt", "text \n")
        code, out = self.stage_and_commit("notes.txt")
        self.assert_blocked(code, out, WHITESPACE)

    def test_whitespace_still_blocks_when_git_c_turns_the_rule_off(self):
        self.write("notes.txt", "text \n")
        self.git("add", "notes.txt")
        code, out = self.run_command(
            "git",
            "-c",
            "core.whitespace=-trailing-space",
            "commit",
            "-m",
            "change",
        )
        self.assert_blocked(code, out, WHITESPACE)

    def test_whitespace_still_blocks_when_user_configuration_turns_the_rule_off(
        self,
    ):
        config = Path(self.env["GIT_CONFIG_GLOBAL"])
        config.write_text(
            config.read_text() + "[core]\n\twhitespace = -trailing-space\n"
        )
        self.write("notes.txt", "text \n")
        code, out = self.stage_and_commit("notes.txt")
        self.assert_blocked(code, out, WHITESPACE)

    def test_whitespace_still_blocks_when_a_git_template_turns_the_rule_off(
        self,
    ):
        template = self.tmp / "template"
        template.mkdir()
        (template / "config").write_text(
            "[core]\n\twhitespace = -trailing-space\n"
        )
        config = Path(self.env["GIT_CONFIG_GLOBAL"])
        config.write_text(
            config.read_text() + f"[init]\n\ttemplateDir = {template}\n"
        )
        self.write("notes.txt", "text \n")
        code, out = self.stage_and_commit("notes.txt")
        self.assert_blocked(code, out, WHITESPACE)

    def test_whitespace_still_blocks_when_user_attributes_turn_the_rule_off(
        self,
    ):
        attributes = Path(self.env["XDG_CONFIG_HOME"], "git", "attributes")
        attributes.parent.mkdir(parents=True, exist_ok=True)
        attributes.write_text("* whitespace=-blank-at-eol\n")
        self.write("notes.txt", "text \n")
        code, out = self.stage_and_commit("notes.txt")
        self.assert_blocked(code, out, WHITESPACE)

    def test_ruff_finding_blocks_and_its_fix_passes(self):
        self.write("py/mod.py", "import os\n")
        code, out = self.stage_and_commit("py/mod.py")
        self.assert_blocked(code, out, RUFF)
        self.assertIn("F401", out)
        self.write("py/mod.py", CLONE_PYTHON)
        code, out = self.stage_and_commit("py/mod.py")
        self.assert_passed(code, out)

    def test_unformatted_python_helper_without_extension_blocks(self):
        self.write(
            "bin/helper",
            "#!/usr/bin/env python3\nx=1\nprint(x)\n",
            executable=True,
        )
        code, out = self.stage_and_commit("bin/helper")
        self.assert_blocked(code, out, RUFF)
        self.assertIn("bin/helper", out)

    def test_exported_ruff_output_file_cannot_hide_a_finding(self):
        self.write("py/mod.py", "import os\n")
        output = self.tmp / "ruff-output"
        code, out = self.stage_and_commit(
            "py/mod.py", env=self.env | {"RUFF_OUTPUT_FILE": str(output)}
        )
        self.assert_blocked(code, out, RUFF)
        self.assertIn("F401", out)
        self.assertFalse(output.exists())

    def test_python_test_files_are_linted(self):
        self.write("tests/test_mod.py", "import os\n")
        code, out = self.stage_and_commit("tests/test_mod.py")
        self.assert_blocked(code, out, RUFF)

    def test_long_python_lines_are_reported_without_blocking(self):
        # ruff never wraps a comment; the report lists it, in modules and tests.
        # shfmt cannot parse the def, so a chain count would show as well.
        long = "# " + "x" * 79 + "\ndef f():\n    pass\n"
        self.write("py/mod.py", long)
        self.write("tests/test_mod.py", long)
        code, out = self.stage_and_commit("py/mod.py", "tests/test_mod.py")
        self.assert_passed(code, out)
        report = section(out, INDICATORS)
        self.assertIn("py/mod.py:1: 81 columns", report)
        self.assertIn("tests/test_mod.py:1: 81 columns", report)
        self.assertNotIn("not measured", report)

    def test_checks_neither_fix_nor_stage_files(self):
        self.write(
            "bash/tool",
            "#!/bin/bash\nif true; then\n\techo hi\nfi\n",
            executable=True,
        )
        self.write("py/mod.py", "x=1\n")
        self.git("add", "bash/tool", "py/mod.py")
        before, staged = self.tree_state(), self.git("diff", "--cached")
        code, out = self.commit()
        self.assertNotEqual(code, 0, out)
        self.assertEqual(self.tree_state(), before)
        self.assertEqual(self.git("diff", "--cached"), staged)

    def test_live_symlink_target_is_unchanged(self):
        target = self.tmp / "live-config"
        target.write_text("live\n")
        before = target.stat()
        (self.repo / "link").symlink_to(target)
        self.write("bash/tool", GOOD_BASH, executable=True)
        code, out = self.stage_and_commit("link", "bash/tool")
        self.assert_passed(code, out)
        self.assertEqual(target.read_text(), "live\n")
        self.assertEqual(target.stat().st_mtime_ns, before.st_mtime_ns)

    def test_untracked_file_cannot_satisfy_a_staged_source(self):
        self.write(
            "bash/lib.sh", '#!/bin/bash\nhelper() { printf "%s\\n" "$1"; }\n'
        )
        self.write(
            "bash/tool",
            '#!/bin/bash\n# shellcheck source=bash/lib.sh\nsource bash/lib.sh\nhelper "$1"\n',
        )
        code, out = self.stage_and_commit("bash/tool")
        self.assert_blocked(code, out, SHELL)
        self.assertIn("SC1091", out)

    def test_missing_tool_fails(self):
        self.write("bash/tool", GOOD_BASH, executable=True)
        code, out = self.stage_and_commit(
            "bash/tool",
            env=self.env | {"PATH": self.path_without("shellcheck")},
        )
        self.assert_blocked(code, out, SHELL)
        self.assertIn("shellcheck is not installed", out)

    def test_failing_clone_scan_blocks(self):
        stub = self.stubs / "jscpd"
        stub.write_text("#!/bin/sh\necho 'scan broke' >&2\nexit 2\n")
        stub.chmod(0o755)
        self.write("bash/tool", GOOD_BASH, executable=True)
        code, out = self.stage_and_commit("bash/tool")
        self.assert_blocked(code, out, CLONES)
        self.assertIn("jscpd failed (2)", out)

    def test_masked_return_is_reported_without_blocking(self):
        self.write(
            "bash/tool",
            '#!/bin/bash\nset -eu\nprintf "%s\\n" "$(date)"\n',
            executable=True,
        )
        code, out = self.stage_and_commit("bash/tool")
        self.assert_passed(code, out)
        self.assertIn("SC2312", section(out, MASKED))

    def test_masked_returns_checker_error_blocks(self):
        stub = self.stubs / "shellcheck"
        real = shutil.which("shellcheck", path=os.environ["PATH"])
        stub.write_text(
            '#!/bin/sh\ncase " $* " in *check-extra-masked-returns*) echo broke >&2; exit 2 ;; esac\n'
            f'exec "{real}" "$@"\n'
        )
        stub.chmod(0o755)
        self.write("bash/tool", GOOD_BASH, executable=True)
        code, out = self.stage_and_commit("bash/tool")
        self.assert_blocked(code, out, MASKED)
        self.assertEqual(results(out).get(SHELL), "Passed", out)

    def test_intent_to_add_file_is_not_checked(self):
        # prek clears intent-to-add entries for its run, so the empty file the
        # snapshot holds is in no check's file list.
        self.write("py/new.py", "x = 1\n")
        self.git("add", "-N", "py/new.py")
        self.write("bash/tool", GOOD_BASH, executable=True)
        code, out = self.stage_and_commit("bash/tool")
        self.assert_passed(code, out)
        self.assertNotIn("py/new.py", out)

    def test_unstaged_configuration_edit_is_not_used_but_a_staged_one_is(self):
        config = self.repo / ".pre-commit-config.yaml"
        config.write_text(
            config.read_text()
            + "      - id: veto\n        name: veto\n        entry: 'false'\n        language: system\n"
            + "        pass_filenames: false\n        always_run: true\n        stages: [pre-commit]\n"
        )
        self.write("bash/tool", GOOD_BASH, executable=True)
        code, out = self.stage_and_commit("bash/tool")
        self.assert_passed(code, out)
        self.assertNotIn("veto", out)
        code, out = self.stage_and_commit(".pre-commit-config.yaml")
        self.assert_blocked(code, out, "veto")

    def test_unstaged_dispatcher_edit_is_not_used_but_a_staged_one_is(self):
        checks = self.repo / "git-hooks/checks"
        checks.write_text(
            checks.read_text().replace(
                "  whitespace) check_whitespace ;;", "  whitespace) exit 1 ;;"
            )
        )
        self.write("bash/tool", GOOD_BASH, executable=True)
        code, out = self.stage_and_commit("bash/tool")
        self.assert_passed(code, out)
        code, out = self.stage_and_commit("git-hooks/checks")
        self.assert_blocked(code, out, WHITESPACE)


class Isolation(HookCase):
    """The probe dispatcher shows what the bootstrap's snapshot holds."""

    checks = PROBE.replace("MARKER", "STAGED")

    def probe(self, out, key):
        return re.findall(rf"^{key}[=:] ?(.*)$", out, re.MULTILINE)

    def assert_isolated(self, code, out, tree):
        self.assertEqual(code, 0, out)
        self.assertEqual(
            self.probe(out, "checks"), ["STAGED mode=pre-commit"], out
        )
        self.assertEqual(self.probe(out, "tree"), [tree], out)
        self.assertEqual(
            self.probe(out, "unstaged") + self.probe(out, "untracked"), [], out
        )
        (index,) = self.probe(out, "index")
        self.assertRegex(
            index,
            rf"^{re.escape(str(self.runtime))}/herdr-hook\.[^/]+/repo/\.git/index$",
        )
        self.assertEqual(self.snapshots(), [])

    def edit_live_dispatcher(self):
        (self.repo / "git-hooks/checks").write_text(
            PROBE.replace("MARKER", "LIVE")
        )

    def test_plain_commit_with_unstaged_edits_and_untracked_files(self):
        self.write("sub/file", "one\n")
        self.git("add", "sub/file")
        self.write("sub/file", "one\ntwo\n")
        self.write("stray", "untracked\n")
        self.edit_live_dispatcher()
        before = self.tree_state()
        code, out = self.commit()
        self.assert_isolated(code, out, self.git("rev-parse", "HEAD^{tree}"))
        self.assertEqual(self.git("show", "HEAD:sub/file"), "one")
        self.assertEqual(self.tree_state(), before)

    def test_commit_from_a_subdirectory(self):
        self.write("sub/file", "one\n")
        self.git("add", "sub/file")
        code, out = self.commit(cwd=self.repo / "sub")
        self.assert_isolated(code, out, self.git("rev-parse", "HEAD^{tree}"))

    def test_commit_all_checks_the_temporary_index(self):
        self.write("sub/file", "one\n")
        self.git("add", "sub/file")
        self.git("commit", "-q", "--no-verify", "-m", "file")
        self.write("sub/file", "two\n")
        code, out = self.commit("-a", cwd=self.repo / "sub")
        self.assert_isolated(code, out, self.git("rev-parse", "HEAD^{tree}"))
        self.assertEqual(self.git("status", "--porcelain"), "")

    def test_commit_of_a_path_leaves_other_staged_changes(self):
        self.write("sub/file", "one\n")
        self.write("other", "other\n")
        self.git("add", "sub/file", "other")
        self.git("commit", "-q", "--no-verify", "-m", "files")
        self.write("sub/file", "two\n")
        self.write("other", "changed\n")
        self.git("add", "other")
        code, out = self.commit("sub/file")
        self.assert_isolated(code, out, self.git("rev-parse", "HEAD^{tree}"))
        self.assertEqual(self.git("diff", "--cached", "--name-only"), "other")

    def test_partial_staging(self):
        self.write("sub/file", "one\n")
        self.git("add", "sub/file")
        self.git("commit", "-q", "--no-verify", "-m", "file")
        self.write("sub/file", "one\ntwo\n")
        self.git("add", "sub/file")
        self.write("sub/file", "one\ntwo\nthree\n")
        code, out = self.commit()
        self.assert_isolated(code, out, self.git("rev-parse", "HEAD^{tree}"))
        self.assertEqual(
            (self.repo / "sub/file").read_text(), "one\ntwo\nthree\n"
        )

    def test_amend_checks_the_amended_index_against_the_replaced_commit(self):
        self.write("sub/file", "one\n")
        self.git("add", "sub/file")
        self.git("commit", "-q", "--no-verify", "-m", "file")
        replaced = self.head()
        self.write("sub/file", "two\n")
        self.git("add", "sub/file")
        code, out = self.commit("--amend")
        self.assert_isolated(code, out, self.git("rev-parse", "HEAD^{tree}"))
        self.assertEqual(
            self.probe(out, "base"), [f"{replaced} scope=changed"], out
        )
        self.assertEqual(self.git("show", "HEAD:sub/file"), "two")

    def test_on_demand_run_from_a_subdirectory_leaves_the_index(self):
        self.write("sub/file", "one\n")
        self.git("add", "sub/file")
        # stores a cache tree, so before the copy below
        tree = self.git("write-tree")
        index = (self.repo / ".git/index").read_bytes()
        code, out = self.run_command(
            "bash", "../git-hooks/bootstrap", "run", cwd=self.repo / "sub"
        )
        self.assertEqual(self.probe(out, "checks"), ["STAGED mode=run"], out)
        self.assertEqual(self.probe(out, "tree"), [tree], out)
        self.assertEqual(code, 0, out)
        self.assertEqual((self.repo / ".git/index").read_bytes(), index)

    def test_first_commit_has_no_base(self):
        repo = self.tmp / "first"
        self.init_repo(repo)
        code, out = self.run_command("git", "commit", "-m", "first", cwd=repo)
        self.assertEqual(code, 0, out)
        self.assertEqual(self.probe(out, "base"), ["scope=changed"], out)
        self.assertEqual(
            self.probe(out, "tree"),
            [self.git("rev-parse", "HEAD^{tree}", cwd=repo)],
            out,
        )

    def test_clean_no_ff_merge_runs_pre_merge_commit(self):
        self.git("switch", "-q", "-c", "side")
        self.write("side", "side\n")
        self.git("add", "side")
        self.git("commit", "-q", "--no-verify", "-m", "side")
        self.git("switch", "-q", "master")
        self.write("main", "main\n")
        self.git("add", "main")
        self.git("commit", "-q", "--no-verify", "-m", "main")
        base = self.head()
        code, out = self.run_command(
            "git", "merge", "--no-ff", "-m", "merge", "side"
        )
        self.assertEqual(code, 0, out)
        self.assertEqual(
            self.probe(out, "checks"), ["STAGED mode=pre-merge-commit"], out
        )
        self.assertEqual(
            self.probe(out, "base"), [f"{base} scope=changed"], out
        )
        self.assertEqual(
            self.probe(out, "tree"), [self.git("rev-parse", "HEAD^{tree}")], out
        )

    def test_failing_check_blocks_and_its_status_passes_through(self):
        self.write("exit-status", "3\n")
        self.git("add", "exit-status")
        code, out = self.commit()
        self.assertNotEqual(code, 0, out)
        self.assertEqual(self.git("log", "-1", "--format=%s"), "tooling")
        code, out = self.run_command("bash", "git-hooks/bootstrap", "run")
        self.assertEqual(code, 3, out)

    def test_unstaged_bootstrap_edit_aborts(self):
        bootstrap = self.repo / "git-hooks/bootstrap"
        bootstrap.write_text(bootstrap.read_text() + "# edit\n")
        self.write("file", "one\n")
        self.git("add", "file")
        code, out = self.commit()
        self.assert_fails(
            code,
            out,
            "git-hooks/bootstrap differs from the copy in this commit",
        )
        self.assertEqual(self.probe(out, "checks"), [])

    def test_staged_bootstrap_edit_left_out_of_a_path_commit_aborts(self):
        bootstrap = self.repo / "git-hooks/bootstrap"
        bootstrap.write_text(bootstrap.read_text() + "# edit\n")
        self.write("file", "one\n")
        self.git("add", "git-hooks/bootstrap", "file")
        code, out = self.commit("file")
        self.assert_fails(
            code,
            out,
            "git-hooks/bootstrap differs from the copy in this commit",
        )
        self.assertEqual(self.probe(out, "checks"), [])

    def test_bootstrap_not_yet_added_aborts(self):
        bootstrap = (self.repo / "git-hooks/bootstrap").read_text()
        self.git("switch", "-q", "--orphan", "new")
        self.write("git-hooks/bootstrap", bootstrap)
        self.write("file", "one\n")
        self.git("add", "file")
        code, out = self.commit()
        self.assert_fails(
            code, out, "git-hooks/bootstrap is not in this commit; add it first"
        )
        self.assertNotIn("removes", out)

    def test_branch_without_the_bootstrap_lets_the_commit_through(self):
        self.git("switch", "-q", "--orphan", "old")
        self.write("file", "one\n")
        self.git("add", "file")
        code, out = self.commit()
        self.assertEqual(code, 0, out)
        self.assertIn(
            "this branch has no git-hooks/bootstrap; no checks run", out
        )

    def test_bootstrap_deleted_but_still_staged_aborts(self):
        (self.repo / "git-hooks/bootstrap").unlink()
        self.write("file", "one\n")
        self.git("add", "file")
        code, out = self.commit()
        self.assert_fails(
            code,
            out,
            "git-hooks/bootstrap is staged but missing; restore it with git restore git-hooks/bootstrap",
        )
        self.assertEqual(self.git("log", "-1", "--format=%s"), "tooling")

    def test_user_autocrlf_does_not_change_the_checked_files(self):
        config = Path(self.env["GIT_CONFIG_GLOBAL"])
        config.write_text(config.read_text() + "[core]\n\tautocrlf = true\n")
        self.write("bash/good", GOOD_BASH, executable=True)
        code, out = self.stage_and_commit("bash/good")
        self.assert_passed(code, out)

    def test_user_eol_attribute_does_not_change_the_checked_files(self):
        attributes = Path(self.env["XDG_CONFIG_HOME"], "git", "attributes")
        attributes.parent.mkdir(parents=True, exist_ok=True)
        attributes.write_text("* text eol=crlf\n")
        self.write("bash/good", GOOD_BASH, executable=True)
        code, out = self.stage_and_commit("bash/good")
        self.assert_passed(code, out)

    def test_full_run_without_a_committed_bootstrap_says_so(self):
        bootstrap = (self.repo / "git-hooks/bootstrap").read_text()
        self.git("switch", "-q", "--orphan", "new")
        self.write("file", "one\n")
        self.git("add", "file")
        self.git("commit", "-q", "--no-verify", "-m", "old")
        self.write("git-hooks/bootstrap", bootstrap)
        code, out = self.run_command(
            "bash", "git-hooks/bootstrap", "full", self.head()
        )
        self.assert_fails(
            code, out, "git-hooks/bootstrap is not in HEAD; commit it first"
        )

    def test_commit_removing_the_bootstrap_fails_while_the_hooks_are_installed(
        self,
    ):
        for remove in (["rm", "-q"], ["rm", "-q", "--cached"]):
            with self.subTest(remove=remove):
                self.git(*remove, "git-hooks/bootstrap")
                code, out = self.commit()
                self.assert_fails(
                    code, out, "this commit removes git-hooks/bootstrap"
                )
                self.assertEqual(
                    self.git("log", "-1", "--format=%s"), "tooling"
                )
                self.git("reset", "-q", "--hard")

    def test_stale_installed_hook_is_warned_about_without_blocking(self):
        code, out = self.commit("--allow-empty")
        self.assertEqual(code, 0, out)
        self.assertNotIn("warning", out)
        stub = self.repo / ".git/hooks/pre-commit"
        stub.write_text(stub.read_text() + "# an older copy\n")
        code, out = self.commit("--allow-empty")
        self.assertEqual(code, 0, out)
        self.assertIn(
            f"warning: {stub} differs from git-hooks/hook; copy it again", out
        )

    def test_split_index_fails(self):
        self.git("update-index", "--split-index")
        code, out = self.commit("--allow-empty")
        self.assert_fails(code, out, "the index is split")

    def test_skip_worktree_entry_fails(self):
        self.git("update-index", "--skip-worktree", "ruff.toml")
        code, out = self.commit("--allow-empty")
        self.assert_fails(code, out, "skip-worktree")
        self.assertEqual(self.snapshots(), [])

    def test_interrupt_removes_the_snapshot_and_leaves_files(self):
        self.write("pause", "")
        self.git("add", "pause")
        mark = self.tmp / "paused"
        before = self.tree_state()
        proc = subprocess.Popen(
            ["git", "commit", "-m", "change"],
            cwd=self.repo,
            env=self.env | {"PROBE_MARK": str(mark)},
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            start_new_session=True,
        )
        deadline = time.monotonic() + 60
        while not mark.exists() and time.monotonic() < deadline:
            time.sleep(0.05)
        self.assertTrue(mark.exists(), "the probe never started")
        self.assertEqual(len(self.snapshots()), 1)
        os.killpg(proc.pid, signal.SIGINT)
        self.assertNotEqual(proc.wait(timeout=30), 0)
        deadline = time.monotonic() + 10
        while self.snapshots() and time.monotonic() < deadline:
            time.sleep(0.05)
        self.assertEqual(self.snapshots(), [])
        self.assertEqual(self.tree_state(), before)
        self.assertEqual(self.git("log", "-1", "--format=%s"), "tooling")


class Clones(HookCase):
    """Clones are named by file and line range, and never block."""

    def test_new_clone_of_an_unchanged_file_is_reported_without_blocking(self):
        self.write("bash/one", "#!/bin/bash\n" + CLONE_SHELL, executable=True)
        code, out = self.stage_and_commit("bash/one")
        self.assertNotIn("docs/clone-verdicts.md", section(out, CLONES))
        self.write("bash/two", "#!/bin/bash\n" + CLONE_SHELL, executable=True)
        code, out = self.stage_and_commit("bash/two")
        self.assert_passed(code, out)
        self.assert_clone(section(out, CLONES), "bash/one", "bash/two")
        self.assertIn(
            "Look each up in docs/clone-verdicts.md first.",
            section(out, CLONES),
        )
        self.assertIn(
            f"1 clones new since {self.git('rev-parse', 'HEAD~1')[:12]}", out
        )

    def test_merge_creating_a_clone_between_two_branches_reports_it(self):
        self.git("switch", "-q", "-c", "side")
        self.write("bash/two", "#!/bin/bash\n" + CLONE_SHELL, executable=True)
        self.git("add", "bash/two")
        self.git("commit", "-q", "--no-verify", "-m", "side")
        self.git("switch", "-q", "master")
        self.write("bash/one", "#!/bin/bash\n" + CLONE_SHELL, executable=True)
        self.git("add", "bash/one")
        self.git("commit", "-q", "--no-verify", "-m", "main")
        code, out = self.run_command(
            "git", "merge", "--no-ff", "-m", "merge", "side"
        )
        self.assert_passed(code, out)
        self.assert_clone(section(out, CLONES), "bash/one", "bash/two")

    def test_first_commit_reports_every_clone(self):
        repo = self.tmp / "first"
        self.init_repo(repo)
        for name in ("bash/one", "bash/two"):
            (repo / name).parent.mkdir(exist_ok=True)
            (repo / name).write_text("#!/bin/bash\n" + CLONE_SHELL)
        self.git("add", "-A", cwd=repo)
        code, out = self.run_command("git", "commit", "-m", "first", cwd=repo)
        self.assertEqual(code, 0, out)
        self.assertIn("in all files (no base commit)", out)
        self.assert_clone(out, "bash/one", "bash/two")

    def test_same_name_in_two_directories_is_reported_by_full_path(self):
        self.write("one/tool", "#!/bin/bash\n" + CLONE_SHELL, executable=True)
        self.write("two/tool", "#!/bin/bash\n" + CLONE_SHELL, executable=True)
        code, out = self.stage_and_commit("one", "two")
        self.assert_passed(code, out)
        self.assert_clone(out, "one/tool", "two/tool")

    def test_zsh_files_without_extension_or_shebang_are_analyzed(self):
        self.write("zsh/aliases", CLONE_SHELL)
        self.write("zsh/tool", "#!/bin/zsh\n" + CLONE_SHELL, executable=True)
        code, out = self.stage_and_commit("zsh")
        self.assert_passed(code, out)
        self.assert_clone(out, "zsh/aliases", "zsh/tool")

    def test_python_clone_is_reported_but_a_test_clone_only_by_the_broad_run(
        self,
    ):
        self.write("py/one.py", CLONE_PYTHON)
        self.write(
            "bin/two",
            "#!/usr/bin/env python3\n" + CLONE_PYTHON,
            executable=True,
        )
        self.write("tests/test_one.py", CLONE_PYTHON)
        self.write("tests/test_two.py", CLONE_PYTHON)
        code, out = self.stage_and_commit(".")
        self.assert_passed(code, out)
        self.assert_clone(out, "py/one.py", "bin/two")
        self.assertNotIn("tests/test_", section(out, CLONES))


class FullRun(HookCase):
    """The full run before a milestone review, against the milestone's base."""

    def test_full_run_reports_planned_and_broad_clones_since_the_base(self):
        self.write("bash/one", "#!/bin/bash\n" + CLONE_SHELL, executable=True)
        self.write("bash/gone", GOOD_BASH, executable=True)
        self.write("tests/test_one.py", TEST_PYTHON)
        self.write("py/loader.py", CLONE_PYTHON)
        self.write("bin/tool", GOOD_BASH, executable=True)
        self.git("add", "-A")
        self.git("commit", "-q", "--no-verify", "-m", "base")
        base = self.head()
        self.git("rm", "-q", "bash/gone")
        self.write("bash/two", "#!/bin/bash\n" + CLONE_SHELL, executable=True)
        self.write("tests/test_two.py", TEST_PYTHON)
        self.write("pkg/__init__.py", "")
        self.write("py/settings.py", SIMILAR_PYTHON)
        self.write("py/count_loop.py", COUNT_LOOP)
        self.write("py/count_counter.py", COUNT_COUNTER)
        self.write(
            "py/loader.py",
            CLONE_PYTHON
            + "\n\ndef keys(path):\n    return sorted(load(path, {}))\n",
        )
        # The same path, Bash at the base and Python now.
        self.write(
            "bin/tool",
            '#!/usr/bin/env python3\nprint("hello")\n',
            executable=True,
        )
        self.git("add", "-A")
        self.git("commit", "-q", "--no-verify", "-m", "branch")
        before = self.tree_state()
        # Reached through a symlink, which jscpd resolves in the paths it reports,
        # with a proxy that the loopback-only namespace cannot reach, and with
        # an API key that the server would demand and jscpd never sends. With
        # core.autocrlf the base's checkout would gain a byte per line.
        runtime = self.tmp / "runtime-link"
        runtime.symlink_to(self.runtime)
        config = Path(self.env["GIT_CONFIG_GLOBAL"])
        config.write_text(config.read_text() + "[core]\n\tautocrlf = true\n")
        env = self.env | {
            "XDG_RUNTIME_DIR": str(runtime),
            "http_proxy": "http://192.0.2.1:9",
            "LLAMA_API_KEY": "secret",
        }
        code, out = self.run_command(
            "bash", "git-hooks/bootstrap", "full", base, env=env
        )
        self.assert_passed(code, out)
        planned, broad = (
            section(out, CLONES),
            section(out, CANDIDATES),
        )
        self.assert_clone(planned, "bash/one", "bash/two")
        self.assertNotIn("tests/test_", planned)
        self.assertIn("Candidates for judgment (broad)", broad)
        self.assert_clone(broad, "tests/test_one.py", "tests/test_two.py")
        similarity = broad[
            broad.index("Candidates for judgment (similarity)") :
        ]
        similarity, semantic = similarity.split(
            "Candidates for judgment (semantic)"
        )
        self.assertIn(f"new since {base[:12]}", similarity)
        self.assert_clone(similarity, "py/loader.py", "py/settings.py")
        self.assertIn(f"new since {base[:12]}", semantic)
        self.assert_clone(semantic, "py/count_loop.py", "py/count_counter.py")
        measure = section(out, MEASURE)
        self.assertRegex(
            measure, rf"bash/gone: \(3, {len(GOOD_BASH)}, \d+\) -> not in scope"
        )
        self.assertRegex(
            measure, r"bash/two: not in scope -> \(\d+, \d+, \d+\)"
        )
        self.assertIn("pkg/__init__.py: not in scope -> not measured", measure)
        for changed in ("bin/tool", "py/loader.py"):
            self.assertRegex(
                measure, rf"{changed}: \(\d+, \d+, \d+\) -> \(\d+, \d+, \d+\)"
            )
        self.assertEqual(self.tree_state(), before)
        self.assertFalse((self.cache / "jscpd").exists())

    def test_missing_tool_fails_the_full_run_by_name(self):
        env = self.env | {"PATH": self.path_without("llama-server")}
        code, out = self.run_command(
            "bash", "git-hooks/bootstrap", "full", self.head(), env=env
        )
        self.assert_fails(code, out, "llama-server is not installed")

    def test_semantic_run_fails_without_the_model(self):
        (self.cache / "llama.cpp" / MODEL).unlink()
        code, out = self.run_command(
            "bash", "git-hooks/bootstrap", "full", self.head()
        )
        self.assert_blocked(code, out, CANDIDATES)
        self.assertIn("the semantic run never downloads it", out)

    def test_semantic_server_has_only_loopback(self):
        seen = self.tmp / "seen"
        stub = self.stubs / "llama-server"
        stub.write_text(
            "#!/bin/sh\n"
            '[ "$1" = --version ] && echo "version: stub" && exit 0\n'
            f'{{ readlink /proc/self/ns/net; ip -o link | cut -d: -f2; }} >"{seen}"\n'
            "exit 1\n"
        )
        stub.chmod(0o755)
        code, out = self.run_command(
            "bash", "git-hooks/bootstrap", "full", self.head()
        )
        self.assert_blocked(code, out, CANDIDATES)
        self.assertIn("llama-server did not become healthy", out)
        namespace, *links = seen.read_text().split()
        self.assertNotEqual(
            namespace, str(Path("/proc/self/ns/net").readlink())
        )
        self.assertEqual(links, ["lo"])


class Reports(Case):
    """report.py on known input, outside any repository."""

    def setUp(self):
        tmp = tempfile.TemporaryDirectory(prefix="git-hooks-report-")
        self.addCleanup(tmp.cleanup)
        self.dir = Path(tmp.name)
        (self.dir / "tmp").mkdir()
        shutil.copy2(ROOT / ".editorconfig", self.dir)
        self.env = clean_env() | {
            "LC_ALL": "C.UTF-8",
            "NO_COLOR": "1",
            "XDG_CACHE_HOME": str(self.dir / "cache"),
            "XDG_CONFIG_HOME": str(self.dir / "config"),
        }

    def report(self, records, *args):
        proc = subprocess.run(
            ["python3", "-I", str(ROOT / "git-hooks/report.py"), *args],
            cwd=self.dir,
            input="".join(f"{r}\0" for r in records),
            env=self.env,
            capture_output=True,
            text=True,
            timeout=120,
            check=False,
        )
        return proc.returncode, proc.stdout + proc.stderr

    def clones(self, records):
        return self.report(
            records, "clones", "planned", "", str(self.dir / "tmp")
        )

    def test_chain_and_line_counter_on_known_input(self):
        (self.dir / "known").write_text(
            "#!/bin/bash\n"
            "a | b | c\n"
            "a | b | c | d\n"
            "a && b && c && d && e\n"
            "{ a | b; } | c | d\n"
            'x="$(a | b | c | d)"\n'
            "a | b && c | d && e\n"
            "echo " + "x" * 76 + "\n"
            "echo " + "é" * 75 + "\n"
        )
        code, out = self.report(["bash:known"], "indicators")
        self.assertEqual(code, 0, out)
        self.assertEqual(
            out.splitlines(),
            [
                "known:3: pipeline of 4",
                "known:4: &&/|| chain of 5",
                "known:6: pipeline of 4",
                "known:8: 81 columns",
            ],
        )

    def test_python_gets_line_lengths_but_no_chain_count(self):
        # shfmt cannot parse this, so a chain count would list it as not measured.
        (self.dir / "tool.py").write_text("if x:\n    pass\n" + "#" * 81 + "\n")
        (self.dir / "known").write_text("#!/bin/bash\na | b | c | d\n")
        code, out = self.report(["bash:known", "python:tool.py"], "indicators")
        self.assertEqual(code, 0, out)
        self.assertEqual(
            out.splitlines(),
            ["known:2: pipeline of 4", "tool.py:3: 81 columns"],
        )

    def test_unparsable_file_is_listed_as_not_measured_and_the_rest_still_are(
        self,
    ):
        (self.dir / "broken").write_text(
            "#!/bin/bash\nif true; then\n" + "#" * 81 + "\n"
        )
        (self.dir / "known").write_text("#!/bin/bash\na | b | c | d\n")
        (self.dir / "named").write_text("#!/bin/bash\n")
        code, out = self.report(
            ["bash:named", "bash:broken", "bash:known"], "indicators", "named"
        )
        self.assertEqual(code, 0, out)
        self.assertEqual(
            out.splitlines(),
            [
                "broken:3: 81 columns",
                "known:2: pipeline of 4",
                "chains not measured (shfmt cannot parse them): broken, named",
            ],
        )

    def test_tiny_file_passes_the_count_check_and_a_skipped_one_fails(self):
        (self.dir / "one").write_text("#!/bin/bash\n" + CLONE_SHELL)
        (self.dir / "tiny").write_text("#!/bin/bash\necho hi\n")
        code, out = self.clones(["bash:one", "bash:tiny"])
        self.assertEqual(code, 0, out)
        self.assertRegex(
            out,
            r"below the 50-token or 5-line minimum, so it cannot hold a clone: tiny \(\d+ tokens",
        )
        # Over both token minimums, but under 5 lines, which jscpd never analyzes.
        words = " ".join(f"w{n}" for n in range(40))
        (self.dir / "short").write_text(f"#!/bin/bash\nprintf '%s' {words}\n")
        for kind in ("planned", "broad"):
            code, out = self.report(
                ["bash:one", "bash:short"],
                "clones",
                kind,
                "",
                str(self.dir / "tmp"),
            )
            self.assertEqual(code, 0, out)
            self.assertRegex(
                out, r"cannot hold a clone: short \(\d+ tokens, 2 lines\)"
            )
        for name in ("__init__.py", "blank.py"):
            (self.dir / name).write_text(
                "" if name == "__init__.py" else "\n  \n"
            )
        code, out = self.clones(
            ["bash:one", "python:__init__.py", "python:blank.py"]
        )
        self.assertEqual(code, 0, out)
        self.assertIn("empty, so it cannot hold a clone: __init__.py", out)
        self.assertIn("empty, so it cannot hold a clone: blank.py", out)
        # jscpd skips files over 1 MB whatever their size in tokens.
        (self.dir / "huge").write_text(
            "".join(f"echo {n}\n" for n in range(150_000))
        )
        code, out = self.clones(["bash:one", "bash:huge"])
        self.assert_fails(code, out, "jscpd skipped huge")

    def test_named_standalone_file_is_quiet_until_it_grows(self):
        (self.dir / "one").write_text("#!/bin/bash\n" + CLONE_SHELL)
        (self.dir / "bash").mkdir()
        (self.dir / "bash/pdf-meta").write_text("#!/bin/sh\nexec true\n")
        code, out = self.clones(["bash:one", "bash:bash/pdf-meta"])
        self.assertEqual(code, 0, out)
        self.assertNotIn("pdf-meta", out)
        self.assertIn("2 files listed, 1 analyzed", out)
        (self.dir / "bash/pdf-meta").write_text("#!/bin/bash\n" + CLONE_SHELL)
        code, out = self.clones(["bash:one", "bash:bash/pdf-meta"])
        self.assertEqual(code, 0, out)
        self.assert_clone(out, "one", "bash/pdf-meta")

    def test_name_under_two_formats_fails(self):
        for name in ("a/tool", "b/tool"):
            (self.dir / name).parent.mkdir()
            (self.dir / name).write_text("#!/bin/bash\n" + CLONE_SHELL)
        code, out = self.clones(["bash:a/tool", "python:b/tool"])
        self.assert_fails(code, out, "tool is both bash and python")

    def test_empty_scan_fails(self):
        code, out = self.clones([])
        self.assert_fails(code, out, "scan would be empty")

    def test_record_without_a_known_format_fails(self):
        code, out = self.clones(["ruby:a"])
        self.assert_fails(code, out, "not a format:path record")


if __name__ == "__main__":
    unittest.main()
