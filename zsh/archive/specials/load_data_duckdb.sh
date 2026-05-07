#!/bin/bash
# DuckDB Data Loader - Robust Version with Direct Config Embedding
# Location: $DOTFILES/zsh/specials/load_data_duckdb.sh

DATA_DIR="./data"
SETUP_FILE=".duckdb_setup.sql"
FORCE_REFRESH=false

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    -f | --force)
      FORCE_REFRESH=true
      shift
      ;;
    -h | --help)
      echo "Usage: $0 [--force|-f] [--help|-h]"
      echo ""
      echo "DuckDB Data Setup Generator with Robust Global Config Support"
      echo ""
      echo "Options:"
      echo "  --force, -f    Force regenerate setup file even if it exists"
      echo "  --help, -h     Show this help message"
      echo ""
      echo "What it does:"
      echo "  1. DIRECTLY embeds your ~/.duckdbrc content (more reliable)"
      echo "  2. Scans ./data/ directory for supported files"
      echo "  3. Generates .duckdb_setup.sql with CREATE VIEW statements"
      echo "  4. Caches results - only rescans when files change"
      echo ""
      echo "Supported formats: CSV, TSV, JSON, JSONL, Parquet"
      exit 0
      ;;
    *)
      echo "❌ Unknown option: $1"
      echo "💡 Use --help for usage information"
      exit 1
      ;;
  esac
done

echo "🦆 DuckDB Data Setup (Robust Version)"
echo "====================================="

# Check if DuckDB is available
if ! command -v duckdb >/dev/null 2>&1; then
  echo "❌ DuckDB not found"
  echo "💡 Install: https://duckdb.org/docs/installation/"
  exit 1
fi

# Check if data directory exists
if [[ ! -d "$DATA_DIR" ]]; then
  echo "❌ No ./data/ directory found"
  echo "💡 Create ./data/ and add your data files"
  echo "💡 Supported formats: CSV, TSV, JSON, JSONL, Parquet"
  echo ""
  echo "📋 To start DuckDB manually: duckdb"
  exit 0
fi

# Check global config
GLOBAL_CONFIG="$HOME/.duckdbrc"
if [[ -f "$GLOBAL_CONFIG" ]]; then
  echo "✅ Found global config: $GLOBAL_CONFIG"
  echo "📏 Size: $(ls -lh "$GLOBAL_CONFIG" | awk '{print $5}')"
else
  echo "💡 No global config found at: $GLOBAL_CONFIG"
  echo "💡 DuckDB will use default settings"
fi

# Check if setup file exists and is up-to-date (unless forced)
if [[ -f "$SETUP_FILE" && "$FORCE_REFRESH" == "false" ]]; then
  echo "📋 Found existing setup file: $SETUP_FILE"

  # Get setup file timestamp
  if command -v stat >/dev/null 2>&1; then
    setup_time=$(stat -c %Y "$SETUP_FILE" 2>/dev/null || stat -f %m "$SETUP_FILE" 2>/dev/null)
  else
    echo "⚠️  Cannot check file timestamps, forcing refresh..."
    FORCE_REFRESH=true
    setup_time=0
  fi

  if [[ -n "$setup_time" && "$setup_time" -gt 0 && "$FORCE_REFRESH" == "false" ]]; then
    # Check if any data files are newer than the setup file
    needs_refresh=false
    file_count=0

    while IFS= read -r -d '' file; do
      file_count=$((file_count + 1))
      file_time=$(stat -c %Y "$file" 2>/dev/null || stat -f %m "$file" 2>/dev/null)

      if [[ -n "$file_time" && "$file_time" -gt "$setup_time" ]]; then
        needs_refresh=true
        echo "💡 Data file changed: $(basename "$file")"
        break
      fi
    done < <(find "$DATA_DIR" -type f \( \
      -name "*.csv" -o -name "*.tsv" -o \
      -name "*.json" -o -name "*.jsonl" -o -name "*.ndjson" -o \
      -name "*.parquet" -o -name "*.pqt" \
      \) -print0 2>/dev/null)

    # Also check if global config changed
    if [[ -f "$GLOBAL_CONFIG" ]]; then
      duckdbrc_time=$(stat -c %Y "$GLOBAL_CONFIG" 2>/dev/null || stat -f %m "$GLOBAL_CONFIG" 2>/dev/null)
      if [[ -n "$duckdbrc_time" && "$duckdbrc_time" -gt "$setup_time" ]]; then
        needs_refresh=true
        echo "💡 Global config (~/.duckdbrc) has changed"
      fi
    fi

    if [[ "$needs_refresh" == "false" ]]; then
      echo "✅ Setup file is up-to-date"
      echo ""
      echo "📊 Available tables:"
      if grep -q "CREATE VIEW" "$SETUP_FILE" 2>/dev/null; then
        grep -o 'CREATE VIEW [a-zA-Z0-9_]* AS' "$SETUP_FILE" | sed 's/CREATE VIEW /  • /' | sed 's/ AS//' 2>/dev/null
      fi
      echo ""
      echo "🚀 Ready! Use: duck"
      echo "💡 To force refresh: $0 --force"
      exit 0
    else
      echo "⚠️  Files have changed, refreshing..."
    fi
  fi
fi

echo "📁 Scanning $DATA_DIR for data files..."

# Find supported files
declare -a data_files=()
declare -a table_names=()

while IFS= read -r -d '' file; do
  # Skip hidden files and temp files
  [[ "$(basename "$file")" == .* ]] && continue
  [[ "$(basename "$file")" == *"~" ]] && continue
  [[ "$(basename "$file")" == *".tmp" ]] && continue

  # Get relative path and create clean table name
  rel_path="${file#$DATA_DIR/}"
  rel_path="${rel_path#./}"

  table_name=$(echo "$rel_path" | sed 's/[^a-zA-Z0-9_]/_/g' | sed 's/__*/_/g' | sed 's/^_\|_$//g')

  # Ensure table name doesn't start with number
  if [[ "$table_name" =~ ^[0-9] ]]; then
    table_name="data_$table_name"
  fi

  # Ensure table name is not empty
  if [[ -z "$table_name" ]]; then
    table_name="data_$(basename "$file" | sed 's/[^a-zA-Z0-9_]/_/g')"
  fi

  data_files+=("$file")
  table_names+=("$table_name")

done < <(find "$DATA_DIR" -type f \( \
  -name "*.csv" -o -name "*.tsv" -o \
  -name "*.json" -o -name "*.jsonl" -o -name "*.ndjson" -o \
  -name "*.parquet" -o -name "*.pqt" \
  \) -print0 2>/dev/null)

if [[ ${#data_files[@]} -eq 0 ]]; then
  echo "❌ No supported data files found in $DATA_DIR"
  echo "💡 Supported formats: CSV, TSV, JSON, JSONL, Parquet"
  exit 0
fi

echo "✅ Found ${#data_files[@]} data file(s)"

# Backup existing setup file if it exists
if [[ -f "$SETUP_FILE" ]]; then
  cp "$SETUP_FILE" "${SETUP_FILE}.backup"
  echo "💾 Backed up existing setup to: ${SETUP_FILE}.backup"
fi

# Start generating the setup file
echo "📝 Generating setup file..."

# Create the setup file with header
cat >"$SETUP_FILE" <<EOF
-- DuckDB Auto-generated Setup with Embedded Global Config
-- Generated: $(date)
-- Data directory: $DATA_DIR
-- Files scanned: ${#data_files[@]}
-- Global config: $([[ -f "$GLOBAL_CONFIG" ]] && echo "embedded directly" || echo "not found")
-- Command: $0 $*

EOF

# Embed global config content directly (more reliable than .read)
if [[ -f "$GLOBAL_CONFIG" ]]; then
  echo "🔧 Embedding global config content..."
  cat >>"$SETUP_FILE" <<'EOF'
-- === EMBEDDED GLOBAL CONFIG (from ~/.duckdbrc) ===
.print "🔧 Loading embedded global config..."

EOF

  # Directly include the content of ~/.duckdbrc
  cat "$GLOBAL_CONFIG" >>"$SETUP_FILE"

  cat >>"$SETUP_FILE" <<'EOF'

-- === END GLOBAL CONFIG ===
.print "✅ Global config loaded"
.print ""

EOF
else
  cat >>"$SETUP_FILE" <<'EOF'
-- === NO GLOBAL CONFIG FOUND ===
.print "💡 No ~/.duckdbrc found, using DuckDB defaults"
.print ""

EOF
fi

# Add data loading section
cat >>"$SETUP_FILE" <<'EOF'
.print "🦆 Loading project data views..."
.print ""

EOF

# Generate view creation statements
echo "📋 Creating table views:"
for i in "${!data_files[@]}"; do
  file="${data_files[$i]}"
  table="${table_names[$i]}"

  echo "  • $table → $file"

  cat >>"$SETUP_FILE" <<EOF
-- Table: $table (from $file)
.print "  📊 Loading: $table"
CREATE OR REPLACE VIEW $table AS SELECT * FROM '$file';

EOF
done

# Add final section
cat >>"$SETUP_FILE" <<'EOF'
.print ""
.print "🦆 DuckDB Environment Ready!"
.print "============================"
.print "✅ Global config: embedded"
.print "✅ Project data: loaded as views"
.print ""
.print "📊 Available tables:"
.tables
.print ""
.print "💡 Quick commands:"
.print "  .tables                           - List all tables" 
.print "  .schema table_name                - Show table structure"
.print "  DESCRIBE table_name;              - Show column info"
.print "  SELECT COUNT(*) FROM table_name;  - Row count"
.print "  SELECT * FROM table_name LIMIT 5; - Preview data"
.print ""
.print "🔍 Example queries:"
.print "  SELECT * FROM table_name WHERE column > 100;"
.print "  SELECT column, COUNT(*) FROM table_name GROUP BY column;"
.print ""
.print "💡 Exit DuckDB: .quit or Ctrl+D"
.print ""
EOF

echo ""
echo "✅ Setup file created: $SETUP_FILE"
if [[ -f "$GLOBAL_CONFIG" ]]; then
  echo "🔧 Global config content embedded directly (more reliable)"
else
  echo "💡 No global config to embed"
fi
echo "💾 Cached for future runs"
echo ""

# Show what tables are available
echo "📊 Tables available:"
for i in "${!table_names[@]}"; do
  echo "  • ${table_names[$i]} (${data_files[$i]})"
done

echo ""
echo "🚀 Test it now:"
echo "  duckdb -init .duckdb_setup.sql"
echo ""
echo "💡 Or use: duck"
