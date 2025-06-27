#!/usr/bin/env zsh
# =============================================================================
# Enhanced FZF Data Browser - PHASE 1
# Location: $DOTFILES/zsh/specials/fzf_data.sh
# =============================================================================

# Simple file analyzer
_analyze_data_file() {
  local file="$1"

  echo "📁 $(basename "$file")"
  echo "📊 $(ls -lh "$file" 2>/dev/null | awk '{print $5}' || echo 'unknown')"
  echo "📅 $(ls -l "$file" 2>/dev/null | awk '{print $6, $7, $8}' || echo 'unknown')"
  echo ""

  local ext="${file##*.}"
  ext=$(echo "$ext" | tr '[:upper:]' '[:lower:]')

  case "$ext" in
    csv | tsv)
      echo "📊 CSV Quick Stats:"
      if command -v qsv >/dev/null 2>&1; then
        local rows=$(qsv count "$file" 2>/dev/null || echo '?')
        local cols=$(qsv headers "$file" 2>/dev/null | wc -l || echo '?')
        echo "Rows: $rows | Columns: $cols"
        echo "Headers: $(qsv headers "$file" 2>/dev/null | head -3 | tr '\n' ', ' | sed 's/, $//' || echo 'Error reading headers')"
      else
        local rows=$(wc -l <"$file" 2>/dev/null || echo '?')
        local cols=$(head -1 "$file" 2>/dev/null | tr ',' '\n' | wc -l || echo '?')
        echo "Rows: $rows | Columns: $cols"
        echo "Headers: $(head -1 "$file" 2>/dev/null | cut -d',' -f1-3 || echo 'Error reading headers')"
      fi
      echo ""
      echo "📄 File Preview:"
      if command -v bat >/dev/null 2>&1; then
        bat --color=always --style=numbers --language=csv --line-range=:20 "$file"
      else
        head -20 "$file"
      fi
      ;;
    json | jsonl)
      echo "📄 JSON Info:"
      if command -v jq >/dev/null 2>&1; then
        echo "Structure: $(jq -r 'keys[]?' "$file" 2>/dev/null | head -3 | tr '\n' ' ')..."
        echo "Size: $(jq length "$file" 2>/dev/null || echo '?') items"
      else
        echo "Lines: $(wc -l <"$file" 2>/dev/null || echo '?')"
      fi
      echo ""
      echo "📄 File Preview:"
      if command -v bat >/dev/null 2>&1; then
        bat --color=always --style=numbers --language=json --line-range=:20 "$file"
      else
        head -20 "$file"
      fi
      ;;
    xlsx | xls)
      echo "📊 Excel Info:"
      if command -v python3 >/dev/null 2>&1; then
        python3 -c "
import pandas as pd
try:
    xl = pd.ExcelFile('$file')
    print('Sheets:', len(xl.sheet_names), '(' + ', '.join(xl.sheet_names[:3]) + ')')
    df = pd.read_excel('$file', nrows=1)
    print('Columns:', len(df.columns))
except Exception as e:
    print('Error reading Excel file')
" 2>/dev/null
      else
        echo "Python3 + pandas required for analysis"
      fi
      echo ""
      echo "📄 Raw File Preview:"
      if command -v bat >/dev/null 2>&1; then
        bat --color=always --style=numbers --line-range=:15 "$file"
      else
        head -15 "$file"
      fi
      ;;
    parquet)
      echo "📦 Parquet Info:"
      if command -v python3 >/dev/null 2>&1; then
        python3 -c "
import pandas as pd
try:
    df = pd.read_parquet('$file')
    print('Shape:', df.shape)
    print('Columns:', ', '.join(df.columns[:3].tolist()) + ('...' if len(df.columns) > 3 else ''))
    print('Memory: {:.1f} MB'.format(df.memory_usage(deep=True).sum() / 1024**2))
except Exception as e:
    print('Error reading parquet')
" 2>/dev/null
      else
        echo "Python3 + pandas required"
      fi
      echo ""
      echo "📄 Binary File Preview:"
      if command -v bat >/dev/null 2>&1; then
        echo "Binary parquet file - use pandas for data preview"
      else
        echo "Binary parquet file"
      fi
      ;;
    pkl | pickle)
      echo "🥒 Pickle Info:"
      if command -v python3 >/dev/null 2>&1; then
        python3 -c "
import pickle
try:
    with open('$file', 'rb') as f:
        obj = pickle.load(f)
    print('Type:', type(obj).__name__)
    if hasattr(obj, 'shape'):
        print('Shape:', obj.shape)
    print('Size: {:.1f} KB'.format(len(open('$file', 'rb').read()) / 1024))
except Exception as e:
    print('Error reading pickle')
" 2>/dev/null
      else
        echo "Python3 required"
      fi
      echo ""
      echo "📄 Binary File Preview:"
      echo "Binary pickle file - use python for object inspection"
      ;;
    yaml | yml)
      echo "📄 YAML Info:"
      echo "Lines: $(wc -l <"$file" 2>/dev/null || echo '?')"
      if command -v yq >/dev/null 2>&1; then
        echo "Keys: $(yq eval 'keys | join(", ")' "$file" 2>/dev/null | head -c 50)..."
      fi
      echo ""
      echo "📄 File Preview:"
      if command -v bat >/dev/null 2>&1; then
        bat --color=always --style=numbers --language=yaml --line-range=:20 "$file"
      else
        head -20 "$file"
      fi
      ;;
    *)
      echo "📄 File Preview:"
      if command -v bat >/dev/null 2>&1; then
        bat --color=always --style=numbers --line-range=:25 "$file"
      else
        head -25 "$file"
      fi
      ;;
  esac
}

# Main data browser with inline preview
fdata-preview() {
  local preview_window="${1:-down:75%:wrap}"
  local multi_mode="false"

  if [[ "$1" == "--multi" ]]; then
    multi_mode="true"
    preview_window="${2:-down:75%:wrap}"
  fi

  local header_text='📊 Data Browser | Enter: edit | Ctrl+D: cd | Ctrl+V: copy | Ctrl+O: folder'

  # Change header for multi mode
  if [[ "$multi_mode" == "true" ]]; then
    header_text='📊 Data Browser (Multi-Select) | Enter: edit | Ctrl+D: cd | Ctrl+V: copy | Ctrl+O: folder'
  fi

  # Base bindings (always present)
  local bindings=(
    'ctrl-d:execute(cd $(dirname {}) && pwd)+abort'
    'ctrl-v:execute(echo {} | wl-copy 2>/dev/null || echo {} | xclip -sel c 2>/dev/null)'
    'ctrl-o:execute(xdg-open $(dirname {}) 2>/dev/null &)'
  )

  # Add profiler binding only if we're in tmux and using bottom preview
  if [[ -n "$TMUX" && "$preview_window" == *"down"* ]]; then
    if [[ "$multi_mode" == "true" ]]; then
      # Multi-select mode: handle both single and multiple selections
      bindings+=('ctrl-r:execute(
        if [[ "{+}" != "{}" ]]; then
          count=$(echo "{+}" | wc -w)
          echo "📊 Multi-file profiling: $count files"
          echo "{+}" | tr " " "\n" | while read file; do 
            [[ -n "$file" ]] && echo "  • $(basename "$file")"
          done
          echo ""
          echo "🚀 Ready for batch profiling!"
          # Save selections to environment variable
          export FDATA_SELECTED=$(echo "{+}" | tr " " ":")
        else
          echo "📊 Single file profiling: $(basename "{}")"
          echo "🔄 Would profile: {}"
          # Clear selections and set single file
          export FDATA_SELECTED="{}"
        fi
        echo ""
        echo "Press any key to return..."
        read -n 1
      )')
    else
      # Single-select mode: simple profiling
      bindings+=('ctrl-r:execute(
        echo "📊 Single file profiling: $(basename "{}")"
        echo "🔄 Would profile: {}"
        export FDATA_SELECTED="{}"
        echo ""
        echo "Press any key to return..."
        read -n 1
      )')
    fi
    header_text="${header_text} | Ctrl+R: profile"
  fi

  # Build fzf options array
  local fzf_options=(
    --height=99%
    --preview='source "$DOTFILES/zsh/specials/fzf_data.sh" && _analyze_data_file {}'
    --preview-window="$preview_window"
    "${bindings[@]/#/--bind=}"
    --header="$header_text"
  )

  # Add --multi flag if in multi mode
  if [[ "$multi_mode" == "true" ]]; then
    fzf_options+=(--multi)
  fi

  fd --type f \
    -e csv -e tsv -e json -e jsonl \
    -e parquet -e xlsx -e xls \
    -e pkl -e pickle -e h5 -e hdf5 \
    -e yaml -e yml \
    --exclude __pycache__ --exclude .git --exclude .venv \
    2>/dev/null |
    fzf "${fzf_options[@]}"
}

# Quick stats function
data-quick-stats() {
  local file="$1"
  if [[ -z "$file" || ! -f "$file" ]]; then
    echo "Usage: data-quick-stats <filename>"
    return 1
  fi
  _analyze_data_file "$file"
}

# Show tools status
fdata-tools-status() {
  echo "🔧 Data Browser Tools:"
  command -v fd >/dev/null && echo "  ✅ fd" || echo "  ❌ fd"
  command -v fzf >/dev/null && echo "  ✅ fzf" || echo "  ❌ fzf"
  command -v bat >/dev/null && echo "  ✅ bat" || echo "  💡 bat (optional)"
  command -v qsv >/dev/null && echo "  ✅ qsv" || echo "  💡 qsv (optional)"
  command -v jq >/dev/null && echo "  ✅ jq" || echo "  💡 jq (optional)"
  command -v python3 >/dev/null && echo "  ✅ python3" || echo "  ❌ python3"
}

# Help
fdata-help() {
  echo "📊 Enhanced Data Browser"
  echo "========================"
  echo "Functions:"
  echo "  fdata-preview      - Launch data browser"
  echo "  data-quick-stats   - Analyze single file"
  echo "  fdata-tools-status - Check available tools"
  echo ""
  echo "Keybindings:"
  echo "  Enter    - Edit file"
  echo "  Ctrl+D   - cd to directory"
  echo "  Ctrl+V   - Copy file path"
  echo "  Ctrl+O   - Open folder"
}

# Aliases
alias fdata-enhanced='fdata-preview'
