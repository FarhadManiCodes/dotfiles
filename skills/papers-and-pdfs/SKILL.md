---
name: papers-and-pdfs
description: >
  Work with PDFs on this machine, whether academic papers or not. Use when adding a paper to
  papis, indexing or asking questions across the library with pask or papis-ask, running
  refinery on a PDF, re-refining documents to improve citations or chunks, converting a PDF or
  scanned book to markdown or plain text, extracting text from a PDF, reading or rendering pages
  of a PDF (the Read tool's PDF mode needs poppler, which is missing: use mutool), typesetting a parsed
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
| **Read some pages of any PDF now** (text or as images), no OCR | `mutool` (see "Quick look: mutool" below) | None |
| Find a library file or search its refined text | `fbook` or `rgbook "query"` | None |
| **A general PDF as markdown** | `refinery-typeset <pdf>`, then read `<pdf-stem>.refinery/parsed.md` | OCR backend only |
| A clean reading copy of a scan | `refinery-typeset <pdf>` → `<stem>.typeset.pdf` | OCR backend only |
| A paper as enriched markdown | `refinery <pdf>` → sibling `<stem>.md` for review | OCR backend + Gemini + providers |
| The review copy only, from an existing `refinery.md` (imported or hand-corrected books) | `refinery --from review <pdf>` | None |

"OCR backend only" excludes Gemini and citation lookups. Default `maas` needs
`ZHIPU_API_KEY` and network; `selfhosted` runs locally. Markdown input skips OCR.
`refinery-typeset --clean-toc` adds Gemini calls.

For PDF input, `refinery-typeset` writes OCR to `<stem>.refinery/parsed.md`. A full
`refinery` run writes enriched `<stem>.refinery/refinery.md` for chunking and a sibling
`<stem>.md` review copy with math collapsed. `rgbook` searches the sibling, excluding
`notes.md`; its markers identify one-based physical PDF pages. `--from chunk` does not
refresh the review copy; `refinery --from review <pdf>` (also `refinery-batch --from review`;
since refinery 0.3.16) writes only that copy from an existing `refinery.md`, with no keys,
network or OCR, and never touches `refinery.md`. It is the way to give an imported or hand-corrected book a
review copy: a full `refinery` run on one would replace the corrected `refinery.md` and pay
for OCR again.

`fbook` finds library files by name. `pdf-meta preview FILE` shows embedded title, author,
page count and first-page text without papis metadata or OCR.

Figures without "FIGURE N" captions need `--describe-uncaptioned` to be described;
that makes one cached figure-model call per image.

Read the matching reference before running anything expensive:

- `references/ingest.md`: adding, indexing, asking, notes, citation quality, re-refining in bulk.
- `references/convert.md`: PDFs that are not library papers, typesetting, re-chunking.

## Quick look: mutool (no OCR, no network, no keys)

The Read tool's PDF mode (`pages: "1-5"`) shells out to `pdftoppm`, which is in **poppler**.
poppler is not installed here, so Read on a PDF fails with "pdftoppm is not installed". Use
**mupdf's `mutool`** (`~/.local/bin/mutool`, 1.26) instead. Verified on a text PDF:

```bash
mutool info doc.pdf 2>/dev/null | head                  # page count, producer, PDF version
mutool draw -q -F txt -o - doc.pdf 1-3 2>/dev/null       # text of pages 1-3 to stdout
mutool draw -q -F txt -o out.txt doc.pdf 1-20 2>/dev/null   # whole range into a file, then read that file
mutool draw -q -r 80 -o /tmp/p%d.png doc.pdf 1-2 2>/dev/null   # PNG per page; %d = page number
mutool draw -q -F stext.json -o - doc.pdf 1 2>/dev/null   # text with positions (JSON), for tables or columns
```

Then **Read the PNG** (the Read tool shows images) when layout matters: two-column CVs, tables,
figures, forms. Use `-r 80` to `-r 100` for a readable page that stays small; higher `-r` makes
large images. Text extraction (`-F txt`) keeps accents; icon fonts show up as private-use
characters or garbage, which is harmless.

- `warning: bogus font ascent/descent values` on stderr is noise; `2>/dev/null` hides it.
- Page ranges are 1-based and accept `1-3,7,10-N`. Without a range mutool renders every page.
- `mutool` reads the embedded text layer only. A scan has none (empty output): use
  `refinery-typeset <pdf>` (OCR) for scans, books and anything you will cite from.
- Put outputs in the scratchpad, not next to the PDF; for a library paper use the refinery
  entry points above, not mutool, so the result is cached and searchable.
- Fallback when mutool is missing: `uv run --no-project --with pypdf python` and
  `PdfReader(path).pages[i].extract_text()` (text only, no images, no page rendering).

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

`--from review` exists only in a snapshot of 0.3.16 or newer: if `refinery --help` does not list
`review` under `--from`, the installed tool is older than the source, so compare and reinstall
as above. `uv tool list` shows the installed version.

`papis` is also a uv tool, but its papis-ask dependency is editable.

## OCR is the expensive stage, and it is checkpointed

Both `refinery` and `refinery-typeset` cache OCR under `<stem>.refinery/parse_cache/` by PDF
hash and parse config. Use `--force-parse` only to change OCR output. Books over 100 pages
also cache split parts under `parts/part_N/`, keyed on the original PDF hash; check for
existing study-project parts before OCR-ing again (see `references/ingest.md`).
