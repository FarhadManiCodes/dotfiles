# Converting a PDF that is not a library paper

Read after choosing the conversion path in `SKILL.md`. This is the cheap path: no figure
descriptions, no citation verification, no network, no API key.

## Markdown out of a PDF

```bash
refinery-typeset paper-or-book.pdf
```

Two things come out of that: a typeset PDF at `<stem>.typeset.pdf`, and — the part usually
wanted — the parsed markdown at `<stem>.refinery/parsed.md`.

There is no parse-only entry point. `refinery-typeset` is the closest thing to one, and the
markdown is a by-product of it rather than its advertised output. Take the file and ignore the
PDF if the PDF is not what you were after.

It accepts markdown as input too, which skips OCR entirely — useful for re-typesetting a previous
run's `parsed.md` after editing it by hand.

## Why not `refinery` for this

`refinery` always runs the full pipeline — parse, figure-enrich via Gemini, citation-verify
against CrossRef/S2/OpenAlex, chunk. There is no flag to stop after parsing. On a book or a
non-academic PDF the citation stage has nothing real to resolve and the figure stage costs one
Gemini call per figure, so you pay for output you did not want and it fails without keys loaded.

You can tell which was run by looking in the work directory:

| Present | What it was |
|---|---|
| `parsed.md` only, plus `figures/` | a parse or typeset run |
| `parsed.md` **and** `refinery.md`, plus `resolution_report.txt` | a full refine |

## Typesetting details worth knowing

Needs `pandoc` and `xelatex` on PATH — system binaries, not pip dependencies.

`--title` and `--author` add a title page; omit them and there is none. `--clean-toc` is the one
option that breaks the no-network promise: it spends a Gemini call to catch table-of-contents
lines the layout model mistagged as headings, beyond the mechanical dedup that always runs. Off
by default, and it needs `GOOGLE_API_KEY`.

`render_pdf` drives xelatex directly rather than through pandoc's `--pdf-engine`, deliberately:
pandoc treats any nonzero engine exit as total failure and discards a PDF that nonstopmode's
error recovery actually produced. Success here is judged by whether a PDF came out, so **a run
that prints TeX errors and still produces a file has worked** — do not re-run it chasing a clean
log.

## Re-chunking without re-parsing

```bash
refinery --from chunk paper.pdf
```

Re-chunks the saved `refinery.md` only. Instant, no OCR, no network — for tuning chunk policy.
`refinery-batch --from chunk` does the same across many.

## When the OCR itself is wrong

The parse checkpoint at `<stem>.refinery/parse_cache/` is keyed on the PDF hash and the parse
config, so a re-run reuses it and will keep reproducing the same bad output. `--force-parse` is
the only thing that bypasses it, and it costs the full ~10-minute OCR pass. That is the one
situation where it is the right flag.
