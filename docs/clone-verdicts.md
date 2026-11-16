# Clone verdicts

Judged clones from `git-hooks/checks` (the planned run and the broad candidates),
so a clone is judged once. Why the clone checks work this way:
`docs/herdr-implementation.md`, Milestone 0.

Match a new report against an entry by its files and its quote, never by line
numbers or jscpd fingerprints, which any edit changes. Judge only clones without
an entry; take an uncertain match to the user. A clone the user decides to fix
later goes to `TODO.md`, not here.

Entry format, one per clone, newest last. One exception is tests (user decision,
2026-11-09; `docs/herdr-implementation.md`, Milestone 0.5): short repeated steps inside
test methods share a single group entry. A helper copied between test files, a test
clone of 13 lines or more, and every clone touching production code get their own,
except that production clones judged in one batch may share a group entry by verdict
when it lists each file pair with a quote of the clone's first line (user decision,
2026-11-16). Match a report against a group by that quote, not by the file pair alone.

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
- Lines when judged: bash/vifm-pick:51-57 <-> zsh/functions/pdf.zsh:28-34 (re-judged
  2026-11-16 after 651bff5 and 1528573 rewrote both)

## Lists and tables (group)
- Verdict: false positive
- Reason: one item per line (imports, arguments, constants, palette and style
  rows) matches itself shifted by a line, or an unrelated list elsewhere.
- Date: 2026-11-16
- Pairs:
  - bash/capture-ocr <-> tests/test_herdr_cargo.py, test_git_hooks.py: `import json`
  - bash/capture-ocr <-> git-hooks/report.py: `key = secrets.token_urlsafe(16)`
  - bash/gdocs-open <-> itself: `b='\e[1m'`
  - bash/status-menu <-> itself: `BAT_FULL=$'…'`
  - zsh/helpers.zsh <-> itself: `echo -e "Status:   ${color}…`
  - ptpython/config.py <-> itself and three tests' env dicts: `"fg": "#abb2bf",`

## Guards and early exits (group)
- Verdict: accepted
- Reason: the standard guard shape; condition, message and exit code differ at
  each site, so sharing them would only hide what each checks. Early exits are
  `[[ cond ]] || exit` unless inverting reads worse (zsh/.zshrc keeps three).
- Date: 2026-11-16
- Pairs:
  - bash/audio-switch <-> bash/mic-control, bash/papis-fuzzel: `|| {` + `notify`
  - bash/herdr-cargo <-> bash/mirrorlist-rank: `[[ -n ${2:-} && $2 != --* ]] ||`
  - bash/media-menu.sh <-> itself: `player=$(resolve_player)`
  - bash/papis-add-paper <-> itself: `[[ -n "$importer" && -n "$identifier" ]] || {`
  - git-hooks/hook <-> itself: `if git cat-file -e :git-hooks/bootstrap`
  - install.sh <-> itself: `htop_dest="${XDG_CONFIG_HOME}/htop/htoprc"`
  - system-sleep/fprintd-resume, unblock-fuse <-> unblock-fuse: `if [ -z "$first" ]`
  - zsh/functions/sysclean.zsh <-> sysup.zsh: `[[ -n ${SHPOOL_SESSION_NAME:-} ]] || {`
  - zsh/functions/sysclean.zsh, sysup/*.zsh: `command -v nvim >/dev/null 2>&1 || {`,
    `_sysup_bgutil() (` + `emulate -L zsh`, `if [[ ! -r $ml ]]; then`
  - zsh/functions/virtualenv.zsh <-> itself: `[[ -n "$VIRTUAL_ENV" ]] || {`

## fzf pickers (group)
- Verdict: accepted
- Reason: the zsh pickers share `_fzf_pick` (zsh/helpers.zsh); what matches is
  each picker's own options and key actions. vifm-pick mirrors them in Bash,
  where `_fzf_pick` is not available.
- Date: 2026-11-16
- Pairs:
  - bash/vifm-pick <-> itself: `if [[ -e "$xdir/cd" ]]; then`, `--header='Enter: goto`
  - zsh/functions/pdf.zsh, search.zsh, fzf.zsh <-> each other and themselves:
    `case "$key" in`, `--bind 'ctrl-p:toggle-preview' \`, `| _fzf_pick key file`
