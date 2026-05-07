# ============================================================================
# PDF/Book Search Functions (rga + fzf)
# ============================================================================

# Default library path (local sync from cloud, can override with STUDY_LIBRARY env var)
STUDY_LIBRARY="${STUDY_LIBRARY:-$HOME/.local/share/study-library}"

# ----------------------------------------------------------------------------
# rgbook - live search PDFs by content
# Usage: rgbook [query]
# Keys: Enter → open in zathura at page, Ctrl-d → cd to folder
# ----------------------------------------------------------------------------
rgbook() {
  local sp="${STUDY_LIBRARY}"
  local query="${*:-}"

  # rga output: path:line:Page N:text → format to: path<TAB>filename:Page N:text
  local rga_cmd="rga -g '*.pdf' --color=always --line-number --no-heading {q} '$sp' 2>/dev/null"
  local format_cmd="awk -F: -v sp='$sp/' '{
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
      --preview "rga --context 3 --no-heading {q} '$sp/{1}' 2>/dev/null | head -20" \
      --preview-window='hidden,right:50%' \
      --bind 'ctrl-p:toggle-preview' \
      --expect='ctrl-d' \
      --header='Enter: open at page | Ctrl-d: cd to folder')

  [[ -z "$result" ]] && return 0

  local key=$(head -1 <<< "$result")
  local selection=$(tail -1 <<< "$result")

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
    *)
      if [[ -n "$page" ]]; then
        zathura --page="$page" "$file" 2>/dev/null &
      else
        zathura "$file" 2>/dev/null &
      fi
      ;;
  esac
}

# ----------------------------------------------------------------------------
# fbook - find book by filename
# Usage: fbook [pattern]
# Keys: Enter → open in zathura, Ctrl-d → cd to folder
# ----------------------------------------------------------------------------
fbook() {
  local search_path="${STUDY_LIBRARY}"
  local pattern="${*:-.}"

  local result=$(fd --type f -e pdf -e epub -e djvu "$pattern" "$search_path" 2>/dev/null | \
    sed "s|^$search_path/||" | \
    fzf --preview "pdfinfo \"$search_path/{}\" 2>/dev/null || echo 'No info available'" \
        --preview-window='hidden,right:40%' \
        --bind 'ctrl-p:toggle-preview' \
        --expect='ctrl-d' \
        --header='Enter: open | Ctrl-d: cd to folder')

  [[ -z "$result" ]] && return 0

  local key=${result%%$'\n'*}
  local selection=${result##*$'\n'}

  # Exit if no selection (user pressed escape)
  [[ -z "$selection" ]] && return 0

  local file="$search_path/$selection"
  [[ ! -f "$file" ]] && return 0

  case "$key" in
    ctrl-d)
      builtin cd "$(dirname "$file")"
      ;;
    *)
      zathura "$file" 2>/dev/null &
      ;;
  esac
}
