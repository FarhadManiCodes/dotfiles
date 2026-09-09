# CLAUDE.md

Guidance for Claude Code when working on the Niri configuration. The Niri guardrails are
shared with Codex and live in one file, imported here so there is only ever one copy:

@AGENTS.md

Repository-wide guardrails are in the root `AGENTS.md`, loaded via the root `CLAUDE.md`
when the session starts at the repository root. A session started inside `niri/` does not
load them — read `../AGENTS.md` in that case; a cross-directory `@` import does not expand.

Detailed reference, read on demand: `README.md` in this directory for the configuration
map, keybindings, paths and operational details.
