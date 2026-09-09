---
name: papers-and-pdfs
description: >
  Work with PDFs on this machine, whether academic papers or not. Use when adding a paper to
  papis, indexing or asking questions across the library with pask or papis-ask, running
  refinery on a PDF, converting a PDF or scanned book to markdown or plain text, extracting
  text from a PDF, typesetting a parsed document, or when chunks.json, citations.json or a
  .refinery work directory is involved. Covers which entry point to use, what is automatic,
  what costs API calls, and the traps that fail silently.
---

# Papers and PDFs

Two tools, four entry points, and the only decision that really matters is **which one**.
Choosing wrong is what costs you: running `refinery` on a textbook burns Gemini figure calls and
citation HTTP for output you did not want, and needs API keys, where `refinery-typeset` needs
neither.

## Pick the entry point first

| What you want | Command | Network / keys |
|---|---|---|
| A paper in the library, searchable | `papis add …`, then `pask index` | Gemini + CrossRef/S2/OpenAlex |
| An answer from the library | `pask "your question"` | Gemini |
| **A general PDF as markdown** | `refinery-typeset <pdf>`, then read `<pdf-stem>.refinery/parsed.md` | **none** |
| A clean reading copy of a scan | `refinery-typeset <pdf>` → `<stem>.typeset.pdf` | **none** |
| A paper as enriched markdown | `refinery <pdf>` → `<stem>.refinery/refinery.md` | Gemini + providers |

`refinery-typeset` runs parse only — no figure-description stage, no citation verification, and
no network calls at all unless `--clean-toc` is passed. It is the right tool for anything that is
not a paper you want in the library, and it is the one people reach past because `refinery` has
the more obvious name.

**`parsed.md` is raw OCR markdown. `refinery.md` is the enriched version** — figure descriptions
spliced in after captions, `[surname_year]` citekeys rewritten. Only `refinery` produces the
second. A work directory holding `parsed.md` but no `refinery.md` was a typeset/parse run, not a
full refine.

Details for the library path are in `references/ingest.md`; for everything else,
`references/convert.md`. Read the matching one before running anything expensive.

## Do not run refinery by hand before indexing

`pask index` **already refines**. It looks for every matching PDF whose `chunks.json` is missing
or older than the PDF and runs `refinery` (or `refinery-batch` for several) before handing off to
`papis ask index`. Running `refinery` first is redundant, and running it *after* is worse — it
rewrites chunks the index has already read.

`--no-refine` or `--raw` suppresses that step. Nothing else does.

## What has to be in place

Two different secret locations, and they are not interchangeable:

| Tool | Reads |
|---|---|
| `pask` | `~/.config/secrets/papis.env` — sourced in a subshell, so it never leaks into your shell |
| `refinery` | `~/.config/paper-refinery/secrets/{google,hf,zai}.env` |

Those keys exist **only on this disk and are in no backup**; losing them means re-issuing all
three. Never print them, and never add `~/.config/paper-refinery/` to a public repo — the config
sits beside the secrets, which is why it is deliberately untracked.

Check presence without reading contents:

```bash
for f in ~/.config/secrets/papis.env ~/.config/paper-refinery/secrets/{google,hf,zai}.env; do
  printf '%-52s %s\n' "${f/#$HOME/~}" "$([ -f "$f" ] && echo present || echo MISSING)"
done
```

## The trap: `refinery` on PATH is a snapshot, not the source

There are two installs, and they are not the same thing:

```bash
command -v refinery       # ~/.local/bin/refinery -> ~/.local/share/uv/tools/paper-refinery/...
```

The one on `PATH` — the one `pask index` runs — is a **uv tool installed from the project
directory with `editable: false`**. Editing `~/projects/paper-refinery` does **not** change what
runs until it is reinstalled:

```bash
uv tool install --force --from ~/projects/paper-refinery paper-refinery
```

Nothing announces the divergence. `uv tool list` reports the version from `pyproject.toml`, which
is not bumped per commit, so a stale tool and a current one look identical. Verified 2026-09-06:
`direct_url.json` says `"editable": false`, and the installed copy happened to match the source
that day only because the tool was reinstalled four minutes after the last commit.

To check rather than assume:

```bash
diff -rq ~/.local/share/uv/tools/paper-refinery/lib/python*/site-packages/paper_refinery \
         ~/projects/paper-refinery/paper_refinery
```

`papis` itself is also a uv tool, installed from PyPI, and is not affected by this.

## OCR is the expensive stage, and it is checkpointed

A full parse is roughly ten minutes. Both `refinery` and `refinery-typeset` write a checkpoint to
`<stem>.refinery/parse_cache/`, keyed on the PDF hash and the parse config, and reuse it on a
re-run. `--force-parse` bypasses it — pass that only when the OCR output itself is what you are
trying to change, never as a general "start clean".
