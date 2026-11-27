# ============================================================================
# PDF/Book Search Functions (ripgrep + fzf)
#
# fbook and rgbook are MIRRORED in bash/vifm-pick (vifm needs a script, and
# these cd, which only works in the interactive shell). The rg preview is
# identical in both — change one, change the other. rgbook's search is one
# script both run, bash/vifm-pick.d/rgbook-search.
# ============================================================================

# The papis library. Searched to depth 2 (<entry>/<file>) only: refinery keeps
# split part_N.pdf copies of books under <entry>/<name>.refinery/parts/, which
# would list each book twice and give the part's page numbers, not the book's.
PAPIS_PAPERS="${PAPIS_PAPERS:-$HOME/.local/share/papis/papers}"

# rgbook's search, shared with bash/vifm-pick. Resolved when this file is
# sourced: zsh sets $0 to the sourcing file, through install.sh's symlink too.
_rgbook_search="${0:A:h:h:h}/bash/vifm-pick.d/rgbook-search"

# Open in sioyek directly rather than via xdg-open, because xdg-open cannot
# carry a page number (--page, the point of rgbook).
# setsid detaches the viewer, so closing the terminal does not close the book.
# Sioyek centers --yloc in the window. Without it, --page puts the page's top
# boundary at the center, leaving the previous page visible.

_open_book() {
  local file="$1" page="${2:-}" yloc
  local -a args
  if [[ -n "$page" ]]; then
    args=(--page "$page")
    yloc=$(pdf-meta yloc "$file" "$page" 2>/dev/null)
    [[ -n "$yloc" ]] && args+=(--yloc "$yloc")
  fi
  setsid -f sioyek "${args[@]}" "$file" >/dev/null 2>&1
}

# ----------------------------------------------------------------------------
# rgbook - search refinery's sibling <stem>.md review copies by content
# Their page markers are physical PDF pages. Books without a finished review
# copy are absent until refinery produces one.
# Usage: rgbook [query]
# Keys: Enter → open at page (sioyek), Ctrl-d → cd to folder, Ctrl-o → open folder in vifm
# ----------------------------------------------------------------------------
rgbook() {
  local sp="${PAPIS_PAPERS}"
  local query="${*:-}"
  # Exported for fzf's preview shell: {1} must sit outside our quotes, because
  # fzf substitutes it as a single-quoted string.
  local -x SP="$sp"

  # Exported, like SP, for fzf's reload shell.
  local -x RGBOOK_SEARCH="$_rgbook_search"
  local reload_cmd='"$RGBOOK_SEARCH" {q}'

  local key selection
  _fzf_pick key selection --ansi --disabled --query "$query" \
    --bind "change:reload:$reload_cmd" \
    --bind "start:reload:$reload_cmd" \
    --delimiter=$'\t' \
    --with-nth=2 \
    --preview '[ -n {q} ] && rg --smart-case --context 3 --no-heading -e {q} "$SP/"{1} 2>/dev/null | head -20' \
    --preview-window='hidden,right:50%' \
    --bind 'ctrl-p:toggle-preview' \
    --expect='ctrl-d,ctrl-o' \
    --header='Enter: open at page | Ctrl-d: cd to folder | Ctrl-o: open in vifm' || return 0

  # Format: path<TAB>filename:Page N:text
  local relpath="${selection%%$'\t'*}"
  local file="$sp/${relpath%.md}.pdf"

  if [[ ! -f "$file" ]]; then
    echo "File not found: $file" >&2
    return 1
  fi

  local page=$(grep -oP 'Page \K[0-9]+' <<<"$selection" | head -1)

  case "$key" in
    ctrl-d)
      builtin cd "$(dirname "$file")"
      ;;
    ctrl-o)
      vifm "$(dirname "$file")"
      ;;
    *)
      _open_book "$file" "$page"
      ;;
  esac
}

# ----------------------------------------------------------------------------
# fbook - find book by filename
# Usage: fbook [pattern]
# Keys: Enter → open (sioyek), Ctrl-d → cd to folder, Ctrl-o → open folder in vifm
# ----------------------------------------------------------------------------
fbook() {
  local search_path="${PAPIS_PAPERS}"
  local pattern="${*:-.}"

  local -x SP="$search_path"
  local key selection
  fd --type f --max-depth 2 -e pdf -e epub --base-directory "$search_path" "$pattern" 2>/dev/null \
    | _fzf_pick key selection --preview 'pdf-meta preview "$SP/"{} 2>/dev/null || echo "No info available"' \
      --preview-window='hidden,right:40%' \
      --bind 'ctrl-p:toggle-preview' \
      --expect='ctrl-d,ctrl-o' \
      --header='Enter: open | Ctrl-d: cd to folder | Ctrl-o: open in vifm' || return 0

  local file="$search_path/$selection"
  [[ -f "$file" ]] || return 0

  case "$key" in
    ctrl-d)
      builtin cd "$(dirname "$file")"
      ;;
    ctrl-o)
      vifm "$(dirname "$file")"
      ;;
    *)
      _open_book "$file"
      ;;
  esac
}

# ============================================================================
# PDF page surgery (qpdf - lossless, preserves links + outline)
# ============================================================================

# ----------------------------------------------------------------------------
# pdfsel - extract pages from a PDF
# Usage: pdfsel <input.pdf> <pages> [output.pdf]
#   pages: qpdf ranges - 1-5 | 1,3,5 | 1-5,8,10-12 | r3-r1 (last 3) | z (last)
#   output defaults to <input>_sel.pdf
# ----------------------------------------------------------------------------
pdfsel() {
  if (($# < 2)); then
    echo "usage: pdfsel <input.pdf> <pages> [output.pdf]" >&2
    echo "  pages: 1-5 | 1,3,5 | 1-5,8 | r3-r1 (last 3) | z (last)" >&2
    return 1
  fi
  local in="$1" pages="$2" out="${3:-${1:r}_sel.pdf}"
  [[ -f "$in" ]] || {
    echo "pdfsel: no such file: $in" >&2
    return 1
  }
  qpdf "$in" --pages . "$pages" -- "$out" && echo "→ $out"
}

# ----------------------------------------------------------------------------
# pdfmerge - concatenate PDFs (last argument is the output file)
# Usage: pdfmerge <in1.pdf> <in2.pdf> [in3.pdf ...] <output.pdf>
# ----------------------------------------------------------------------------
pdfmerge() {
  if (($# < 3)); then
    echo "usage: pdfmerge <in1.pdf> <in2.pdf> [...] <output.pdf>" >&2
    return 1
  fi
  local out="${@[-1]}" ins=("${@[1,-2]}") f
  # An existing output is refused: with the output name forgotten,
  # `pdfmerge a.pdf b.pdf c.pdf` would overwrite c.pdf, and a rerun of
  # `pdfmerge ./*.pdf out.pdf` would merge out.pdf into itself. A dangling
  # symlink counts too: -e is false for it, and qpdf would write its target.
  if [[ -e "$out" || -L "$out" ]]; then
    echo "pdfmerge: $out exists; remove it or name a new output" >&2
    return 1
  fi
  for f in "$ins[@]"; do
    [[ -f "$f" ]] || {
      echo "pdfmerge: no such file: $f" >&2
      return 1
    }
  done
  qpdf "$ins[1]" --pages "$ins[@]" -- "$out" && echo "→ $out (${#ins} files)"
}
