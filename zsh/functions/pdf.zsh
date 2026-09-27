# ============================================================================
# PDF/Book Search Functions (ripgrep + fzf)
#
# fbook and rgbook are MIRRORED in bash/vifm-pick (vifm needs a script, and
# these cd, which only works in the interactive shell). The rg command, awk
# formatter and rg preview are identical in both — change one, change the other.
# ============================================================================

# The papis library. Searched to depth 2 (<entry>/<file>) only: refinery keeps
# split part_N.pdf copies of books under <entry>/<name>.refinery/parts/, which
# would list each book twice and give the part's page numbers, not the book's.
PAPIS_PAPERS="${PAPIS_PAPERS:-$HOME/.local/share/papis/papers}"

# Open by type: sioyek for PDF — it is the only one taking --page, which is the
# point of rgbook — zathura for DjVu, Foliate for EPUB. Same mapping as
# mimeapps.list, dispatched here because handlr cannot carry a page number.
# Sioyek centers --yloc in the window. Without it, --page puts the page's top
# boundary at the center, leaving the previous page visible.
_book_page_middle() {
  LC_ALL=C pdfinfo -f "$2" -l "$2" "$1" 2>/dev/null |
    awk '$1 == "Page" && $3 == "size:" && $5 == "x" && $6 > 0 {
      printf "%.3f", $6 / 2; exit
    }'
}

_open_book() {
  local file="$1" page="${2:-}"
  case "${file:l}" in
    *.pdf)
      if [[ -n "$page" ]]; then
        local yloc=$(_book_page_middle "$file" "$page")
        if [[ -n "$yloc" ]]; then
          sioyek --page "$page" --yloc "$yloc" "$file" 2>/dev/null &
        else
          sioyek --page "$page" "$file" 2>/dev/null &
        fi
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

  # Include markers in the same rg stream so each hit inherits its PDF page.
  local rg_cmd="[ -n {q} ] && rg --smart-case --color=always --no-heading --line-number --max-depth 2 -g '*.md' -g '!notes.md' -g '!*.refinery/**' -e '^<page_number>[0-9]+</page_number>$' -e {q} \"\$SP\" 2>/dev/null"
  local format_cmd="awk -v sp=\"\$SP/\" '
    {
      first=index(\$0, \":\"); if (!first) next;
      second=index(substr(\$0, first+1), \":\"); if (!second) next;
      path=substr(\$0, 1, first-1);
      line=substr(\$0, first+1, second-1);
      raw=substr(\$0, first+second+1);
      gsub(/\\033\\[[0-9;]*m/, \"\", path);
      gsub(/\\033\\[[0-9;]*m/, \"\", line);
      if (substr(path, 1, length(sp)) != sp) next;
      path=substr(path, length(sp)+1);
      plain=raw; gsub(/\\033\\[[0-9;]*m/, \"\", plain);
      if (plain ~ /^<page_number>[0-9]+<\\/page_number>$/) {
        page[path]=plain; sub(/^<page_number>/, \"\", page[path]);
        sub(/<\\/page_number>$/, \"\", page[path]); next;
      }
      if (!(path in page)) next;
      key=path SUBSEP page[path]; if (seen[key]++) next;
      name=path; sub(/^.*\\//, \"\", name); sub(/\\.md$/, \".pdf\", name);
      snippet=raw;
      if (length(plain) > 220) {
        start_color=match(raw, /\\033\\[1m\\033\\[31m/);
        before=substr(raw, 1, start_color-1);
        gsub(/\\033\\[[0-9;]*m/, \"\", before);
        pos=length(before)+1;
        start=pos-50; if (start<1) start=1;
        stop=pos+150; if (stop>length(plain)) stop=length(plain);
        snippet=substr(plain, start, stop-start+1);
        if (start_color) {
          colored=substr(raw, start_color+RLENGTH);
          reset=index(colored, sprintf(\"%c[0m\", 27));
          if (reset) {
            hit=substr(colored, 1, reset-1);
            gsub(/\\033\\[[0-9;]*m/, \"\", hit);
            offset=pos-start+1;
            snippet=substr(snippet, 1, offset-1) sprintf(\"%c[1m%c[31m\", 27, 27) hit sprintf(\"%c[0m\", 27) substr(snippet, offset+length(hit));
          }
        }
        if (start>1) snippet=\"…\" snippet;
        if (stop<length(plain)) snippet=snippet \"…\";
      }
      printf \"%s\\t%s:\\033[32mPage %s\\033[0m:%s\\n\", path, name, page[path], snippet;
    }'"
  local reload_cmd="$rg_cmd | $format_cmd || true"

  local result=$(fzf --ansi --disabled --query "$query" \
      --bind "change:reload:$reload_cmd" \
      --bind "start:reload:$reload_cmd" \
      --delimiter=$'\t' \
      --with-nth=2 \
      --preview '[ -n {q} ] && rg --smart-case --context 3 --no-heading -e {q} "$SP/"{1} 2>/dev/null | head -20' \
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
  local file="$sp/${relpath%.md}.pdf"

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
