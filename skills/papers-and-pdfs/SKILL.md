---
name: papers-and-pdfs
description: >
  Work with PDFs on this machine, whether academic papers or not. Use when adding a paper to
  papis, indexing or asking questions across the library with pask or papis-ask, running
  refinery on a PDF, re-refining documents to improve citations or chunks, converting a PDF or
  scanned book to markdown or plain text, extracting text from a PDF, typesetting a parsed
  document, or when chunks.json, citations.json, resolution_report.txt or a .refinery work
  directory is involved. Covers which entry point to use, what is automatic, what costs API
  calls, and the traps that fail silently.
---

# Papers and PDFs

Two tools do the work: **papis** with the papis-ask plugin (the library, the index, the
answers), and **paper-refinery** (PDF to enriched markdown and chunks). The decision that matters
is **which entry point**. Choosing wrong is what costs you: running `refinery` on a textbook pays
for Gemini figure descriptions and citation lookups you did not want, where `refinery-typeset`
only runs OCR.

## Pick the entry point first

| What you want | Command | Network / keys |
|---|---|---|
| A paper in the library, searchable | `papis add …`, then index it (see below) | Gemini + CrossRef/S2/OpenAlex |
| An answer from the library | `pask "your question"` | Gemini |
| An answer from part of it | `pask -s "tags:control-theory" "your question"` | Gemini |
| **A general PDF as markdown** | `refinery-typeset <pdf>`, then read `<pdf-stem>.refinery/parsed.md` | OCR backend only |
| A clean reading copy of a scan | `refinery-typeset <pdf>` → `<stem>.typeset.pdf` | OCR backend only |
| A paper as enriched markdown | `refinery <pdf>` → `<stem>.refinery/refinery.md` | Gemini + providers |

"OCR backend only" means no Gemini and no citation lookups. The default `maas` OCR mode still
needs `ZHIPU_API_KEY` and network access; `selfhosted` mode runs locally; markdown input skips
OCR and needs neither. `refinery-typeset --clean-toc` adds Gemini calls. `refinery-typeset` is
the right tool for anything that is not a paper you want in the library, and the one people
reach past because `refinery` has the more obvious name.

**`parsed.md` is raw OCR markdown. `refinery.md` is the enriched version**: figure descriptions
spliced in after captions, `[surname_year]` citekeys rewritten. Only `refinery` produces the
second. A work directory holding `parsed.md` but no `refinery.md` was a typeset/parse run.

Figure descriptions are anchored on "FIGURE N" captions, so an image without a numbered caption
is never described. For a visual book (canvases, worksheets), `--describe-uncaptioned` describes
those too, at one call per image with the configured figure model (cached).

Read the matching reference before running anything expensive:

- `references/ingest.md`: adding, indexing, asking, notes, citation quality, re-refining in bulk.
- `references/convert.md`: PDFs that are not library papers, typesetting, re-chunking.

## Do not run refinery by hand before indexing

`pask index` **already refines**. It runs `refinery` (or `refinery-batch` for several) on every
matching PDF whose `chunks.json` is missing or older than the PDF, then hands off to
`papis ask index`. Running `refinery` first is redundant; running it *after* rewrites chunks the
index has already read. `--no-refine` or `--raw` suppresses the refining, and nothing else
does, but **it also reaches `papis ask index`**, where it means "ignore `chunks.json`, use pypdf":
everything that run embeds is chunked badly and paid for. Do not use it to skip refining.

**The query scopes the refining, not the indexing.** Without `-f`, `pask index "q"` refines only
what matches `q` and then runs an *unscoped* `papis ask index`, which embeds every PDF in the
library that is not indexed yet, through plain pypdf chunking if it has no `chunks.json`. With
unrefined books in the library that is hundreds of pages embedded badly, then paid for again once
they are refined. To index a subset only, refine it first (`refinery-batch` on its PDFs), then
call papis directly with the keys sourced, since `papis ask index` does not refine:

```bash
( source ~/.config/secrets/papis.env; papis ask index "ref:^Kalman_1960$" )
```

`pask index -f "q"` is scoped too, but `-f` re-embeds every match, which costs money. Plain
`pask index` with no query is fine for embedding "everything that needs it", but its automatic
refine runs `refinery-batch` at the default 4 workers, which loses citations to provider rate
limits. When citation quality matters, refine new PDFs with `--workers 1` first.

Scoped runs still drop deleted documents from the index: the existence check always covers the
whole library.

## What has to be in place

Two different secret locations, and they are not interchangeable:

| Tool | Reads |
|---|---|
| `pask` | `~/.config/secrets/papis.env`, sourced in a subshell so it never leaks into your shell |
| `refinery` | every `~/.config/paper-refinery/secrets/*.env`: `google`, `hf`, `zai`, `openalex` (`OPENALEX_API_KEY`), `contact` (`REFINERY_MAILTO`), optionally `s2` (`S2_API_KEY`) |

Those keys exist **only on this disk and are in no backup**; losing them means re-issuing them.
Never print or read them, and never add `~/.config/paper-refinery/` to a public repo: the config
sits beside the secrets, which is why it is deliberately untracked.

Check presence without reading contents:

```bash
for f in ~/.config/secrets/papis.env ~/.config/paper-refinery/secrets/{google,hf,zai,openalex,contact}.env; do
  printf '%-52s %s\n' "${f/#$HOME/~}" "$([ -f "$f" ] && echo present || echo MISSING)"
done
```

Models are pinned by exact name in refinery's `config.toml` and the papis config, never
`-latest` aliases, with the evidence for each choice in a comment. Before changing one, compare
on the library: `scripts/eval_models.py check|extraction|figures` in paper-refinery, and
`contrib/eval_questions.py` in papis-ask. Never change `ask.embedding` casually: it forces a
full re-embed.

## The trap: `refinery` on PATH is a snapshot, not the source

The `refinery` on `PATH`, the one `pask index` runs, is a **uv tool installed from
`~/projects/paper-refinery` with `editable: false`**. Editing the project does **not** change
what runs until it is reinstalled:

```bash
uv tool install --force --from ~/projects/paper-refinery paper-refinery
```

Nothing announces the divergence: `uv tool list` shows the `pyproject.toml` version, which is
bumped per release, not per commit. Check rather than assume:

```bash
diff -rq ~/.local/share/uv/tools/paper-refinery/lib/python*/site-packages/paper_refinery \
         ~/projects/paper-refinery/paper_refinery
```

Reinstall only when no refinery process is running (`ps -eo args | grep -c "[b]in/refinery"`
prints 0): a batch in progress would pick up a mix of old and new modules. `papis` is also a uv
tool, but papis-ask is an editable dependency of it, so papis-ask edits are live at once.

## OCR is the expensive stage, and it is checkpointed

A full parse is roughly ten minutes. Both `refinery` and `refinery-typeset` write a checkpoint to
`<stem>.refinery/parse_cache/`, keyed on the PDF hash and the parse config, and reuse it on a
re-run. `--force-parse` bypasses it: pass that only when the OCR output itself is what you are
trying to change, never as a general "start clean".

Books over 100 pages are split, and each part checkpoints under `<stem>.refinery/parts/part_N/`,
keyed on the *original* PDF's hash, so the checkpoint survives being copied. Before OCR-ing a book
that a study project already converted, check for its `parts/`; see `references/ingest.md`.
