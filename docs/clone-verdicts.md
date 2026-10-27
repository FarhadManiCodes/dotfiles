# Clone verdicts

Judged clones from `git-hooks/checks` (the planned run and the broad candidates),
so a clone is judged once. Why the clone checks work this way:
`docs/herdr-implementation.md`, Milestone 0.

Match a new report against an entry by its files and its quote, never by line
numbers or jscpd fingerprints, which any edit changes. Judge only clones without
an entry; take an uncertain match to the user. A clone the user decides to fix
later goes to `TODO.md`, not here.

Entry format, one per clone, newest last:

```
## <file> <-> <file>
- Verdict: accepted | false positive
- Code: <function name, or a short quote of the clone's first line>
- Reason: <why it stays, or why it is not a real copy>
- Date: <yyyy-mm-dd>
- Lines when judged: <file:start-end <-> file:start-end> (a hint only)
```

## Too small to hold a clone, by design

Below the token runs' 50-token or 5-line minimum, and each stands alone by
design, so it is not merged into another file. `STANDALONE` in
`git-hooks/report.py` names them, which only stops the clone report listing
them as below the minimum at every commit. They stay in every check and scan:
one that grows past the minimum is scanned and its clones reported as usual.

- `bash/open-detached`: a command run by name, from vifm and shells.
- `bash/pdf-meta`: a command run by name; it starts `.pdf-meta.js` under mutool.
- `ipython/profile_default/ipython_config.py`: IPython reads it by name.

Decided 2026-10-25; a map of how files group for jscpd is planned for later.

## Verdicts

No verdicts yet.
