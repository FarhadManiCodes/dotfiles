# Converting a PDF that is not a library paper

Read after choosing the conversion path in `SKILL.md`. This path skips figure descriptions and
citation verification; same OCR-backend rules as the table there (`maas` needs
`ZHIPU_API_KEY` + network, `selfhosted` is local, markdown input skips OCR).

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

`refinery` always runs the full pipeline: parse, figure-enrich via Gemini, citation-verify
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

`--title` and `--author` add a title page; omit them and there is none. `--clean-toc` spends
Gemini calls to catch table-of-contents lines the layout model mistagged as headings, beyond the
mechanical dedup that always runs. It is off by default and needs `GOOGLE_API_KEY`; these calls
are additional to any network access used by the configured OCR backend.

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

Chunking leaves out reference lists and back-of-book indexes (`[chunk] drop_back_matter`,
default on), which would otherwise be retrieved and cited as evidence. A headed section is
dropped only when its content looks like references or index entries, so a section titled
"1.8.4 References" about C++ references stays; long unheaded index runs go too.

Re-chunking is free, but it rewrites every `chunks.json` it touches, and papis-ask re-embeds by
file date alone, so each re-chunked document is re-embedded (paid) even if its chunks come out
identical. Re-chunk only the documents whose chunks would change: compare `chunk_markdown` on
their `refinery.md` with the old and new settings first.

## When the OCR itself is wrong

Same checkpoint as in `SKILL.md` — if the OCR itself was wrong, a plain re-run just reproduces
it. `--force-parse` is the only way past that, at the cost of the full ~10-minute pass.
