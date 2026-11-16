# Herdr baseline: repository measure, 2026-11

Milestone 0.5's whole-repository run of the checks in `git-hooks/`
(`docs/herdr-implementation.md`), taken on 2026-11-09 at `522eac1`. It is the list the
audit judges; the verdicts are not here but where the plan routes them:
`docs/clone-verdicts.md`, `TODO.md`, `revisit.md` or a fix.

## Rerun

```sh
bash git-hooks/bootstrap full "$(GIT_AUTHOR_NAME=baseline GIT_AUTHOR_EMAIL=baseline@localhost GIT_AUTHOR_DATE=2000-01-01T00:00:00Z GIT_COMMITTER_NAME=baseline GIT_COMMITTER_EMAIL=baseline@localhost GIT_COMMITTER_DATE=2000-01-01T00:00:00Z git commit-tree --no-gpg-sign "$(git hash-object -t tree /dev/null)" -m 'empty tree: the base for a whole-repository full run')"
```

The command measures the commit checked out, so on a later commit it gives that commit's
counts. To reproduce the counts below, run it from a worktree at `522eac1`
(`git worktree add --detach ../dotfiles-baseline 522eac1`, then
`git worktree remove ../dotfiles-baseline`), not by switching this checkout, whose files
are live configuration; identical counts also need the versions listed below.

The full run lists only what is new since its base commit, so the base here is a commit
holding no files: nothing is hidden. The inner command creates it, always with the ID
`964eed6eb68d6c51ccc5eebe384ecca165c9a8e0`. No branch holds it, so Git may prune it;
the line above creates it again. The repository's first commit is not used as the base:
it already holds four files, and a clone present there would be left out.

The raw output, about 1,800 lines, is not tracked: its line numbers change with any
edit. The run takes about a minute.

## Versions and configuration

```
prek 0.5.10
shfmt v3.14.1
shellcheck 0.11.0
ruff 0.17.4
jscpd 5.4.3
llama-server 0.6.0-dev (build 11429, commit d812350493)
Python 3.14.9
zsh 5.9.2 (x86_64-pc-linux-gnu)
bash 5.3.20(1)-release
git version 2.56.0
base 964eed6eb68d6c51ccc5eebe384ecca165c9a8e0
```

Not printed by the run: `util-linux 2.42.4-1` (`unshare`), `iproute2 7.3.0-1` (`ip`),
`curl 8.23.0-1`, and the model file `jina-code-embeddings-0.5b-F16.gguf`, SHA-256
`81f7d569cdd10dab45aef7582b5d2bb12a21b2aa34580b33c5ea3b926b521cfc`.

The settings are the tracked ones at `522eac1`: `.pre-commit-config.yaml`, `git-hooks/`,
`.shellcheckrc`, `ruff.toml` and `.editorconfig`. Scope and thresholds:
`docs/architecture/git-hooks.md`, "Scope" and "Measurement limits".

## Coverage

The scans list 78 production files (shell, and Python outside `tests/`), 38 of them
without a file extension, and 111 with the tests. The clone scan fails when it leaves out
a file large enough to hold a clone
(`test_tiny_file_passes_the_count_check_and_a_skipped_one_fails` in
`tests/test_git_hooks.py`); here it left out only files named as standalone in
`docs/clone-verdicts.md`. No executable was outside every checked dialect. Chains are not
measured in `zsh/functions/sysup.zsh` and `zsh/functions/sysup/tool-tests.zsh`, which
shfmt cannot parse.

## Results

The blocking checks pass: whitespace, shell syntax, ShellCheck, shfmt and ruff.

| Report | Count |
|---|---|
| Clones, planned settings | 1 |
| Clone candidates, broad settings | 590 (17 exact, 573 renamed) |
| Clone candidates, syntax tree (Python outside `tests/`) | 0 |
| Clone candidates, semantic (Python outside `tests/`) | 0 |
| Masked return codes | 107 in 25 files |
| Lines over 80 columns | 966 in 99 files |
| Pipelines or `&&`/`\|\|` chains longer than 3 | 3 |

**The planned clone** is a 43-line awk formatter in both `bash/vifm-pick` and
`zsh/functions/pdf.zsh`.

**The broad candidates:** 528 have both sides in `tests/` (278 across two files, 250
within one); 60 have both sides in production code (23 across two files, 37 within one);
2 pair `bash/capture-ocr` with a test file.

**Masked return codes** per file:
`bash/herdr-cargo` 14, `bash/status-menu` 12, `bash/mirrorlist-rank` 10,
`bash/papis-bib` 10, `bash/config-drift.d/etc-baselines.sh` 9, `bash/media-menu.sh` 8,
`bash/sioyek-papis` 7, `bash/vifm-pick` 5, `bash/check-skills` 4, `install-root.sh` 4,
`bash/papis-add-paper` 3, `bash/powermenu` 3, `bash/wob-control` 3,
`bash/config-drift.d/sioyek.sh` 2, `system-sleep/unblock-fuse` 2,
`zsh/generate-completions.sh` 2, `bash/audio-switch` 1, `bash/config-drift` 1,
`bash/lock-once` 1, `bash/mic-control` 1, `bash/pdf-meta` 1, `bash/run-tests` 1,
`bash/service-failed-notify` 1, `git-hooks/bootstrap` 1, `install.sh` 1.

**Lines over 80 columns:** 764 in production code, 46 of them over 120; 202 in `tests/`,
none over 120.

**Long pipelines:** 4 commands in `bash/check-skills`, 5 in `bash/papis-add-paper` and 5
in `zsh/functions/search.zsh`.

## Size and complexity

Every production file, 10,623 lines in all, largest estimate first. Complexity is
jscpd's estimate for the whole file: an indicator for review, not a per-function measure.

| File | Lines | Bytes | Complexity |
|---|---|---|---|
| `zsh/functions/virtualenv.zsh` | 739 | 24113 | 108 |
| `git-hooks/report.py` | 402 | 13833 | 90 |
| `zsh/functions/sysup.zsh` | 415 | 18625 | 80 |
| `zsh/helpers.zsh` | 248 | 9417 | 77 |
| `bash/herdr-cargo` | 226 | 11644 | 73 |
| `bash/capture-ocr` | 480 | 17122 | 66 |
| `bash/sioyek-papis` | 326 | 13095 | 65 |
| `bash/config-drift` | 362 | 13576 | 61 |
| `zsh/functions/sysclean.zsh` | 318 | 12720 | 56 |
| `git-hooks/checks` | 353 | 11519 | 54 |
| `bash/media-menu.sh` | 236 | 8285 | 53 |
| `install.sh` | 421 | 18264 | 50 |
| `bash/papis-bib` | 255 | 9659 | 44 |
| `niri/niri-session-isolated` | 113 | 4847 | 43 |
| `bash/status-menu` | 176 | 7634 | 39 |
| `zsh/functions/git-enhancements.zsh` | 316 | 10998 | 38 |
| `zsh/.zshrc` | 285 | 11386 | 38 |
| `zsh/functions/sysup/bgutil.zsh` | 121 | 5455 | 35 |
| `bash/check-skills` | 136 | 5099 | 33 |
| `git-hooks/bootstrap` | 161 | 7021 | 33 |
| `bash/papis-add-paper` | 194 | 8319 | 31 |
| `zsh/functions/pdf.zsh` | 226 | 8548 | 31 |
| `bash/config-drift.d/pacman-transaction.sh` | 85 | 3652 | 27 |
| `bash/mirrorlist-rank` | 128 | 5233 | 27 |
| `bash/vifm-pick` | 214 | 8417 | 27 |
| `bash/config-drift.d/symlink-integrity.sh` | 150 | 7268 | 24 |
| `system-sleep/unblock-fuse` | 143 | 6169 | 24 |
| `bash/gdocs-open` | 160 | 5776 | 23 |
| `zsh/functions/papis.zsh` | 110 | 4190 | 20 |
| `install-root.sh` | 164 | 7894 | 19 |
| `zsh/functions/search.zsh` | 228 | 7846 | 19 |
| `zsh/functions/sysup/mirrorlist.zsh` | 94 | 3552 | 19 |
| `bash/config-drift.d/etc-baselines.sh` | 85 | 4154 | 17 |
| `bash/sioyek-papis-note` | 116 | 3767 | 16 |
| `bash/powermenu` | 87 | 2396 | 15 |
| `zsh/functions/sysup/tool-tests.zsh` | 84 | 4145 | 15 |
| `zsh/functions/fzf.zsh` | 134 | 5413 | 14 |
| `zsh/functions/sysup/podman.zsh` | 72 | 2293 | 14 |
| `zsh/functions/sysup/plugins.zsh` | 56 | 2798 | 13 |
| `zsh/generate-completions.sh` | 143 | 5117 | 13 |
| `bash/cliphist-store-guard` | 55 | 1634 | 12 |
| `bash/fuzzel-restore-shpool` | 59 | 2186 | 12 |
| `bash/papis-fuzzel` | 52 | 2148 | 12 |
| `ptpython/config.py` | 348 | 14048 | 12 |
| `zsh/functions/shpool.zsh` | 88 | 3815 | 12 |
| `zsh/functions/sysup/yts.zsh` | 70 | 2909 | 12 |
| `zsh/functions/sysup/nvim-health.zsh` | 59 | 2224 | 11 |
| `bash/cmus-open` | 25 | 768 | 10 |
| `bash/config-drift.d/spotify.sh` | 54 | 2018 | 10 |
| `zsh/aliases` | 154 | 6913 | 10 |
| `zsh/functions/cpp.zsh` | 88 | 2551 | 10 |
| `bash/config-drift.d/sioyek.sh` | 37 | 1949 | 8 |
| `bash/sioyek-to-source` | 54 | 1844 | 8 |
| `zsh/functions/sysup/claude-prune.zsh` | 35 | 1263 | 8 |
| `bash/hardware-readings` | 35 | 1421 | 7 |
| `bash/mic-control` | 44 | 1511 | 7 |
| `bash/qrscan` | 42 | 1360 | 7 |
| `zsh/functions/last_working_dir.zsh` | 51 | 1633 | 7 |
| `zsh/update-plugins.sh` | 48 | 1506 | 7 |
| `bash/audio-switch` | 29 | 1009 | 6 |
| `bash/wob-control` | 49 | 1665 | 6 |
| `bash/keyring-lock` | 23 | 1004 | 5 |
| `bash/lock-once` | 32 | 1543 | 5 |
| `bash/run-tests` | 41 | 1321 | 5 |
| `git-hooks/hook` | 25 | 1122 | 5 |
| `bash/sioyek-search` | 19 | 844 | 4 |
| `bash/toggle-foot-theme.sh` | 22 | 1016 | 4 |
| `bash/service-failed-notify` | 30 | 1096 | 3 |
| `ipython/profile_default/startup/01-theme.py` | 16 | 440 | 3 |
| `system-sleep/fprintd-resume` | 15 | 671 | 3 |
| `zsh/functions/clipboard.zsh` | 14 | 374 | 3 |
| `direnv/direnvrc` | 14 | 398 | 2 |
| `zsh/functions/audio.zsh` | 21 | 647 | 2 |
| `zsh/functions/sysup/herdr.zsh` | 9 | 405 | 2 |
| `bash/open-detached` | 9 | 603 | 1 |
| `bash/pdf-meta` | 2 | 85 | 1 |
| `ipython/profile_default/ipython_config.py` | 13 | 426 | 1 |
| `zsh/.zshenv` | 80 | 3273 | 1 |
