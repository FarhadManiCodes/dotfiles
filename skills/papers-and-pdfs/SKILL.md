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

**papis** manages the library, index and answers; **paper-refinery** converts PDFs. Use the
entry point that fits the job: `refinery` runs figure descriptions and citation lookups,
while `refinery-typeset` only runs OCR.

## Pick the entry point first

| What you want | Command | Network / keys |
|---|---|---|
| A paper in the library, searchable | `papis add …`, then index it (see below) | Gemini + CrossRef/S2/OpenAlex |
| An answer from the library | `pask "your question"` | Gemini |
| An answer from part of it | `pask -s "tags:control-theory" "your question"` | Gemini |
| Inspect an existing PDF | `pdf-meta preview <pdf>` | None; embedded metadata and first-page text only |
| Find a library file or search its refined text | `fbook` or `rgbook "query"` | None |
| **A general PDF as markdown** | `refinery-typeset <pdf>`, then read `<pdf-stem>.refinery/parsed.md` | OCR backend only |
| A clean reading copy of a scan | `refinery-typeset <pdf>` → `<stem>.typeset.pdf` | OCR backend only |
| A paper as enriched markdown | `refinery <pdf>` → sibling `<stem>.md` for review | OCR backend + Gemini + providers |

"OCR backend only" excludes Gemini and citation lookups. Default `maas` needs
`ZHIPU_API_KEY` and network; `selfhosted` runs locally. Markdown input skips OCR.
`refinery-typeset --clean-toc` adds Gemini calls.

For PDF input, `refinery-typeset` writes OCR to `<stem>.refinery/parsed.md`. A full
`refinery` run writes enriched `<stem>.refinery/refinery.md` for chunking and a sibling
`<stem>.md` review copy with math collapsed. `rgbook` searches the sibling, excluding
`notes.md`; its markers identify one-based physical PDF pages. `--from chunk` does not
refresh the review copy.

`fbook` finds library files by name. `pdf-meta preview FILE` shows embedded title, author,
page count and first-page text without papis metadata or OCR.

Figures without "FIGURE N" captions need `--describe-uncaptioned` to be described;
that makes one cached figure-model call per image.

Read the matching reference before running anything expensive:

- `references/ingest.md`: adding, indexing, asking, notes, citation quality, re-refining in bulk.
- `references/convert.md`: PDFs that are not library papers, typesetting, re-chunking.

## Indexing scope

`pask index` refines PDFs with missing or older `chunks.json`, then calls `papis ask index`.
`--no-refine` and `--raw` also reach papis-ask, where they bypass `chunks.json` and embed
raw pypdf text; do not use them to skip refining.

`pask index "q"` scopes refining but indexes the whole library, including any still-unrefined
PDFs. To index a subset, refine its PDFs first, then call papis directly with the keys sourced:

```bash
( source ~/.config/secrets/papis.env; papis ask index "ref:^Kalman_1960$" )
```

`pask index -f "q"` is scoped but re-embeds every match. For good citations in a batch,
refine with `--workers 1` before indexing; automatic batches use 4 workers and can hit
provider rate limits. See `references/ingest.md` for the indexing details.

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

## Installed refinery

`refinery` on `PATH` is a non-editable uv tool snapshot of `~/projects/paper-refinery`.
Source edits do not change it; compare before assuming they are installed:

```bash
diff -rq ~/.local/share/uv/tools/paper-refinery/lib/python*/site-packages/paper_refinery \
         ~/projects/paper-refinery/paper_refinery
```

Reinstall only when no refinery process is running:

```bash
uv tool install --force --from ~/projects/paper-refinery paper-refinery
```

`papis` is also a uv tool, but its papis-ask dependency is editable.

## OCR is the expensive stage, and it is checkpointed

Both `refinery` and `refinery-typeset` cache OCR under `<stem>.refinery/parse_cache/` by PDF
hash and parse config. Use `--force-parse` only to change OCR output. Books over 100 pages
also cache split parts under `parts/part_N/`, keyed on the original PDF hash; check for
existing study-project parts before OCR-ing again (see `references/ingest.md`).
