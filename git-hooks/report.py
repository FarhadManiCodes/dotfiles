"""Reports for git-hooks/checks that need jscpd's or shfmt's JSON.

    report.py clones planned|broad|similarity BASE TMP   clones new since BASE (all if empty)
    report.py clones semantic BASE TMP URL               the same, embeddings served at URL
    report.py indicators [UNPARSED...]                   long chains and lines (report only)
    report.py measure BASE TMP OLD OLD_RECORDS           size and complexity, BASE against now

Each reads the files in scope from stdin as NUL-separated `format:path`
records, format bash or python, and runs from the top of the snapshot. measure
also reads BASE's records from OLD_RECORDS, with BASE's tree checked out in
OLD. Only a scan can fail, and only when the scan itself is wrong: clones are
reported, never blocking.
"""

import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

FORMATS = {"bash", "python"}
# The token runs, by their flags and minimum: the planned one keeps jscpd's
# defaults, and the broad one finds renamed copies down to 30 tokens.
TOKEN_RUNS = {
    "planned": ([], 50),
    "broad": (["--mode", "strict", "--ignore-identifiers", "--ignore-literals", "--kind", "exact,renamed"], 30),
}
MIN_LINES = 5  # jscpd's default, kept by both token runs: a shorter file is never analyzed
SIMILARITY = ["--similarity", "--kind", "ast"]
# Below jina's calibrated 0.7125, so that functions doing the same thing
# written differently are reported (docs/herdr-implementation.md).
SEMANTIC = [
    "--semantic",
    "--kind",
    "semantic",
    "--semantic-model",
    "jina-code-embeddings-0.5b",
    "--semantic-same-threshold",
    "0.6375",
]
# Below the token runs' minimums and standing alone by design, so their
# below-minimum line is not printed; one that grows is scanned as usual
# (docs/clone-verdicts.md).
STANDALONE = {
    "bash/open-detached",
    "bash/pdf-meta",
    "ipython/profile_default/ipython_config.py",
    "ipython/profile_default/startup/00-imports.py",
}
CHAIN_LIMIT = 3
LINE_LIMIT = 80
PIPES, LOGIC = {"|", "|&"}, {"&&", "||"}


def fail(message):
    sys.exit(f"report: {message}")


def mapping(files):
    """jscpd's --formats-names for files, a {path: format} dict.

    Every file is mapped: jscpd skips extensionless files without a shebang
    otherwise, and counts them as 0 tokens like a tiny file. It matches names,
    not paths, and takes one prefix and a comma-separated list per format;
    `bash:a,bash:b` would map only `a`.
    """
    formats = {}
    for path, form in files.items():
        name = os.path.basename(path)
        if "," in name or ";" in name:
            fail(f"{path}: ',' and ';' cannot be expressed in jscpd's name mapping")
        if formats.setdefault(name, form) != form:
            fail(f"{name} is both {formats[name]} and {form}; jscpd maps formats by file name")
    names = {}
    for name, form in sorted(formats.items()):
        names.setdefault(form, []).append(name)
    return ";".join(f"{form}:{','.join(n)}" for form, n in sorted(names.items()))


def jscpd(files, tmp, *flags, report="jscpd-report", root=None):
    """Scan files, a {path: format} dict, with jscpd and return its JSON report."""
    out = tempfile.mkdtemp(dir=tmp)
    proc = subprocess.run(
        [
            "jscpd",
            "--absolute",
            "--no-gitignore",
            "--silent",
            "--formats-names",
            mapping(files),
            "--reporters",
            "json",
            "--output",
            out,
            *flags,
            "--",
            *files,
        ],
        cwd=root,
        # The semantic run's embeddings cache goes into the snapshot.
        env=os.environ | {"XDG_CACHE_HOME": os.path.join(tmp, "cache")},
        capture_output=True,
        encoding="utf-8",
        check=False,
    )
    if proc.returncode != 0:
        fail(f"jscpd failed ({proc.returncode}):\n{proc.stdout}{proc.stderr}")
    path = Path(out, report + ".json")
    if not path.exists():
        fail(f"jscpd wrote no {path.name}:\n{proc.stdout}{proc.stderr}")
    return json.loads(path.read_text(encoding="utf-8"))


def relative(path, root):
    return os.path.relpath(path, root)


def analyzed(files, tmp, flags):
    """Paths jscpd analyzes with a token run's flags and minimum."""
    report = jscpd(files, tmp, *flags, "--complexity", "--summary-top", str(len(files)), report="jscpd-complexity")
    return {relative(f["path"], os.getcwd()) for f in report["summary"]["files"]}


def check_count(files, sources, tmp, flags, minimum):
    """Fail unless every file a token run left out is below its minimum tokens or lines."""
    if sources == len(files):
        return
    seen = analyzed(files, tmp, [*flags, "--min-tokens", str(minimum)])
    if len(seen) != sources:
        fail(f"the clone scan analyzed {sources} files and the complexity scan {len(seen)}")
    for f in sorted(set(files) - seen):
        # jscpd never analyzes these, whatever the minimums, such as an empty __init__.py.
        if not Path(f).read_bytes().strip():
            print(f"empty, so it cannot hold a clone: {f}")
            continue
        alone = jscpd({f: files[f]}, tmp, *flags, "--min-tokens", "1", "--min-lines", "1")["statistics"]["total"]
        size = f"{alone['tokens']} tokens, {alone['lines']} lines"
        if alone["sources"] != 1 or (alone["tokens"] >= minimum and alone["lines"] >= MIN_LINES):
            fail(f"jscpd skipped {f} ({alone['sources']} files, {size} alone)")
        if f in STANDALONE:
            continue
        print(f"below the {minimum}-token or {MIN_LINES}-line minimum, so it cannot hold a clone: {f} ({size})")


def scan(kind, files, base, tmp, url):
    """jscpd's report for a clone scan of files, with the token runs' count checked."""
    baseline = ["--baseline-from-ref", base] if base else []
    if kind in TOKEN_RUNS:
        flags, minimum = TOKEN_RUNS[kind]
        report = jscpd(files, tmp, *flags, "--min-tokens", str(minimum), *baseline)
        # Semantic and syntax-tree runs compare functions, so a file without
        # one is not analyzed and no count holds.
        check_count(files, report["statistics"]["total"]["sources"], tmp, flags, minimum)
        return report
    if kind == "similarity":
        return jscpd(files, tmp, *SIMILARITY, *baseline)
    if kind == "semantic":
        if not url:
            fail("the semantic clone scan needs the embeddings server's URL")
        return jscpd(files, tmp, *SEMANTIC, "--semantic-url", url, *baseline)
    return fail(f"unknown clone scan {kind!r}")


def clones(kind, base, tmp, url=None):
    files = read_files()
    if not files:
        fail(f"no files in scope, so the {kind} clone scan would be empty")
    report = scan(kind, files, base, tmp, url)
    new = [d for d in report["duplicates"] if not base or d.get("isNew")]
    since = f"new since {base[:12]}" if base else "in all files (no base commit)"
    lookup = "Look each up in docs/clone-verdicts.md first."
    if kind != "planned":
        print(f"Candidates for judgment ({kind}), {since}; false positives are expected. {lookup}")
    elif new:
        print(lookup)
    for d in new:
        a, b = d["firstFile"], d["secondFile"]
        score = f", similarity {d['similarity']:.3f}" if "similarity" in d else ""
        print(
            f"clone ({d.get('kind', 'exact')}, {d['lines']} lines{score}): "
            f"{relative(a['name'], os.getcwd())}:{a['start']}-{a['end']} <-> "
            f"{relative(b['name'], os.getcwd())}:{b['start']}-{b['end']}"
        )
    print(f"{len(new)} clones {since}; {len(files)} files listed, {report['statistics']['total']['sources']} analyzed")


def chain_length(stmt, ops):
    """Commands in the chain of `ops` that stmt starts, counting nested parts as one."""
    cmd = stmt.get("Cmd") or {}
    if cmd.get("Type") == "BinaryCmd" and cmd["Op"] in ops:
        return chain_length(cmd["X"], ops) + chain_length(cmd["Y"], ops)
    return 1


def chains(node, found, parent_ops=None):
    """Collect (line, kind, length) for every chain longer than CHAIN_LIMIT."""
    if isinstance(node, list):
        for item in node:
            chains(item, found, parent_ops)
        return
    if not isinstance(node, dict):
        return
    cmd = node.get("Cmd")
    if isinstance(cmd, dict) and cmd.get("Type") == "BinaryCmd":
        ops = PIPES if cmd["Op"] in PIPES else LOGIC
        if ops is not parent_ops:  # the top of its chain
            length = chain_length(node, ops)
            if length > CHAIN_LIMIT:
                kind = "pipeline" if ops is PIPES else "&&/|| chain"
                found.append((node["Pos"]["Line"], kind, length))
        chains(cmd["X"], found, ops)
        chains(cmd["Y"], found, ops)
        return
    for value in node.values():
        chains(value, found)


def indicators(*unparsed):
    """Chains are not counted in unparsed, the files shfmt cannot parse, nor in
    any other file it cannot parse: the blocking shell check fails on those."""
    files = read_files()
    skipped = list(set(unparsed) & set(files))
    for f in files:
        notes = [
            (n, f"{len(line)} columns")
            for n, line in enumerate(Path(f).read_text(encoding="utf-8", errors="replace").splitlines(), 1)
            if len(line) > LINE_LIMIT
        ]
        if f not in unparsed:
            # --to-json reads only stdin, and needs --filename to honour .editorconfig.
            with open(f, "rb") as source:
                proc = subprocess.run(
                    ["shfmt", "--to-json", "--filename", f],
                    stdin=source,
                    capture_output=True,
                    encoding="utf-8",
                    check=False,
                )
            if proc.returncode != 0:
                skipped.append(f)
            else:
                found = []
                chains(json.loads(proc.stdout), found)
                notes += [(line, f"{kind} of {length}") for line, kind, length in found]
        for line, note in sorted(notes):
            print(f"{f}:{line}: {note}")
    if skipped:
        print("chains not measured (shfmt cannot parse them): " + ", ".join(sorted(skipped)))


def sizes(files, tmp, root):
    """{path: (lines, bytes, complexity)} for files, a {path: format} dict, under root."""
    if not files:
        return {}
    report = jscpd(
        files,
        tmp,
        "--complexity",
        "--min-tokens",
        "1",
        "--min-lines",
        "1",
        "--summary-top",
        str(len(files)),
        report="jscpd-complexity",
        root=root,
    )
    return {relative(f["path"], root): (f["lines"], f["bytes"], f["complexity"]) for f in report["summary"]["files"]}


def measure(base, tmp, old_root, old_records):
    """Report the production files in scope at either end that changed."""
    new, old = read_files(), parse(Path(old_records).read_bytes())
    diff = subprocess.run(
        ["git", "diff", "--name-only", "--no-renames", "-z", base, "HEAD"], check=True, capture_output=True
    )
    changed = sorted(set(parse_paths(diff.stdout)) & (new.keys() | old.keys()))
    # jscpd reports resolved paths, so a symlink in old_root would match none.
    before = sizes({f: old[f] for f in changed if f in old}, tmp, os.path.realpath(old_root))
    after = sizes({f: new[f] for f in changed if f in new}, tmp, os.getcwd())
    print(
        f"Size and jscpd's file-level complexity estimate, {base[:12]} -> HEAD "
        "(lines, bytes, complexity; an indicator, not a per-function measure):"
    )
    for f in changed:
        print(f"  {f}: {label(f, before, old)} -> {label(f, after, new)}")
    if not changed:
        print("  no production file in scope changed")


def label(f, measured, scope):
    """A file's sizes, or why it has none: jscpd skips empty files and ones over 1 MB."""
    if f in measured:
        return measured[f]
    return "not measured" if f in scope else "not in scope"


def parse_paths(data):
    return [f for f in data.decode().split("\0") if f]


def parse(data):
    """{path: format} from NUL-separated `format:path` records."""
    files = {}
    for record in parse_paths(data):
        form, _, path = record.partition(":")
        if form not in FORMATS or not path:
            fail(f"not a format:path record: {record!r}")
        files[path] = form
    return files


def read_files():
    return parse(sys.stdin.buffer.read())


def main():
    command, *args = sys.argv[1:]
    if command == "clones":
        clones(*args)
    elif command == "indicators":
        indicators(*args)
    elif command == "measure":
        measure(*args)
    else:
        fail(f"unknown command {command!r}")


if __name__ == "__main__":
    main()
