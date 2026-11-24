# Clone verdicts

Judged clones from `git-hooks/checks` (the planned run and the broad candidates),
so a clone is judged once. Why the clone checks work this way:
`docs/herdr-implementation.md`, Milestone 0.

Match a new report against an entry by its files and its quote, never by line
numbers or jscpd fingerprints, which any edit changes. Judge only clones without
an entry; take an uncertain match to the user. A clone the user decides to fix
later goes to `TODO.md`, not here.

Entry format, one per clone, newest last. One exception is tests (user decision,
2026-11-09; `docs/herdr-implementation.md`, Milestone 0.5): short repeated steps in
tests share a single group entry. A helper copied between test files, a test clone of
13 lines or more, and every clone touching production code get their own. A helper
counts as copied when the clone starts at a helper definition in both files, renamed
or not; a window that starts elsewhere and runs into one, from call arguments or env
lines, is a short step (user decision, 2026-11-17). Production clones, copied test
helpers and test clones of 13 lines or more judged in one batch may share a group entry
by verdict when it lists each file pair with a quote of the clone's first line, both
sides' when they differ (user decisions, 2026-11-16 and 2026-11-17). Match a report
against a group by that quote, not by the file pair alone.

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
- Lines when judged: bash/vifm-pick:62-68 <-> zsh/functions/pdf.zsh:28-34 (re-judged
  2026-11-16 after 651bff5 and 1528573 rewrote both; vifm-pick lines moved
  2026-11-24 when papers() was added above, code unchanged)

## Lists and tables (group)
- Verdict: false positive
- Reason: one item per line (imports, arguments, constants, palette and style
  rows) matches itself shifted by a line, or an unrelated list elsewhere.
- Date: 2026-11-16
- Pairs:
  - bash/capture-ocr <-> tests/test_herdr_cargo.py, test_git_hooks.py: `import http.client`
    or `import json` <-> `import io`, `import contextlib`
  - bash/capture-ocr <-> git-hooks/report.py: `key = secrets.token_urlsafe(16)` <->
    `config.write_text("{}\n", encoding="utf-8")`
  - bash/gdocs-open <-> itself: `b='\e[1m'`
  - bash/status-menu <-> itself: `BAT_FULL=$'…'`
  - zsh/helpers.zsh <-> itself: `echo -e "Status:   ${color}…`
  - ptpython/config.py <-> itself and three tests' env dicts: `"fg": "#abb2bf",`,
    `"green": "#98c379",` or `"colors": {` <-> `"PATH": str(self.base / "hostile-path"),`
    (test_niri_session_isolated.py), `stub.write_text(` (test_sysup_agent_tools.py),
    `mappings = {` (test_config_drift.py)

## Guards and early exits (group)
- Verdict: accepted
- Reason: the standard guard shape; condition, message and exit code differ at
  each site, so sharing them would only hide what each checks. Early exits are
  `[[ cond ]] || exit` unless inverting reads worse (zsh/.zshrc keeps three).
- Date: 2026-11-16
- Pairs:
  - bash/audio-switch <-> bash/mic-control, bash/papis-fuzzel: `|| {` + `notify`
  - bash/herdr-cargo <-> bash/mirrorlist-rank: `[[ -n ${2:-} && $2 != --* ]] ||` <->
    `[[ ${2:-} =~ ^(0(\.[0-9]+)?|1(\.0+)?)$ ]] ||`
  - bash/media-menu.sh <-> itself: `player=$(resolve_player)`
  - bash/papis-add-paper <-> itself: `[[ -n "$importer" && -n "$identifier" ]] || {`
  - git-hooks/hook <-> itself: `if git cat-file -e :git-hooks/bootstrap`
  - install.sh <-> itself: `htop_dest="${XDG_CONFIG_HOME}/htop/htoprc"`
  - system-sleep/fprintd-resume <-> unblock-fuse: `if output=$(systemctl --no-block
    try-restart fprintd.service 2>&1); then` <-> `"$0" remount 2>&1); then`
  - system-sleep/unblock-fuse <-> itself: `if [ -z "$first" ]; then` <-> `if [ -z "$stuck" ]; then`
  - zsh/functions/sysclean.zsh <-> sysup.zsh: `[[ -n ${SHPOOL_SESSION_NAME:-} ]] || {`
  - zsh/functions/sysclean.zsh <-> sysup/nvim-health.zsh, sysup/podman.zsh:
    `_sysclean_nvme_health() {` <-> `_sysup_nvim_health() {`, `_sysup_podman_images() {`
  - zsh/functions/virtualenv.zsh <-> itself: `[[ -n "$VIRTUAL_ENV" ]] || {`

## fzf pickers (group)
- Verdict: accepted
- Reason: the zsh pickers share `_fzf_pick` (zsh/helpers.zsh); what matches is
  each picker's own options and key actions. vifm-pick mirrors them in Bash,
  where `_fzf_pick` is not available.
- Date: 2026-11-16 (re-judged 2026-11-24: vifm-pick's pickers now take the key
  from fzf --expect, so the repeated lines changed)
- Pairs:
  - bash/vifm-pick <-> itself: `if [[ $key == ctrl-d ]]; then`,
    `key=${out%%$'\n'*} result=${out#*$'\n'}`, `--header='Enter: goto`
  - zsh/functions/pdf.zsh, search.zsh, fzf.zsh <-> each other and themselves:
    `case "$key" in`, `--bind 'ctrl-p:toggle-preview' \`, `| _fzf_pick key file`

## Copied test helpers (group)
- Verdict: accepted
- Reason: each file's own small fixture tools (fake and stub writers, log readers,
  run wrappers); copies differ in their fake's log format and arguments, and the
  repo keeps no shared test module.
- Date: 2026-11-17
- Pairs, all in tests/:
  - test_capture_ocr.py <-> test_papis_fuzzel.py, test_sioyek_papis.py:
    `def fake(self, name, body):`
  - test_cliphist_store_guard.py <-> test_niri_session_isolated.py: `def calls(self):`
  - test_install_user_units.py <-> test_media_menu_recording.py:
    `def stub(self, name, body):`
  - test_sysup_agent_tools.py <-> test_sysup_herdr.py:
    `def run_sysup(self, stubs="", **env):`,
    `def run_sysup(self, stubs, args="", after=""):`
  - test_sysup_ctrl_c.py <-> test_sysup_podman.py: `def ran(self):`, `def calls(self):`

## Short repeated steps in tests (group)
- Verdict: accepted
- Scope: a clone under 13 lines between tests or within one, that does not
  start at a helper definition in both files (see "Copied test helpers").
- Reason: each test spells out its own setup, call and checks so it reads
  alone; what matches is that shape with different data: imports and module
  constants, the setUp skeleton (temporary directory, fake bin, env dict),
  subprocess.run arguments, fake-script bodies, table rows, and one test's
  last checks running into the next test's first lines.
- Not covered: the same lines with the same data in two tests, which is one
  test written twice; judge that one on its own.
- Date: 2026-11-17

## Test clones of 13 lines or more, accepted (group)
- Verdict: accepted
- Reason: each test keeps its own setup and checks with different data (tool,
  exit code, file, page); the git-hooks pair is a clone on purpose, the fixture
  for the clone check; the git helper is a copied test helper.
- Date: 2026-11-17
- Pairs, all in tests/:
  - test_cliphist_store_guard.py <-> itself: `self.assertEqual(len(self.calls()), 1)`,
    `self.assertEqual(self.calls(), [])`
  - test_git_hooks.py <-> itself: `CLONE_PYTHON = '''"""Fixture module."""`,
    `SIMILAR_PYTHON = '''"""Fixture module."""`
  - test_git_hooks.py <-> itself: `self.assertIn("SC1017", out)`,
    `self.assert_passed(code, out)`
  - test_install_user_units.py <-> test_sysup_herdr.py: `["/bin/bash", str(SOURCE)],`,
    `["zsh", "-f", "-c", code, "test", str(source), str(self.helper)],`
  - test_papis_add_paper.py <-> test_papis_fuzzel.py:
    ``papis creates the entry the way `papis add --set ref` would.``,
    `fake fuzzel records the menu and picks the line matching $PICK.`
  - test_sioyek_papis.py <-> itself: `self.assertEqual(` (the `refs = [` tests)
  - test_sysup_bgutil.py <-> test_sysup_yts.py: `str(directory),`, `str(self.repo),`
  - test_vifm_pick_rgbook.py <-> itself:
    `self.assertTrue(any("beta.pdf:Page 3:" in x for x in rows))`,
    `self.run_caller(caller, "Optimal", "beta.pdf:Page 3")`

## Test clones of 13 lines or more, false positives (group)
- Verdict: false positive
- Reason: table and data rows matching themselves shifted, or two unrelated
  subTest lists.
- Date: 2026-11-17
- Pairs, all in tests/:
  - test_config_drift.py <-> itself:
    `(base.replace('client_id = "SECRET_TEMPLATE"\n', ""), None),`, `),`
  - test_niri_session_isolated.py <-> test_sysup_bgutil.py: `)`, `self.assertEqual(`
  - test_sioyek_papis.py <-> itself: `"citation_key": "[1]",`, `"citation_key": "[3]",`
