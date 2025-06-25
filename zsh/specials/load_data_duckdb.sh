#!/bin/bash
# DuckDB Data Loader - Setup Generator with Smart Caching
# Location: $DOTFILES/zsh/specials/load_data_duckdb.sh

DATA_DIR="./data"
SETUP_FILE=".duckdb_setup.sql"
FORCE_REFRESH=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--force)
            FORCE_REFRESH=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [--force|-f] [--help|-h]"
            echo ""
            echo "DuckDB Data Setup Generator with Smart Caching"
            echo ""
            echo "Options:"
            echo "  --force, -f    Force regenerate setup file even if it exists"
            echo "  --help, -h     Show this help message"
            echo ""
            echo "What it does:"
            echo "  1. Scans ./data/ directory for supported files"
            echo "  2. Generates .duckdb_setup.sql with CREATE VIEW statements"
            echo "  3. Caches results - only rescans when data files change"
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

echo "🦆 DuckDB Data Setup"
echo "==================="

# Check if DuckDB is available
if ! command -v duckdb >/dev/null 2>&1; then
    echo "❌ DuckDB not found"
    echo "💡 Install: https://duckdb.org/docs/installation/"
    echo "   - Ubuntu/Debian: apt install duckdb"
    echo "   - macOS: brew install duckdb"
    echo "   - Or download from: https://duckdb.org/docs/installation/"
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

# Check if setup file exists and is up-to-date (unless forced)
if [[ -f "$SETUP_FILE" && "$FORCE_REFRESH" == "false" ]]; then
    echo "📋 Found existing setup file: $SETUP_FILE"
    
    # Get setup file timestamp
    if command -v stat >/dev/null 2>&1; then
        # Try GNU stat first (Linux), then BSD stat (macOS)
        setup_time=$(stat -c %Y "$SETUP_FILE" 2>/dev/null || stat -f %m "$SETUP_FILE" 2>/dev/null)
    else
        echo "⚠️  Cannot check file timestamps (stat command not found)"
        echo "💡 Use --force to regenerate"
        setup_time=0
    fi
    
    if [[ -n "$setup_time" && "$setup_time" -gt 0 ]]; then
        # Check if any data files are newer than the setup file
        needs_refresh=false
        newest_data_file=""
        newest_data_time=0
        file_count=0
        
        while IFS= read -r -d '' file; do
            file_count=$((file_count + 1))
            
            # Get file timestamp
            file_time=$(stat -c %Y "$file" 2>/dev/null || stat -f %m "$file" 2>/dev/null)
            
            if [[ -n "$file_time" ]]; then
                # Track newest file for reporting
                if [[ $file_time -gt $newest_data_time ]]; then
                    newest_data_time=$file_time
                    newest_data_file="$file"
                fi
                
                # Check if this file is newer than setup
                if [[ $file_time -gt $setup_time ]]; then
                    needs_refresh=true
                fi
            fi
        done < <(find "$DATA_DIR" -type f \( \
            -name "*.csv" -o -name "*.tsv" -o \
            -name "*.json" -o -name "*.jsonl" -o -name "*.ndjson" -o \
            -name "*.parquet" -o -name "*.pqt" \
            \) -print0 2>/dev/null)
        
        if [[ "$needs_refresh" == "false" ]]; then
            echo "✅ Setup file is up-to-date (newer than all $file_count data files)"
            echo ""
            echo "📊 Available tables:"
            if grep -q "CREATE VIEW" "$SETUP_FILE" 2>/dev/null; then
                grep -o 'CREATE VIEW [a-zA-Z0-9_]* AS' "$SETUP_FILE" | sed 's/CREATE VIEW /  • /' | sed 's/ AS//' 2>/dev/null
            else
                echo "  (no tables found in setup file)"
            fi
            echo ""
            echo "🚀 Ready! Use these commands:"
            echo "  duckdb -init .duckdb_setup.sql   # Start with data loaded"  
            echo "  duckdb                           # Start fresh DuckDB"
            echo ""
            echo "💡 To force refresh: $0 --force"
            exit 0
        else
            echo "⚠️  Data files have changed since last setup, refreshing..."
            if [[ -n "$newest_data_file" ]]; then
                echo "💡 Newest file: $(basename "$newest_data_file")"
            fi
            echo ""
        fi
    else
        echo "⚠️  Could not check timestamps, regenerating setup..."
        echo ""
    fi
fi

echo "📁 Scanning $DATA_DIR for data files..."

# Find supported files
declare -a data_files=()
declare -a table_names=()

# Scan for supported formats
while IFS= read -r -d '' file; do
    # Skip hidden files and common temp files
    [[ "$(basename "$file")" == .* ]] && continue
    [[ "$(basename "$file")" == *"~" ]] && continue
    [[ "$(basename "$file")" == *".tmp" ]] && continue
    [[ "$(basename "$file")" == *".temp" ]] && continue
    
    # Get relative path from data dir and clean it
    rel_path="${file#$DATA_DIR/}"
    rel_path="${rel_path#./}"  # Remove leading ./ if present
    
    # Create clean table name
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
    echo "💡 Add some data files and run again"
    echo ""
    echo "📋 To start DuckDB manually: duckdb"
    exit 0
fi

echo "✅ Found ${#data_files[@]} data file(s)"

# Backup existing setup file if it exists
if [[ -f "$SETUP_FILE" ]]; then
    cp "$SETUP_FILE" "${SETUP_FILE}.backup"
    echo "💾 Backed up existing setup to: ${SETUP_FILE}.backup"
fi

# Generate setup SQL file header
cat > "$SETUP_FILE" << EOF
-- DuckDB Auto-generated Setup
-- Generated: $(date)
-- Data directory: $DATA_DIR
-- Files scanned: ${#data_files[@]}
-- Command: $0 $*

.print ""
.print "🦆 Loading data views..."
.print ""

EOF

# Generate view creation statements
echo "📋 Creating table views:"
for i in "${!data_files[@]}"; do
    file="${data_files[$i]}"
    table="${table_names[$i]}"
    
    echo "  • $table → $file"
    
    # Add to SQL file with error handling
    cat >> "$SETUP_FILE" << EOF
-- Table: $table (from $file)
.print "  📊 Loading: $table"
CREATE OR REPLACE VIEW $table AS SELECT * FROM '$file';

EOF
done

# Add helper section to SQL file
cat >> "$SETUP_FILE" << 'EOF'

.print ""
.print "🦆 DuckDB Environment Ready!"
.print "============================"
.print ""
.print "📊 Available tables:"
.tables
.print ""
.print "💡 Quick commands:"
.print "  .tables                      - List all tables" 
.print "  .schema table_name           - Show table structure"
.print "  DESCRIBE table_name;         - Show column info"
.print "  SELECT COUNT(*) FROM table_name; - Row count"
.print "  SELECT * FROM table_name LIMIT 5; - Preview data"
.print ""
.print "🔍 Example queries:"
.print "  SELECT * FROM table_name WHERE column > 100;"
.print "  SELECT column, COUNT(*) FROM table_name GROUP BY column;"
.print "  SELECT * FROM table1 JOIN table2 ON table1.id = table2.id;"
.print ""
.print "💡 Exit DuckDB: .quit or Ctrl+D"
.print ""

EOF

echo ""
echo "✅ Setup file created: $SETUP_FILE"
echo "💾 Cached for future runs (will auto-refresh if data changes)"
echo ""
echo "🚀 Ready! Use these commands:"
echo "  duckdb -init .duckdb_setup.sql   # Start with data loaded"
echo "  duckdb                           # Start fresh DuckDB" 
echo ""

# Show what tables are available
echo "📊 Tables available:"
for i in "${!table_names[@]}"; do
    echo "  • ${table_names[$i]} (${data_files[$i]})"
done

echo ""
echo "💡 Next time you run this script, it will use the cached setup"
echo "💡 To force refresh: $0 --force"
echo "💡 Backup created: ${SETUP_FILE}.backup"
