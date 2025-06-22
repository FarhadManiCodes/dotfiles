#!/bin/bash
# ~/dotfiles/zsh/productivity/cli-enhancements.sh
# Enhanced CLI tools - FOCUSED on unique data engineering file handling

# ============================================================================
# SMART FILE VIEWERS (Unique functionality not covered by existing tools)
# ============================================================================

# Smart file viewer with data engineering format support
view() {
  local file="$1"

  if [[ -z "$file" ]]; then
    echo "Usage: view <file>"
    echo "💡 Smart viewer for data engineering files"
    return 1
  fi

  if [[ ! -f "$file" ]]; then
    echo "❌ File not found: $file"
    return 1
  fi

  # Quick file info
  local size=$(stat -c%s "$file" 2>/dev/null || echo "0")
  echo "📄 $(basename "$file") ($(numfmt --to=iec $size 2>/dev/null || echo "${size}B"))"

  # Format-specific handling
  case "${file,,}" in
    *.csv)
      echo "📊 CSV preview:"
      if command -v csvlook >/dev/null; then
        head -20 "$file" | csvlook 2>/dev/null || head -10 "$file"
      else
        echo "Columns: $(head -1 "$file" | tr ',' '\n' | wc -l)"
        head -10 "$file" | column -t -s, 2>/dev/null || head -10 "$file"
      fi
      ;;
    *.parquet)
      echo "📊 Parquet file:"
      if command -v duckdb >/dev/null; then
        duckdb -c "SELECT * FROM '$file' LIMIT 10;" 2>/dev/null
      else
        echo "💡 Install duckdb to view parquet files"
      fi
      ;;
    *.pkl | *.pickle)
      echo "🐍 Pickle content:"
      python3 -c "
import pickle
try:
    with open('$file', 'rb') as f: obj = pickle.load(f)
    print(f'Type: {type(obj)}')
    if hasattr(obj, 'shape'): print(f'Shape: {obj.shape}')
    elif hasattr(obj, '__len__'): print(f'Length: {len(obj)}')
    print(f'Preview: {str(obj)[:200]}...' if len(str(obj)) > 200 else f'Content: {obj}')
except Exception as e: print(f'Error: {e}')
" 2>/dev/null || echo "💡 Python required for pickle files"
      ;;
    *.ipynb)
      echo "📓 Notebook info:"
      if command -v jq >/dev/null; then
        local cells=$(jq '.cells | length' "$file" 2>/dev/null || echo "?")
        local code_cells=$(jq '[.cells[] | select(.cell_type=="code")] | length' "$file" 2>/dev/null || echo "?")
        echo "Total cells: $cells | Code cells: $code_cells"
        echo "First code cell:"
        jq -r '.cells[] | select(.cell_type=="code") | .source[]' "$file" 2>/dev/null | head -5
      else
        echo "💡 Install jq for better notebook viewing"
      fi
      ;;
    *.json)
      if command -v jq >/dev/null; then
        jq -C . "$file" 2>/dev/null | head -20
      else
        head -20 "$file"
      fi
      ;;
    *)
      # Use bat if available, otherwise cat
      if command -v bat >/dev/null; then
        bat --style=numbers,changes --line-range=:50 "$file" 2>/dev/null
      else
        head -50 "$file"
      fi
      ;;
  esac
}

# Quick data file inspector
peek() {
  local file="$1"
  local lines="${2:-10}"

  [[ -z "$file" ]] && {
    echo "Usage: peek <file> [lines]"
    return 1
  }
  [[ ! -f "$file" ]] && {
    echo "❌ File not found: $file"
    return 1
  }

  echo "📊 Peek: $(basename "$file") (first $lines)"

  case "${file,,}" in
    *.csv)
      head -$((lines + 1)) "$file" | column -t -s, 2>/dev/null || head -$((lines + 1)) "$file"
      ;;
    *.tsv)
      head -$((lines + 1)) "$file" | column -t -s$'\t' 2>/dev/null || head -$((lines + 1)) "$file"
      ;;
    *.parquet)
      if command -v duckdb >/dev/null; then
        duckdb -c "SELECT * FROM '$file' LIMIT $lines;" 2>/dev/null
      else
        echo "💡 Install duckdb for parquet support"
      fi
      ;;
    *.json)
      if command -v jq >/dev/null; then
        jq -C . "$file" 2>/dev/null | head -$((lines * 2))
      else
        head -$lines "$file"
      fi
      ;;
    *)
      head -$lines "$file"
      ;;
  esac
}

# ============================================================================
# ALIASES & HELP
# ============================================================================

alias p='peek'

cli_help() {
  echo "🚀 CLI Enhancements (Focused)"
  echo "============================"
  echo ""
  echo "📄 Smart File Viewers:"
  echo "  view <file>           Format-aware file viewer (CSV, parquet, pickle, JSON, notebooks)"
  echo "  peek <file> [lines]   Quick data preview with column formatting"
  echo "  p <file>              Alias for peek"
  echo ""
  echo "💡 Specialized for data engineering file formats!"
  echo "💡 Use your existing fzf functions (fdata, fnb, ff) for file discovery"
}
