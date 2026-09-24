# Getting a paper into the library and asking questions of it

Read after choosing the library path in `SKILL.md`.

- [Adding](#adding)
- [Queries](#queries)
- [Indexing](#indexing)
- [Asking](#asking)
- [Personal notes](#personal-notes)
- [Books a study project already converted](#books-a-study-project-already-converted)
- [Citation quality](#citation-quality)
- [Re-refining documents](#re-refining-documents)
- [Passing known metadata to refinery](#passing-known-metadata-to-refinery)

## Adding

The library is `~/.local/share/papis/papers` (`papis config dir` confirms it).

Two ways in, for different situations:

- **From the browser**: Tridactyl `,p` calls `bash/papis-add-paper <importer> <id>` with `doi`
  or `arxiv`. It runs from Firefox with no terminal, so it opens a small floating footclient to
  confirm the title and edit a pre-filled reference key and tags. **An empty key cancels.**
  `arxiv` also downloads the PDF; `doi` does not always.
- **From a file you already have**: `papis add --set …` directly. `papis add FILE` **copies**
  the file into the library; the original stays where it was.

**Reference keys are kept unique deliberately.** papis permits duplicates, but `papis.nvim`'s
sqlite cache enforces `UNIQUE(ref)`, so a clash silently breaks the nvim side.
`papis-add-paper` disambiguates its suggestion and re-prompts on a typed clash; do not force a
duplicate.

**A failed importer still adds a document in `--batch` mode**, with no metadata: a
`papis_id`-named folder, a timestamp `ref`, nothing else. arXiv answers HTTP 406 for a while
after a burst of PDF downloads from one IP. For bulk adds, fetch metadata yourself (the arXiv
Atom API with plain curl works) and add with `papis add --batch --from yaml meta.yaml file.pdf`.
papis rewrites `ref` from `ref-format` even when the YAML sets one, and normalises hyphens
(`Ruiz-Balet` becomes `Ruiz_Balet`), so check refs for duplicates afterwards.

## Queries

**`key:value` values are unanchored, case-insensitive regexes.** `ref:Li_2026` also matches
`Ali_2026`, and `tags:control` also matches `agent-control`. Use `ref:^Li_2026$` for an exact
ref. Anchors do not work on list fields: `tags:^cpp$` matches nothing, so keep tag names from
being substrings of each other. Current tags, with counts:

```bash
papis list --all --format '{doc[tags]}' | tr ' ,' '\n\n' | tr -d "[]'" | grep -v '^$' | sort | uniq -c | sort -rn
```

**`AND`, `OR`, `NOT` and parentheses work** (papis 0.16). Space-separated terms are ANDed.
`tags:llm-steering OR tags:agent-safety` and `tags:book AND NOT tags:cpp` both work.

`papis list` needs **`--all`**; without it, it returns nothing. `-f` is `--file` (a boolean,
"show the files"), not a format argument; the query is positional. An empty query is not
special: `papis list --all -f ""` returns every document.

## Indexing

```bash
pask index                                                      # everything that needs it
( source ~/.config/secrets/papis.env; papis ask index "ref:^Kalman_1960$" )   # one document
pask index -f "ref:^Kalman_1960$"                               # force re-embed (paid)
```

Why not `pask index "query"` for a subset: it refines only the matches, then indexes the whole
library (see `SKILL.md`). Refine the subset first if it needs it, then use the papis form.

`pask index` refines first, automatically. A PDF is refined when its `chunks.json` is missing or
older than the PDF; that mtime comparison is the whole staleness rule, so **touching a PDF marks
it for re-refining** and editing `chunks.json` by hand does not. papis-ask in turn re-embeds a
document whenever its `chunks.json` file date changes, even if the chunks are identical.

One PDF goes through `refinery`; several go through `refinery-batch`, which gates cloud OCR to
`--ocr-workers` (z.ai rate-limits concurrent OCR) while running the network stages at
`--workers`. A paper that fails is logged and skipped, so **the final count can be lower than
the number of PDFs given**: check the count, do not assume completion.

**Embedding a large batch can hit Gemini's rate limit** (`429 RESOURCE_EXHAUSTED` after
LiteLLM's retries, around 600 chunks in one run). Work done before the error is saved, and a
re-run embeds only what is still missing. For a big backlog, index one ref at a time with a
pause between runs. Semantic Scholar 429s during indexing only skip optional metadata
enrichment for that paper and do not stop the run.

## Asking

```bash
pask "what does this library say about observability gramians"
pask -s "tags:llm-steering OR tags:agent-safety" "your question"
pask -s "tags:book AND NOT tags:cpp" "your question"
```

Anything that is not `index` passes straight through to `papis ask`, with
`~/.config/secrets/papis.env` sourced in a subshell.

`-s`/`--scope QUERY` answers from the documents matching a papis query only; repeating `-s` is
the same as joining queries with `OR`. Scoping reuses the stored embeddings, so it costs nothing
extra. Matching documents that are not indexed are left out, and a blank `-s ""` is rejected.

Embeddings come from papis' configured backend (`ask.embedding`, a Gemini model), not a local
server. If answers seem to miss a paper you know is there, the question is almost always *was
it indexed*, not *is retrieval wrong*: index that paper and compare.

## Personal notes

A document's personal note is the file named in its papis `notes:` field (`papis edit -n`
creates it). papis-ask indexes it as a separate source next to the paper, so answers can cite
your own notes. Only the `notes:` file counts; other `.md` files in the folder are never
indexed. A note is independent of refinery: re-refining the paper, even with
`--overwrite-edits`, leaves the note untouched.

- `<!--quote-->…<!--/quote-->` blocks and HTML comments (such as sioyek's page markers) are
  removed before embedding; a note holding only headings or quotes is not indexed.
- Editing a note re-embeds it on the next index run.
- A `type: note` entry whose `.md` sits under `files:` instead of `notes:` is never indexed
  (a warning is logged).

## Books a study project already converted

Study projects (`~/projects/cpp-study`, `DDIA_study`, `DataEngineering_study`) hold refinery OCR
of books that are also in the library. Two ways to avoid paying for it again:

**Copy the OCR checkpoint** when the project kept its work directory, as `cpp-study` does under
`books/<slug>/work/refinery/parts/`. Copy that `parts/` into `<library-pdf-stem>.refinery/` and
run `refinery` normally. Every part hits, provided the two PDFs are byte-identical: the key is
the original PDF's sha256 plus the part index and `max_pages_per_part`, and the parse config and
checkpoint version must match too. A project converted with a different OCR backend or parse
config misses without any message and pays for full OCR. Compare `sha256sum`s first, and use
`parse_cache.load_checkpoint` for a dry run that costs nothing. A hit shows in the log as the
split followed by `done` within seconds.

**Import the markdown** when only the conversion survived. Write a `refinery.md` into the
library PDF's `<stem>.refinery/` and run `refinery --from chunk <pdf>` (see `convert.md`). The
chunker reads `<page_number>N</page_number>` markers, which must be **PDF page numbers**, so
check what the markers mean before trusting them:

| Source | Markers | Fix |
|---|---|---|
| DDIA chapters | restart at 1 per chapter | add each chapter's start page from the PDF outline (`get_toc()`) |
| Data Center as a Computer, Fourth Paradigm | printed page numbers | constant offset per chapter or book, found by matching text |
| Fundamentals of Data Engineering | stripped entirely | rebuild by locating each paragraph's opening words in the PDF text layer |

Verify either way. Sample marked pages and compare each one's words with `pymupdf` page text at
offsets −1/0/+1; the right mapping wins at 0 almost every time. Also strip bare
`![FIGURE_CROP …](…)` lines, which a full run would have replaced with descriptions, but keep
the captions. What you give up compared with a full run is figure descriptions and the citation
stage.

## Citation quality

Each refine writes `<stem>.refinery/resolution_report.txt` and `<stem>.citations.json`.

**Reading the report.** The first line gives the verified count, split by the route that
verified each reference: `resolved 157/937 references (crossref: 154, openalex: 2,
semanticscholar: 1)`. `crossref`, `semanticscholar` and `openalex` are title searches, tried in
that order, so a healthy report is mostly `crossref` too. `bulk` means the source paper's own
reference list, fetched from S2 or OpenAlex; `doi` an S2 lookup by a printed DOI; `papis` a match
against the document's papis `citations:` field.

Acceptance: a title match at similarity ≥ 0.90 needs the year within ±1 (a missing year on
either side skips the check) and no plain disagreement between printed and provider surnames. A
match at 0.75–0.90 needs the exact year and the same first-author surname.

Each reference under `UNVERIFIED` shows its `best reject`, the closest candidate, with the
*candidate's* year (check the printed year in `references.md` or `citations.json`), or `no
candidate from any provider`:

| What you see | What it means | Worth a re-run? |
|---|---|---|
| Low similarity, candidate unrelated | The providers do not list it: web pages, blog posts, talks, ISO standards, software, committee papers | No; unverified is correct |
| Similarity 0.75–0.90 | An OCR-garbled title without matching year and first author, or a different work | Look at the entry by hand |
| Similarity ≥ 0.90, printed year off by more than 1 | Another edition or a reprint | No; rejected on purpose |
| Similarity ≥ 0.90, year within ±1 | The printed and provider authors disagree (the report does not show the authors) | Look at the entry by hand |
| Low verified share on a paper-heavy bibliography, with `semanticscholar`, `openalex`, `bulk` and `doi` all near zero | S2 and OpenAlex were rate-limited or keyless during the run | **Yes**, serially |

A book citing mostly web pages and standards stays around 20% however often it is re-run.

**Refine serially when citations matter.** Several refinery workers make the free providers
rate-limit each other: papers from a 4-worker batch verified 12–53% of references, and one of
them went from 40% to 77% when re-run alone with an OpenAlex key. Use
`refinery-batch --workers 1`.

**Providers and credentials** (all in refinery's secrets folder, see `SKILL.md`):

- OpenAlex requires a free API key. Keyless requests share a per-IP daily budget and return
  `429 "Insufficient budget"`, and the fallback then fails without further notice. The key goes
  in `openalex.env` as `OPENALEX_API_KEY`; a rejected key is logged once.
- CrossRef and OpenAlex give a "polite pool" to requests carrying a contact address:
  `REFINERY_MAILTO` in `contact.env`, sent only to the providers in `[citation]
  mailto_providers` of `config.toml`.
- Semantic Scholar has no polite pool, and its key needs an academic affiliation. Keyless works
  with retries (`[citation] api_retry_attempts`, 5 in `config.toml`; the default is 2).

**Wrong matches.** `citations.json` stores the provider's title. A title that does not fit its
printed reference is usually a wrong *resolution*: refinery rejects a title match when the
printed and provider surnames plainly disagree, and tries the provider's next hits when the top
one is rejected. Extraction misalignment shows as the benign warnings `N line(s) unmatched --
retrying them once` or `dropped N row(s) that do not fit their line`.

## Re-refining documents

To improve a document, re-run `refinery` on its PDF. OCR, figure descriptions and successful
provider lookups all come from caches; what runs again is citation extraction (flash-lite, one
call per 50 references) and the lookups that failed before. The cost is mostly downstream: the
new `chunks.json` makes the next index run re-embed the whole document, typically several times
the extraction tokens. When only chunking changed, re-chunk instead (`convert.md`), and only the
documents whose chunks actually change.

**Hand edits to `refinery.md`.** A full run replaces `refinery.md`. Refinery records a checksum
of each file it writes; a later full run that finds the file edited stops before any paid work,
keeps a `refinery.md.hand-edited-*` copy, and points to `refinery --from chunk`, which re-chunks
the edited file. `--overwrite-edits` replaces it anyway (a copy is kept either way). In
`refinery-batch` a refused paper is skipped, so the final count drops. A `refinery.md` written
before checksums existed (refinery < 0.3.6) cannot be checked: it is copied to
`refinery.md.before-*` and replaced without stopping.

Checklist for re-refining several documents:

```text
- [ ] No refinery process running; installed refinery matches the source (SKILL.md)
- [ ] Back up each document's citations.json, chunks.json, .md and .refinery/ outside the library
- [ ] Note each document's current verified count (first line of resolution_report.txt)
- [ ] Decide on hand-edited documents: --from chunk to keep the edits, --overwrite-edits to drop them
- [ ] Refine one PDF at a time: refinery-batch --workers 1 [--meta-map map.json] PDF
- [ ] After each refine, pause, then index that ref alone:
      ( source ~/.config/secrets/papis.env; papis ask index "ref:^X$" )
      retry after a pause on 429; stop on "spending cap"
- [ ] Check every refine succeeded and every ref is indexed; compare verified counts with the backup
```

## Passing known metadata to refinery

`refinery-batch --meta-map FILE` feeds known doi/title/year/authors (a JSON object keyed by PDF
path) into source identification, so refinery can take the S2 bulk-references fast path: one
call for the whole bibliography instead of a per-reference search. It is optional; without it
refinery falls back to the OCR'd title. For a single PDF, `refinery --doi DOI` does the same.
`refinery-export-citations` goes the other way, turning
resolved references into papis `citations:` YAML.
