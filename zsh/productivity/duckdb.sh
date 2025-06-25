#!/bin/zsh
# DuckDB Integration - Simple & Reliable Approach
# Location: $DOTFILES/zsh/productivity/duckdb-enhancements.sh
# Loaded by: scripts.sh

# ============================================================================
# SMART DUCKDB LAUNCHER (with commands)
# ============================================================================

duck() {
  local action="$1"

  case "$action" in
    "" | "start")
      if [[ -f ".duckdb_setup.sql" ]]; then
        echo "🦆 Starting DuckDB with data loaded..."
        duckdb -init .duckdb_setup.sql
      else
        echo "❌ No .duckdb_setup.sql found"
        echo "💡 Run: duck setup"
        echo "💡 Or start fresh: duck clean"
      fi
      ;;
    "clean" | "fresh")
      echo "🦆 Starting fresh DuckDB session (global config)..."
      duckdb
      ;;
    "setup" | "refresh")
      if [[ -f "$DOTFILES/zsh/specials/load_data_duckdb.sh" ]]; then
        bash "$DOTFILES/zsh/specials/load_data_duckdb.sh" --force
      else
        echo "❌ Setup script not found: $DOTFILES/zsh/specials/load_data_duckdb.sh"
      fi
      ;;
    "info" | "tables")
      if [[ -f ".duckdb_setup.sql" ]]; then
        echo "📊 Available tables:"
        grep -o 'CREATE VIEW [a-zA-Z0-9_]* AS' .duckdb_setup.sql | sed 's/CREATE VIEW /  • /' | sed 's/ AS//' 2>/dev/null || echo "  (no tables found)"
        echo ""
        echo "Generated: $(head -2 .duckdb_setup.sql | tail -1 | sed 's/-- Generated: //')"
      else
        echo "❌ No setup file found"
        echo "💡 Run: duck setup"
      fi
      ;;
    "help" | "-h" | "--help")
      echo "🦆 Duck - DuckDB Helper"
      echo "======================"
      echo ""
      echo "Usage: duck [command]"
      echo ""
      echo "Commands:"
      echo "  duck              - Start DuckDB with data loaded (default)"
      echo "  duck start        - Same as above"
      echo "  duck clean        - Start fresh DuckDB (no data loaded)"
      echo "  duck setup        - Generate/refresh data setup"
      echo "  duck info         - Show available tables"
      echo "  duck help         - Show this help"
      echo ""
      echo "Examples:"
      echo "  duck              # Start with your data loaded"
      echo "  duck clean        # Start empty DuckDB"
      echo "  duck setup        # Refresh if you added new files"
      ;;
    *)
      echo "❌ Unknown command: $action"
      echo "💡 Try: duck help"
      ;;
  esac
}

# ============================================================================
# COLORIZED OUTPUT FUNCTIONS
# ============================================================================

# DuckDB with CSV output piped to bat for syntax highlighting
duckdb-pretty() {
  local query="$1"
  if [[ -z "$query" ]]; then
    echo "Usage: duckdb-pretty 'SELECT * FROM table LIMIT 10'"
    return 1
  fi

  if [[ -f ".duckdb_setup.sql" ]]; then
    echo "$query" | duckdb -init .duckdb_setup.sql -csv | bat --language=csv --style=grid
  else
    echo "$query" | duckdb -csv | bat --language=csv --style=grid
  fi
}

# Quick table preview with colors
duck-peek() {
  local table="$1"
  local rows="${2:-10}"

  if [[ -z "$table" ]]; then
    echo "Usage: duck-peek table_name [rows]"
    echo "Available tables:"
    duck info
    return 1
  fi

  duckdb-pretty "SELECT * FROM $table LIMIT $rows"
}

# Show tables with nice formatting
duck-tables() {
  if [[ -f ".duckdb_setup.sql" ]]; then
    echo ".tables" | duckdb -init .duckdb_setup.sql
  else
    echo "❌ No data setup found. Run: duck setup"
  fi
}

# Quick stats for a table (colorized output)
duck-stats() {
  local table="$1"
  if [[ -z "$table" ]]; then
    echo "Usage: duck-stats table_name"
    return 1
  fi

  duckdb-pretty "
    SELECT 
        '$table' as table_name,
        COUNT(*) as total_rows
    FROM $table
    UNION ALL
    SELECT 
        'Column Count' as info,
        COUNT(*) as value
    FROM information_schema.columns 
    WHERE table_name = '$table'
    "
}

# ============================================================================
# EXPORT FUNCTIONS
# ============================================================================

# Export query results to different formats with colors
duck-export() {
  local format="$1"
  local query="$2"
  local output="$3"

  if [[ -z "$format" || -z "$query" || -z "$output" ]]; then
    echo "Usage: duck-export <csv|json|md> 'SELECT...' output.file"
    echo "Example: duck-export csv 'SELECT * FROM sales' sales.csv"
    return 1
  fi

  local duck_cmd="duckdb"
  if [[ -f ".duckdb_setup.sql" ]]; then
    duck_cmd="duckdb -init .duckdb_setup.sql"
  fi

  case "$format" in
    csv)
      echo "$query" | $duck_cmd -csv >"$output" && echo "✅ Exported to $output" && bat --language=csv "$output"
      ;;
    json)
      echo "$query" | $duck_cmd -json >"$output" && echo "✅ Exported to $output" && bat --language=json "$output"
      ;;
    md | markdown)
      echo "$query" | $duck_cmd -markdown >"$output" && echo "✅ Exported to $output" && bat --language=markdown "$output"
      ;;
    *)
      echo "❌ Unsupported format: $format"
      echo "💡 Supported: csv, json, md"
      ;;
  esac
}

# Copy DuckDB query results to clipboard
duck-copy() {
  local query="$1"
  local format="${2:-csv}"

  if [[ -z "$query" ]]; then
    echo "Usage: duck-copy 'SELECT * FROM table' [csv|json]"
    return 1
  fi

  local duck_cmd="duckdb"
  if [[ -f ".duckdb_setup.sql" ]]; then
    duck_cmd="duckdb -init .duckdb_setup.sql"
  fi

  local result
  case "$format" in
    csv)
      result=$(echo "$query" | $duck_cmd -csv)
      ;;
    json)
      result=$(echo "$query" | $duck_cmd -json)
      ;;
    *)
      result=$(echo "$query" | $duck_cmd -box)
      ;;
  esac

  if command -v wl-copy >/dev/null 2>&1; then
    echo "$result" | wl-copy
    echo "✅ Copied to clipboard (Wayland)"
  elif command -v xclip >/dev/null 2>&1; then
    echo "$result" | xclip -selection clipboard
    echo "✅ Copied to clipboard (X11)"
  else
    echo "❌ No clipboard tool found"
    echo "$result"
  fi
}

# ============================================================================
# INTERACTIVE FUNCTIONS
# ============================================================================

# Interactive DuckDB with fzf integration
duck-interactive() {
  if ! command -v fzf >/dev/null; then
    echo "❌ fzf not found - falling back to regular DuckDB"
    duck
    return
  fi

  if [[ ! -f ".duckdb_setup.sql" ]]; then
    echo "❌ No data setup found. Run: duck setup"
    return 1
  fi

  echo "🦆 Interactive DuckDB with fzf"
  echo "Select a table to explore:"

  local table=$(duck info 2>/dev/null | grep "•" | sed 's/.*• //' | sed 's/ .*//' | fzf --prompt="Select table: " --height=40%)

  if [[ -n "$table" ]]; then
    echo "📊 Selected: $table"
    echo "🔍 Preview:"
    duck-peek "$table" 5
    echo ""
    echo "🚀 Starting DuckDB with $table loaded..."
    duck
  fi
}

# ============================================================================
# TMUX INTEGRATION
# ============================================================================

# DuckDB query with results in a new tmux window
duck-tmux() {
  local query="$1"
  local window_name="${2:-duckdb-query}"

  if [[ -z "$TMUX" ]]; then
    echo "❌ Not in tmux session"
    return 1
  fi

  if [[ -z "$query" ]]; then
    echo "Usage: duck-tmux 'SELECT * FROM table' [window_name]"
    return 1
  fi

  local duck_cmd="duckdb"
  if [[ -f ".duckdb_setup.sql" ]]; then
    duck_cmd="duckdb -init .duckdb_setup.sql"
  fi

  tmux new-window -n "$window_name" "echo '$query' | $duck_cmd -box && read -p 'Press Enter to close...'"
}

# ============================================================================
# STATUS AND HELP
# ============================================================================

# Show DuckDB setup status
duck-status() {
  echo "🦆 DuckDB Setup Status"
  echo "====================="
  echo ""

  echo "📁 Current directory: $(pwd)"

  if [[ -f ".duckdb_setup.sql" ]]; then
    echo "✅ Data setup: .duckdb_setup.sql"
    local table_count=$(grep -c "CREATE VIEW" .duckdb_setup.sql 2>/dev/null || echo "0")
    echo "📊 Tables: $table_count"
  else
    echo "❌ No data setup found"
    echo "💡 Run: duck setup"
  fi

  if [[ -f "$HOME/.duckdbrc" ]]; then
    echo "✅ Global config: ~/.duckdbrc"
  else
    echo "❌ No global config: ~/.duckdbrc"
    echo "💡 Create global config for consistent prompt and macros"
  fi

  if [[ -d "./data" ]]; then
    local file_count=$(find ./data -name "*.csv" -o -name "*.json" -o -name "*.parquet" 2>/dev/null | wc -l)
    echo "📊 Data directory: ./data ($file_count supported files)"
  else
    echo "📁 No ./data directory"
  fi

  echo ""
  echo "🚀 Recommended: duck (or duck setup if no data loaded)"
}

# Enhanced help
duck-help() {
  echo "🦆 DuckDB Enhanced Commands"
  echo "==========================="
  echo ""
  echo "Basic:"
  echo "  duck              - Start DuckDB with data (if setup exists)"
  echo "  duck clean        - Start fresh DuckDB (global config only)"
  echo "  duck setup        - Generate/refresh data setup from ./data/"
  echo "  duck info         - Show available tables"
  echo "  duck status       - Show current setup status"
  echo ""
  echo "Table Operations:"
  echo "  duck-tables       - List all tables"
  echo "  duck-peek table [rows] - Preview table data (colorized)"
  echo "  duck-stats table  - Quick table statistics"
  echo ""
  echo "Advanced:"
  echo "  duckdb-pretty 'query'   - Run query with colorized CSV output"
  echo "  duck-export fmt 'query' file - Export: csv, json, md"
  echo "  duck-interactive        - fzf-powered table explorer"
  echo ""
  echo "Integration:"
  echo "  duck-tmux 'query' [name] - Run query in new tmux window"
  echo "  duck-copy 'query' [fmt]  - Copy results to clipboard"
  echo ""
  echo "Examples:"
  echo "  duck setup                   # First time in project"
  echo "  duck                         # Start with data loaded"
  echo "  duck-peek sales_data 5       # Preview table"
  echo "  duckdb-pretty 'SELECT COUNT(*) FROM users'"
  echo "  duck-export csv 'SELECT * FROM products' products.csv"
}

# ============================================================================
# COMPLETIONS
# ============================================================================

# Add completion for table names
if command -v compdef >/dev/null 2>&1; then
  _duck_table_completion() {
    local -a tables
    if [[ -f ".duckdb_setup.sql" ]]; then
      tables=($(grep -o 'CREATE VIEW [a-zA-Z0-9_]* AS' .duckdb_setup.sql 2>/dev/null | sed 's/CREATE VIEW //' | sed 's/ AS//'))
    fi
    _describe 'tables' tables
  }

  compdef _duck_table_completion duck-peek duck-stats
fi
