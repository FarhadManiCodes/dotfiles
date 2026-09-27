# ============================================================================
# PDF/Book Search Functions (rga + fzf)
#
# fbook and rgbook are MIRRORED in bash/vifm-pick (vifm needs a script, and
# these cd, which only works in the interactive shell). The rga command, awk
# formatter and rga preview are identical in both — change one, change the other.
# ============================================================================

# The papis library. Searched to depth 2 (<entry>/<file>) only: refinery keeps
# split part_N.pdf copies of books under <entry>/<name>.refinery/parts/, which
# would list each book twice and give the part's page numbers, not the book's.
PAPIS_PAPERS="${PAPIS_PAPERS:-$HOME/.local/share/papis/papers}"

# Open by type: sioyek for PDF — it is the only one taking --page, which is the
# point of rgbook — zathura for DjVu, Foliate for EPUB. Same mapping as
# mimeapps.list, dispatched here because handlr cannot carry a page number.
_open_book() {
  local file="$1" page="${2:-}"
  case "${file:l}" in
    *.pdf)
      if [[ -n "$page" ]]; then
        sioyek --page "$page" "$file" 2>/dev/null &
      else
        sioyek "$file" 2>/dev/null &
      fi
      ;;
    *.djvu) zathura "$file" 2>/dev/null & ;;
    *.epub) foliate "$file" 2>/dev/null & ;;
    *)      handlr open "$file" 2>/dev/null & ;;
  esac
}

# ----------------------------------------------------------------------------
# rgbook - live search PDFs by content
# Usage: rgbook [query]
# Keys: Enter → open at page (sioyek), Ctrl-d → cd to folder, Ctrl-o → open folder in vifm
# ----------------------------------------------------------------------------
rgbook() {
  local sp="${PAPIS_PAPERS}"
  local query="${*:-}"
  # Exported for fzf's preview shell: {1} must sit outside our quotes, because
  # fzf substitutes it as a single-quoted string.
  local -x SP="$sp"

  # rga output: path:line:Page N:text → format to: path<TAB>filename:Page N:text
  local rga_cmd="rga -g '*.pdf' --max-depth 2 --color=always --line-number --no-heading {q} '$sp' 2>/dev/null"
  local format_cmd="awk -F: -v sp='$sp/' '{
    gsub(/\\033\\[[0-9;]*m/, \"\", \$1);
    gsub(sp, \"\", \$1);
    n=split(\$1,a,\"/\");
    key=\$1\":\"\$3;
    if(seen[key]++) next;
    printf \"%s\\t%s:\\033[32m%s\\033[0m:%s\\n\", \$1, a[n], \$3, \$4
  }'"
  local reload_cmd="$rga_cmd | $format_cmd || true"

  local result=$(fzf --ansi --disabled --query "$query" \
      --bind "change:reload:$reload_cmd" \
      --bind "start:reload:$reload_cmd" \
      --delimiter=$'\t' \
      --with-nth=2 \
      --preview 'rga --context 3 --no-heading {q} "$SP/"{1} 2>/dev/null | head -20' \
      --preview-window='hidden,right:50%' \
      --bind 'ctrl-p:toggle-preview' \
      --expect='ctrl-d,ctrl-o' \
      --header='Enter: open at page | Ctrl-d: cd to folder | Ctrl-o: open in vifm')

  [[ -z "$result" ]] && return 0

  local key selection
  _fzf_split "$result" key selection
  [[ -z "$selection" ]] && return 0

  # Format: path<TAB>filename:Page N:text
  local relpath="${selection%%$'\t'*}"
  local file="$sp/$relpath"

  if [[ ! -f "$file" ]]; then
    echo "File not found: $file" >&2
    return 1
  fi

  local page=$(grep -oP 'Page \K[0-9]+' <<< "$selection" | head -1)

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
# Keys: Enter → open (sioyek/zathura/Foliate by type), Ctrl-d → cd to folder, Ctrl-o → open folder in vifm
# ----------------------------------------------------------------------------
fbook() {
  local search_path="${PAPIS_PAPERS}"
  local pattern="${*:-.}"

  local -x SP="$search_path"
  local result=$(fd --type f --max-depth 2 -e pdf -e epub -e djvu "$pattern" "$search_path" 2>/dev/null | \
    sed "s|^$search_path/||" | \
    fzf --preview 'pdfinfo "$SP/"{} 2>/dev/null || echo "No info available"' \
        --preview-window='hidden,right:40%' \
        --bind 'ctrl-p:toggle-preview' \
        --expect='ctrl-d,ctrl-o' \
        --header='Enter: open | Ctrl-d: cd to folder | Ctrl-o: open in vifm')

  [[ -z "$result" ]] && return 0

  local key selection
  _fzf_split "$result" key selection
  # Exit if no selection (user pressed escape)
  [[ -z "$selection" ]] && return 0

  local file="$search_path/$selection"
  [[ ! -f "$file" ]] && return 0

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
  if (( $# < 2 )); then
    echo "usage: pdfsel <input.pdf> <pages> [output.pdf]" >&2
    echo "  pages: 1-5 | 1,3,5 | 1-5,8 | r3-r1 (last 3) | z (last)" >&2
    return 1
  fi
  local in="$1" pages="$2" out="${3:-${1:r}_sel.pdf}"
  [[ -f "$in" ]] || { echo "pdfsel: no such file: $in" >&2; return 1; }
  qpdf "$in" --pages . "$pages" -- "$out" && echo "→ $out"
}

# ----------------------------------------------------------------------------
# pdfmerge - concatenate PDFs (last argument is the output file)
# Usage: pdfmerge <in1.pdf> <in2.pdf> [in3.pdf ...] <output.pdf>
# ----------------------------------------------------------------------------
pdfmerge() {
  if (( $# < 3 )); then
    echo "usage: pdfmerge <in1.pdf> <in2.pdf> [...] <output.pdf>" >&2
    return 1
  fi
  local out="${@[-1]}" ins=("${@[1,-2]}") f
  for f in "$ins[@]"; do
    [[ -f "$f" ]] || { echo "pdfmerge: no such file: $f" >&2; return 1; }
    [[ "$f" == "$out" ]] && { echo "pdfmerge: output would overwrite input: $f" >&2; return 1; }
  done
  qpdf "$ins[1]" --pages "$ins[@]" -- "$out" && echo "→ $out (${#ins} files)"
}
