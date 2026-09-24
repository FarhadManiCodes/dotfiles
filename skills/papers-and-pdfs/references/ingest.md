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

`papis add FILE` **copies** the file into the library; the original stays where it was.

**A failed importer still adds a document in `--batch` mode**, with no metadata at all: a
`papis_id`-named folder, a timestamp `ref`, nothing else. Seen 2026-09-23 when arXiv briefly
answered the `arxiv` library with HTTP 406 after a burst of PDF downloads from the same IP; it
worked again minutes later with no change. For bulk adds, fetch metadata yourself (the arXiv
Atom API with plain curl works) and add with `papis add --batch --from yaml meta.yaml file.pdf`.
papis rewrites `ref` from `ref-format` even when the YAML sets one, and normalises hyphens
(`Ruiz-Balet` becomes `Ruiz_Balet`), so check refs for duplicates afterwards.

**`key:value` values are unanchored, case-insensitive regexes** (`docmatcher.get_regex_from_search`).
So `ref:Li_2026` also matches `Ali_2026`, and `tags:control` also matches `agent-control`. Use
`ref:^Li_2026$` for an exact ref. Anchors do not work on list fields such as `tags`:
`tags:^cpp$` matches nothing (checked 2026-09-23). Keep tag names from being substrings of each
other. The library's tags on 2026-09-23: `book`/`paper` plus `control-theory`, `optimization`, `sciml`, `data-systems`,
`fifth-paradigm`, `agent-control`, `llm-steering`, `agent-safety`, `cpp`, `business`.

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

**Embedding a large batch can hit Gemini's rate limit.** On 2026-09-23 about 600 chunks in one
run ended in `429 RESOURCE_EXHAUSTED` after LiteLLM's three retries, and `papis ask index` exited
with a traceback. Work done before the error was saved, and a re-run embeds only what is still
missing. For a big backlog, index one reference at a time (`papis ask index "ref:^X$"`) with a
pause between runs. Semantic Scholar 429s during indexing are different: they only skip optional
metadata enrichment for that paper and do not stop the run.

**Queries support `AND`, `OR`, `NOT` and parentheses** (papis 0.16, `docmatcher._QUERY_GRAMMAR`).
Space-separated terms are ANDed. `tags:llm-steering OR tags:agent-safety` returns 18 documents,
the same as the regex `tags:llm-steering|agent-safety`, and `tags:book AND NOT tags:cpp` works
too (checked 2026-09-24). `pask index` also accepts several query strings and loops over them,
but a single `OR` query does the same job.

Two things about `papis list` worth having straight, both re-measured on papis 0.16.0 on
2026-09-06:

- **`--all` is the flag that matters.** `papis list` without it returns nothing at all; with it
  you get the whole library. `-f` is `--file` (a boolean, "show the files"), not a format
  argument — the query is positional.
- An empty query is **not** special. `papis list --all -f ""` and `papis list --all -f` both
  return every document. A comment in `zsh/functions/papis.zsh` claimed the empty form matched
  zero; it does not on 0.16.0, and that comment has been corrected.

## Books a study project already converted

Study projects (`~/projects/cpp-study`, `DDIA_study`, `DataEngineering_study`) hold refinery OCR
of books that are also in the library. Two ways to avoid paying for it again:

**Copy the OCR checkpoint** when the project kept its work directory, as `cpp-study` does under
`books/<slug>/work/refinery/parts/`. Copy that `parts/` into `<library-pdf-stem>.refinery/` and
run `refinery` normally. Every part hits, provided the two PDFs are byte-identical: the key is
the original PDF's sha256 plus the part index and `max_pages_per_part`, and the parse config and
checkpoint version must match too. A project converted with a different OCR backend or parse
config misses without any message and pays for full OCR. Compare `sha256sum`s first, and check
with `parse_cache.load_checkpoint` for a dry run that costs nothing. Done on
2026-09-23 for Gottschling (6 parts) and Meyers (4 parts): no OCR, and the log shows the split
then `done` within seconds.

**Import the markdown** when only the conversion survived. Write a `refinery.md` into the
library PDF's `<stem>.refinery/` and run `refinery --from chunk <pdf>` (see `convert.md`). The
chunker reads `<page_number>N</page_number>` markers, which must be **PDF page numbers**, so
check what the markers mean before trusting them. The 2026-09-23 imports met all three cases:

| Source | Markers | Fix |
|---|---|---|
| DDIA chapters | restart at 1 per chapter | add each chapter's start page from the PDF outline (`get_toc()`) |
| Data Center as a Computer, Fourth Paradigm | printed page numbers | constant offset per chapter or book, found by matching text |
| Fundamentals of Data Engineering | stripped entirely | rebuild by locating each paragraph's opening words in the PDF text layer |

Verify either way. Sample marked pages and compare each one's words with `pymupdf` page text at
offsets −1/0/+1; the right mapping wins at 0 almost every time. Also strip chapter-end
`## References` sections, which otherwise turn into chunks of bibliography, and bare
`![FIGURE_CROP …](…)` lines, which a full run would have replaced with descriptions. Keep the
captions. What you give up compared with a full run is figure descriptions and the citation
stage.

## Asking

```bash
pask "what does this library say about observability gramians"
```

Anything that is not `index` passes straight through to `papis ask`, with
`~/.config/secrets/papis.env` sourced in a subshell.

`-s`/`--scope QUERY` answers from the documents matching a papis query only (added 2026-09-23).
It takes any papis query, and repeating `-s` is the same as joining queries with `OR`:

```bash
pask -s "tags:llm-steering OR tags:agent-safety" "your question"
pask -s "tags:book AND NOT tags:cpp" "your question"
```

Scoping reuses the stored embeddings, so it costs nothing extra. Matching documents that are not
indexed are left out. A blank `-s ""` is rejected, because papis would match everything.

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

## Checking citations after a refine

Before v0.3.1 (2026-09-23), a Gemini response one row short of a 50-line reference batch was
padded at the end, and every later reference took its neighbour's title, which then drove
resolution and the `[surname_year]` rewrite. A `_row_fits` audit of the library's
citations.json files on 2026-09-23 found it in 5 of 41 papers, one of them refined in July. The
old log line was `padding/truncating to align by position`. From v0.3.1, rows are placed by the
line they name (v0.3.2 adds their printed reference number) and checked against the raw text,
and anything unplaceable is left empty. The warnings now read `N line(s) unmatched -- retrying
them once` or `dropped N row(s) that do not fit their line`, and both are benign.

A `_row_fits` misfit that is not part of a run usually means a wrong *resolution*, not a
wrong extraction: `citations.json` stores the provider's title. Before v0.3.3 (2026-09-24), a
title match at >= 0.90 similarity was accepted without looking at authors, so "Compressive
sensing" (Baraniuk, Candès) resolved to Donoho's "Compressed sensing" and AlphaGo Zero to a
Gomoku paper. Measured on 2026-09-24 by re-extracting authors: 43 wrong matches across 14 documents. v0.3.3
rejects a title match when the printed and provider surnames plainly disagree.

**Citation providers need their credentials** (all in refinery's secrets folder, see
`SKILL.md`). OpenAlex has required a free API key since 2026 (observed): keyless requests share a per-IP
daily budget and return `429 "Insufficient budget"` (seen 2026-09-24), so without
`OPENALEX_API_KEY` the third-provider fallback fails without any warning. From v0.3.7 the key is
sent as a bearer header, and a rejected key is logged once. CrossRef
and OpenAlex give a "polite pool" to requests carrying a contact address: `REFINERY_MAILTO` in
`contact.env`, restricted per provider by `[citation] mailto_providers` in `config.toml`. Semantic
Scholar has no polite pool; its key application asked for an academic affiliation (seen
2026-09-24), and keyless worked with more retries (`[citation] api_retry_attempts`, 5 in
`config.toml`; the default is 2). From v0.3.4 a rejected top title hit is followed
by the provider's next hits (`search_candidates`), which recovers generic titles.

Verification rates also depend on how a document was refined. Papers refined in a
4-worker `refinery-batch` on 2026-09-23 verified 12–53% of references, because the free
providers rate-limited the lookups. Re-run alone, one paper went from 40% to 75%. Use
`refinery-batch --workers 1` when citation quality matters more than speed.

**A full re-run replaces `refinery.md`**, and hand edits to it used to be lost silently (a
July math cleanup on kalman-1960 was, on 2026-09-24). From v0.3.6 each run records the file's
checksum; a later full run that finds it edited stops before any paid work, keeps a
`refinery.md.hand-edited-*` copy and points to `refinery --from chunk`, which re-chunks the
edited file. `--overwrite-edits` replaces it anyway; a file from before checksums is copied to
`refinery.md.before-*` and replaced.

To fix a document, re-run `refinery` on its PDF. OCR and figure descriptions both come from
caches, and successful provider lookups are cached too. What runs again is citation
extraction (flash-lite, one call per 50 references, plus a retry for skipped lines). The new `chunks.json` then makes the next
index run re-embed the whole document: for the 49 refined documents on 2026-09-24 that was
~3.7M embedding tokens against ~1M extraction tokens.
