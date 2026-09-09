# Claude Code → Codex migration

Implemented on 2026-09-06 as an instructions-and-documentation migration. No
application configuration, helper code, installers, user settings, or Claude
configuration is changed. Existing uncommitted Neovim work is preserved.

## Instruction ownership

| Source retained for Claude | Codex instructions | Detailed reference |
| --- | --- | --- |
| `CLAUDE.md` | `AGENTS.md` | `docs/architecture.md`, `docs/system-notes.md` |
| `niri/CLAUDE.md` | `niri/AGENTS.md` | `niri/README.md` |
| `nvim/CLAUDE.md` | `nvim/AGENTS.md` | `nvim/docs/architecture.md` |

Paths in this table are relative to the dotfiles root. Nested instructions exist
only for the different KDL and Neovim rules. Other applications use root guidance
and their existing documentation. Read the relevant detailed section before edits:
the short instruction files do not replace the operational constraints it contains.

Detailed sections were extracted without dropping their original content, which
deliberately introduced temporary duplication pending a scoped cleanup.

**That cleanup was done on 2026-09-09 for the root and `niri/` files.** It was safe
because the duplication turned out to be total: normalising whitespace and comparing
sorted unique lines, `CLAUDE.md` (995 lines) held exactly 2 lines absent from
`docs/architecture.md` + `docs/system-notes.md`, and `niri/CLAUDE.md` (159) exactly 2
absent from `niri/AGENTS.md` + `niri/README.md` — each file's own title and subtitle.
Both are now thin entry points whose body is an `@AGENTS.md` import, so the guardrails
have one copy and cannot drift. `AGENTS.md` was tightened from 90 to 67 lines in the
same pass, since it became the file loaded into every session.

`nvim/CLAUDE.md` (645 lines, likewise a total duplicate of `nvim/AGENTS.md` +
`nvim/README.md` + `nvim/docs/architecture.md`) is **still outstanding** — it lives in a
separate repository. Until it is done, keep its guidance synchronized. Historical command
examples are documentation, not authorization to run them.

The root file explicitly routes work to nested instructions. Codex's startup
discovery follows the root-to-working-directory chain; do not assume a session
launched at the root has automatically loaded every child instruction file.
Keep these files concise rather than copying the large references into them.
See the [official AGENTS.md documentation](https://learn.chatgpt.com/docs/agent-configuration/agents-md).

## Skills

The six existing `skills/<name>/SKILL.md` procedures remain unchanged. Root
instructions route matching tasks to them explicitly, so they are usable in this
repository without editing the installer or assuming automatic discovery.

Automatic user-wide discovery is a separate setup step: symlink each directory
into `~/.agents/skills/<name>`. Preserve user scope, because these machine procedures
are useful outside dotfiles. Keep existing `~/.claude/skills` links while Claude
remains installed; avoid duplicate repo/user registrations with the same name.
Codex supports symlinked skill directories at that user location. See
[official skill discovery documentation](https://learn.chatgpt.com/docs/build-skills).

That setup would also require extending `install.sh` and `bash/config-drift` to
install and monitor the extra location. They are intentionally unchanged here.
`bash/check-skills` validates existing authoring conventions, including some
Claude-oriented restrictions; it is not a Codex loader compatibility test.

## Settings and mappings that are not exact

- The four `.claude/settings.local.json` files contain local permission allowlists.
  Their `Read`, `Bash`, and `WebFetch` patterns are not Codex configuration syntax.
  No historical approvals were imported or treated as ongoing task authorization.
- Personal model, approval, sandbox, search, and trust choices belong in the
  existing `~/.codex/config.toml`, merged with its current contents. Selected
  command permissions may become reviewed `~/.codex/rules/*.rules` prefix rules.
  No global settings or command permissions are changed by this migration.
- `.claudeignore` remains. No documented drop-in Codex ignore-file mapping was
  established. Git exclusions and instructions to avoid secrets do not enforce
  read-access isolation; actual access is governed by the active permission policy.
- No repository Claude commands, hooks, custom agents, or MCP configuration were
  found to convert. Codex supports hooks, but none are needed for this migration.
- `claude update` and old-version pruning in `sysup.zsh` remain Claude-specific.
  Codex update handling depends on how it is installed and is not substituted here.
- Branch/commit/merge instructions retain their workflow intent, conditional on
  the task authorizing those operations. A reference to a maintenance command is
  not an instruction to run it during every edit.
- Niri's retained reference includes reload and quit commands. The agent guidance
  requires checking the installed CLI and treats quitting as ending the session,
  rather than routine validation. Older Basedpyright per-venv examples remain as
  historical text; nested guidance preserves the newer uv-tool installation rule.

See the official [configuration reference](https://learn.chatgpt.com/docs/config-file/config-reference)
and [execution rules](https://learn.chatgpt.com/docs/agent-configuration/rules).

## Reviewing this change

Neovim is a separate Git repository. Review its new instructions and reference
inside `nvim/`; the parent repository cannot represent their content as an ordinary
file diff. Commit them there and update the parent pointer only when requested.

Validation for this documentation-only migration checks extracted-content
preservation, local Markdown link targets, instruction-file sizes, whitespace,
and that pre-existing files remain unchanged. It does not run application tests,
plugin synchronization, system audits, or installers.
