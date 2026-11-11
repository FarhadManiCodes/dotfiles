# Clone verdicts

Judged clones from `git-hooks/checks` (the planned run and the broad candidates),
so a clone is judged once. Why the clone checks work this way:
`docs/herdr-implementation.md`, Milestone 0.

Match a new report against an entry by its files and its quote, never by line
numbers or jscpd fingerprints, which any edit changes. Judge only clones without
an entry; take an uncertain match to the user. A clone the user decides to fix
later goes to `TODO.md`, not here.

Entry format, one per clone, newest last. The one exception is tests (user decision,
2026-11-09; `docs/herdr-implementation.md`, Milestone 0.5): short repeated steps inside
test methods share a single group entry. A helper copied between test files, a test
clone of 13 lines or more, and every clone touching production code get their own.

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

## bash/vifm-pick <-> zsh/functions/pdf.zsh
- Verdict: accepted
- Code: `open_book()` and `_open_book()`, with the sioyek comment above them
- Reason: two callers by design: the zsh pickers change the shell's directory
  and vifm needs a script; the function has no other caller, so a command on
  `PATH` for it was declined. The "MIRRORS" comment at the top of each file
  names the other. A test comparing more of the two copies was dropped as out of
  proportion (2026-11-11).
- Date: 2026-11-11
- Lines when judged: bash/vifm-pick:45-53 <-> zsh/functions/pdf.zsh:21-29
