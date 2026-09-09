# Getting a paper into the library and asking questions of it

Read after choosing the library path in `SKILL.md`.

## Adding

The library is `~/.local/share/papis/papers` (`papis config dir` confirms it).

Two ways in, and they are for different situations:

- **From the browser** — Tridactyl `,p`, which calls `bash/papis-add-paper <importer> <id>` with
  `doi` or `arxiv`. It is launched from Firefox with no terminal, so it opens a small floating
  footclient to confirm the title and let you edit a pre-filled reference key and tags. **An
  empty key cancels.** `arxiv` also downloads the PDF; `doi` does not always.
- **From a file you already have** — `papis add --set …` directly.

**Reference keys are kept unique deliberately.** papis itself permits duplicates, but
`papis.nvim`'s sqlite cache enforces `UNIQUE(ref)`, so a clash silently breaks the nvim side.
`papis-add-paper` auto-disambiguates its suggestion and re-prompts on a typed clash — do not work
around that by forcing a duplicate.

## Indexing

```bash
pask index                       # everything that needs it
pask index "author:kalman"       # one query
pask index -f "author:kalman"    # force re-index of matches
```

`pask index` refines first, automatically. A PDF is refined when its `chunks.json` is missing or
older than the PDF itself — that mtime comparison is the whole staleness rule, so **touching a
PDF marks it for re-refining** and editing `chunks.json` by hand does not.

One PDF goes through `refinery`; several go through `refinery-batch`, which gates cloud OCR to
`--ocr-workers` because z.ai rate-limits concurrent OCR while running the network stages wider at
`--workers`. A paper that fails is logged and skipped, so **the final count can be lower than the
number of PDFs given** — check the count, do not assume completion.

**papis' query language has no OR.** `docmatcher.py` ANDs every space-separated term together,
and `papis ask index` takes exactly one query argument, so "paper A or paper B" cannot be
expressed in a single papis call. `pask index` accepts several query strings and loops instead —
that is why it takes multiple arguments where papis takes one.

Two things about `papis list` worth having straight, both re-measured on papis 0.16.0 on
2026-09-06:

- **`--all` is the flag that matters.** `papis list` without it returns nothing at all; with it
  you get the whole library. `-f` is `--file` (a boolean, "show the files"), not a format
  argument — the query is positional.
- An empty query is **not** special. `papis list --all -f ""` and `papis list --all -f` both
  return every document. A comment in `zsh/functions/papis.zsh` claimed the empty form matched
  zero; it does not on 0.16.0, and that comment has been corrected.

## Asking

```bash
pask "what does this library say about observability gramians"
```

Anything that is not `index` passes straight through to `papis ask`, with
`~/.config/secrets/papis.env` sourced in a subshell.

Embeddings come from papis' configured backend (`ask.embedding`, currently a Gemini model), not
from a local llama.cpp server — that moved off local on 2026-07-08. If answers look like they are
missing a paper you know is there, the question is almost always *was it indexed*, not *is the
retrieval wrong*: re-run `pask index` for that paper and compare.

## Feeding papis metadata back into refinery

`refinery-export-citations` turns resolved references into papis `citations:` YAML.
`refinery-batch --meta-map FILE` goes the other way, feeding known doi/title/year/authors into
source identification so refinery can take the S2 bulk-references fast path — one call for the
whole bibliography instead of a per-reference search. It is optional complementary data; without
it refinery falls back to the OCR'd title.
