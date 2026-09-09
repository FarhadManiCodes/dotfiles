# Dotfiles agent instructions

Personal Arch Linux + Niri/Wayland configuration for data engineering and scientific
computing. `CLAUDE.md` imports this file, so this is the single source of agent guardrails.
Read `README.md` for the directory map, an application's section in `docs/architecture.md`
before changing it, and `docs/system-notes.md`, `TODO.md` and `revisit.md` before package,
system or audit work — those hold operational constraints, not background. Do not reopen
accepted findings without new evidence; TODO items need the user. Read `niri/AGENTS.md`
before editing Niri and `nvim/AGENTS.md` before Neovim, a separate submodule, including
when working from the repository root.

## Live configuration and installation

- Live configuration is the source of truth. Tracked configs symlink into this checkout, so
  editing the target already changes the live file: confirm with `ls -la` or `readlink`
  before copying back, and do not overwrite independent live changes.
- Switching branches changes live configuration and can leave dangling links. Preserve
  existing work and inspect affected links when switching.
- `install.sh` installs user configs without sudo; `install-root.sh` copies root files
  rather than symlinking them to user-writable paths — preserve `etc/` ownership and modes.
  A new config needs its installation mapping as well as its tracked source, on an
  `add-<name>-config` branch. Installation commands change the machine; they are not tests.
- Keep `zsh/.zshrc` plugin sources and `zsh/update-plugins.sh` synchronized. Shared exports
  belong in `.zshenv`; interactive directory creation does not.

## Evidence and audits

- Prove a probe can detect something before treating empty output as absence: check
  permissions, names, glob matches including dotfiles, and errors.
- State what a probe actually measures. Package ownership, file metadata, content and
  rendered behavior answer different questions. Assert on observable behavior.
- Conflicting numbers remain unresolved when the original query is unavailable; a new probe
  does not by itself disprove the original measurement.
- Audits use `audit-<yyyy-mm>` branches, one evidence-backed commit per finding, and a
  `--no-ff` merge. Route every finding to a fix, `TODO.md` for user action, or `revisit.md`
  for accepted behavior — rejected ones too, with the reason.

## Credentials and deliberate system choices

- Never commit tokens, passwords, keys, `git/config.local`, `gh/hosts.yml`, rclone
  credentials or Podman secrets, and never print unfiltered `rclone config show` output.
  Keep generated completions, plugin clones, bookmarks and session state out of commits.
- Preserve rootless Podman: no `sudo podman`, no system `podman.socket`, Quadlet lifecycle
  through `systemctl --user`. Read `containers/README.md` before changing it.
- Do not order user services against the system `network-online.target`; preserve retries,
  explicit enable lists and failure notification behavior.
- AOCL, Rust, qpdf, the locally built mutool and `shellcheck-bin` have deliberate roles —
  read the package notes before suggesting a removal. Keep Tor Browser unconfigured. Do not
  expose AOCL libraries or pkg-config paths globally.

## Validation

No repository-wide pipeline exists. Use checks appropriate to the changed files, and report
checks not run and their limitations.

- `python3 -B -m unittest discover -s tests` for the checkers; `bash -n` and `shellcheck`
  for Bash; `zsh -n` for Zsh, never Bash-only checks; `bash bash/check-skills` for skills;
  `bash bash/config-drift` (or `-v`) to audit the live machine, read-only and no root.
- Units: `systemd-analyze verify <unit>` plus runtime evidence; verification alone cannot
  prove network ordering or successful execution.
- Do not run installers, `sysup` or plugin upgrades to validate unrelated edits, and do not
  reformat unrelated files. Niri and Neovim follow their nested instructions.

## Reusable procedures

Read the matching `skills/<name>/SKILL.md`: `diagnose-boot-or-suspend`, `systemd-user-units`,
`local-postgres`, `python-venv`, `papers-and-pdfs`, `screenshot`.
