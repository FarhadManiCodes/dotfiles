# Dotfiles agent instructions

Personal Arch Linux + Niri/Wayland configuration for data engineering and scientific
computing. Match the surrounding file's syntax and style; keep changes focused.

## Read the relevant guidance

- Start with `README.md` for the directory map and installation overview.
- Before changing an application or service, read its section in
  `docs/architecture.md` and its local README. Those sections retain operational
  constraints and deliberate decisions, not just background information.
- Before package, system, or audit work, read `docs/system-notes.md`, `TODO.md`, and
  `revisit.md`. Do not reopen accepted findings without new evidence. TODO items
  require the user's involvement; do not act on them unless the current task authorizes it.
- Read `niri/AGENTS.md` before editing Niri and `nvim/AGENTS.md` before editing Neovim,
  including when working from the repository root. Neovim is a separate submodule.
- Existing `CLAUDE.md` files remain for compatibility. Detailed guidance has been
  extracted into the documentation above; keep corresponding guidance synchronized.
  Historical state is not a substitute for inspecting current files.

## Live configuration and installation

- Live configuration is the source of truth when reconciling drift. User configs
  normally symlink into this checkout: confirm with `ls -la` or `readlink` before
  copying. Editing the target already changes the live file; copy back only when
  symlinks were bypassed. Do not overwrite independent live changes.
- Switching branches changes live configuration and can leave dangling links.
  Preserve existing work and inspect affected links when switching.
- `install.sh` installs user configs without sudo. Root files are copied by
  `install-root.sh`, never symlinked to user-writable files. `etc/` mirrors `/etc`;
  preserve metadata exclusions, root ownership, 0644 config modes and 0755 sleep hooks.
- A new config needs its installation mapping as well as its tracked source.
  The documented workflow uses `add-<name>-config` branches, then commit and merge.
  Installation commands change the machine; they are not validation commands.
- Keep `zsh/.zshrc` plugin sources and `zsh/update-plugins.sh` synchronized.
  Shared exports belong in `.zshenv`; interactive directory creation does not.
- Keep Neovim config commits and parent submodule-pointer changes distinct.
  Plugin sync separately rewrites `nvim/lazy-lock.json`; preserve intentional pins.

## Evidence and audits

- Prove a probe can detect something before treating empty output as absence.
  Check permissions, names, glob matches (including dotfiles), and errors.
- State what a probe actually measures. Package ownership, file metadata, content,
  and rendered application behavior answer different questions. Test observable behavior.
- Conflicting numbers remain unresolved if the original query is unavailable;
  a new probe does not by itself disprove the original measurement.
- Audits use `audit-<yyyy-mm>` branches, one evidence-backed commit per finding,
  and a `--no-ff` merge to retain the audit as a unit when committing/merging is in scope.
- Route findings to a fix, `TODO.md` for user action, or `revisit.md` for accepted
  behavior. Record rejected findings and reasons. Keep README rebuild exclusions current.

## Credentials and deliberate system choices

- Never commit tokens, passwords, keys, `git/config.local`, `gh/hosts.yml`, rclone
  credentials, or Podman secrets. Do not print unfiltered `rclone config show` output.
- Keep generated completions, plugin clones, incidental bookmarks and session state
  out of commits. This does not prohibit intentional tracked lockfiles or wordlists.
- Preserve rootless Podman: no `sudo podman` or system `podman.socket`. Manage Quadlet
  lifecycle through `systemctl --user`; read `containers/README.md` before changing it.
- Do not order user services against the system `network-online.target`; preserve
  retries, explicit enable lists, and failure notification behavior.
- Read package decisions before suggesting removals or replacements: AOCL, Rust,
  qpdf, locally built mutool and shellcheck-bin have deliberate roles. Keep Tor Browser
  unconfigured. Do not expose AOCL libraries or pkg-config paths globally.

## Validation

There is no repository-wide build, formatter, or type-check pipeline. Use checks
appropriate to the changed files; report checks not run and limitations.

- Checker regressions: `python3 -B -m unittest discover -s tests -v` runs isolated
  temporary-file fixtures and stubbed tools without changing live configuration.

- Bash: `bash -n <file>` and `shellcheck <file>` for changed Bash scripts.
- Zsh: `zsh -n <file>`; do not apply Bash-only checks to Zsh.
- Skills: `bash bash/check-skills` checks the existing local authoring conventions.
- Audits: `bash bash/config-drift` (or `-v`) checks the live machine without root.
- Units: `systemd-analyze verify <unit>` plus relevant runtime evidence; verification
  alone cannot prove network ordering or successful execution.
- Niri and Neovim: follow their nested instructions. Do not run installers, `sysup`,
  or plugin upgrades just to validate unrelated edits. Do not reformat unrelated files.

## Reusable procedures

When the task matches, read `skills/<name>/SKILL.md` and its selected references:
`diagnose-boot-or-suspend`, `systemd-user-units`, `local-postgres`, `python-venv`,
`papers-and-pdfs`, or `screenshot`. These are machine procedures, useful outside
this repository too. This explicit routing works without changing skill installation.
See `docs/codex-migration.md` for discovery, permissions, and compatibility limitations.
