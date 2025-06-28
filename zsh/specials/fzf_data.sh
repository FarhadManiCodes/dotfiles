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
# Enhanced fdata-preview with Phase 3 integration

fdata-preview() {
  local preview_window="${1:-down:75%:wrap}"
  local multi_mode="false"

  if [[ "$1" == "--multi" ]]; then
    multi_mode="true"
    preview_window="${2:-down:75%:wrap}"
  fi

  # Set up context environment variables for integration
  export FDATA_SOURCE="fdata-preview"
  export FDATA_WORKING_DIR="$PWD"
  export FDATA_SELECTION_MODE="$multi_mode"
  if [[ -n "$TMUX" ]]; then
    export FDATA_TMUX_SESSION="$(tmux display-message -p '#S' 2>/dev/null)"
    export FDATA_TMUX_WINDOW="$(tmux display-message -p '#W' 2>/dev/null)"
  fi

  local header_text='📊 Data Browser | Enter: edit | Ctrl+D: cd | Ctrl+V: copy | Ctrl+O: folder | Ctrl+R: profile'

  # Change header for multi mode
  if [[ "$multi_mode" == "true" ]]; then
    header_text='📊 Data Browser (Multi-Select) | Tab: select | Enter: edit | Ctrl+D: cd | Ctrl+R: profile'
  fi

  # Base bindings (always present)
  local bindings=(
    'ctrl-d:execute(cd $(dirname {}) && pwd)+abort'
    'ctrl-v:execute(echo {} | wl-copy 2>/dev/null || echo {} | xclip -sel c 2>/dev/null)'
    'ctrl-o:execute(xdg-open $(dirname {}) 2>/dev/null &)'
  )

  # Add profile selection binding based on mode
  if [[ "$multi_mode" == "true" ]]; then
    # Multi-select mode: pass all selected files to fdata-profile
    bindings+=('ctrl-r:execute(
      if [[ "{+}" != "{}" ]]; then
        echo "🔄 Running profiler selection for selected files..."
        fdata-profile {+} < /dev/tty > /dev/tty
      else
        echo "📄 Running profiler selection for single file..."
        fdata-profile {} < /dev/tty > /dev/tty
      fi
      echo ""
      echo "Press Enter to return to file browser..."
      read
    )+abort')
  else
    # Single-select mode: pass single file to fdata-profile
    bindings+=('ctrl-r:execute(
      echo "📄 Running profiler selection for: $(basename {})"
      fdata-profile {} < /dev/tty > /dev/tty
      echo ""
      echo "Press Enter to return to file browser..."
      read
    )+abort')
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

  # Clean up environment variables
  unset FDATA_SOURCE FDATA_WORKING_DIR FDATA_SELECTION_MODE FDATA_TMUX_SESSION FDATA_TMUX_WINDOW
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

# =============================================================================
# Phase 2: Configuration System for Data Profiling
# Location: Add to $DOTFILES/zsh/specials/fzf_data.sh
# =============================================================================

# Global configuration arrays (populated by load-profiling-config)
typeset -A PROFILING_REPORTS      # report_name -> description
typeset -A PROFILING_FILE_TYPES   # report_name -> "csv,json,parquet"
typeset -A PROFILING_BATCH_SUITES # suite_name -> "report1,report2,report3"
typeset -A PROFILING_SETTINGS     # setting_name -> value

# Global file type to reports mapping
typeset -A FILE_TYPE_PROFILES     # file_type -> "report1,report2,report3"

# =============================================================================
# CONFIGURATION LOADING FUNCTIONS
# =============================================================================

# Load configuration with cascade: tools -> user -> defaults
load-profiling-config() {
  echo "🔧 Loading profiling configuration..."
  echo "📋 Priority: Tools config > User config > Built-in defaults"
  
  # Check if yq is available
  if ! command -v yq >/dev/null 2>&1; then
    echo "❌ Error: yq not found"
    echo "📦 Install options:"
    echo "  • Ubuntu/Debian: sudo apt install yq"
    echo "  • macOS: brew install yq"
    echo "  • Manual: https://github.com/mikefarah/yq/releases"
    return 1
  fi
  
  # Clear existing configuration
  PROFILING_REPORTS=()
  PROFILING_FILE_TYPES=()
  PROFILING_BATCH_SUITES=()
  PROFILING_SETTINGS=()
  FILE_TYPE_PROFILES=()
  
  # Load defaults first (lowest priority)
  echo "🔧 Loading built-in defaults..."
  _load_default_config
  
  # Try to load user config (medium priority)
  local user_config="$HOME/.config/profiling/config.yml"
  if [[ -f "$user_config" ]]; then
    echo "✅ Loading user config (overrides defaults): $user_config"
    _parse_config_file "$user_config"
  else
    echo "💡 No user config found: $user_config"
  fi
  
  # Try to load centralized tools config (highest priority)
  local profiling_dir="${PROFILING_SETTINGS[profiling_dir]:-$HOME/projects/profiling}"
  local tools_config="$profiling_dir/config.yml"
  if [[ -f "$tools_config" ]]; then
    echo "✅ Loading tools config (highest priority): $tools_config"
    _parse_config_file "$tools_config"
  else
    echo "💡 No tools config found: $tools_config"
    echo "💡 Expected location: \$PROFILING_DIR/config.yml"
  fi
  
  # Build file type to profiles mapping
  _build_file_type_mapping
  
  echo "✅ Configuration loaded successfully"
  echo "   Reports: ${#PROFILING_REPORTS[@]}"
  echo "   Batch suites: ${#PROFILING_BATCH_SUITES[@]}"
  echo "   File types: ${#FILE_TYPE_PROFILES[@]}"
  echo "   Tools directory: $profiling_dir"
}

# Load built-in default configuration
_load_default_config() {
  echo "🔧 Loading default configuration..."
  
  # Default reports
  # PROFILING_REPORTS[quick_health]="Fast health check with basic stats"
  # PROFILING_REPORTS[column_drill]="Detailed column analysis and profiling"
  # PROFILING_REPORTS[pii_scanner]="Scan for personally identifiable information"
  # PROFILING_REPORTS[schema_validation]="Validate data schema and structure"
  # PROFILING_REPORTS[structure_analysis]="Analyze JSON/nested data structure"
  
  # Test dummy profilers (for Phase 4)
  # PROFILING_REPORTS[line_count]="Count lines in file (fast test)"
  # PROFILING_REPORTS[file_size]="Show file size and basic info"
  # PROFILING_REPORTS[basic_stats]="Basic statistics (rows, columns, types)"
  # PROFILING_REPORTS[column_types]="Detect and show column data types"
  
  # Default file type associations
  # PROFILING_FILE_TYPES[quick_health]="csv,tsv,parquet"
  # PROFILING_FILE_TYPES[column_drill]="csv,tsv,parquet"
  # PROFILING_FILE_TYPES[pii_scanner]="csv,tsv,parquet"
  # PROFILING_FILE_TYPES[schema_validation]="json,jsonl,yaml,yml"
  # PROFILING_FILE_TYPES[structure_analysis]="json,jsonl"
  
  # Test profiler file types
  # PROFILING_FILE_TYPES[line_count]="csv,tsv,json,jsonl,yaml,yml"
  # PROFILING_FILE_TYPES[file_size]="csv,tsv,json,jsonl,parquet,xlsx,xls,pkl,pickle,yaml,yml"
  # PROFILING_FILE_TYPES[basic_stats]="csv,tsv"
  # PROFILING_FILE_TYPES[column_types]="csv,tsv"
  
  # Default batch suites
  # PROFILING_BATCH_SUITES[health_suite]="quick_health,pii_scanner"
  # PROFILING_BATCH_SUITES[test_suite]="line_count,file_size,basic_stats"
  # PROFILING_BATCH_SUITES[full_analysis]="quick_health,column_drill,pii_scanner"
  # PROFILING_BATCH_SUITES[data_discovery]="schema_validation,structure_analysis"
  
  # Default settings
  PROFILING_SETTINGS[profiling_dir]="$HOME/projects/profiling"
  PROFILING_SETTINGS[results_dir]="/tmp/profiling_results"
  PROFILING_SETTINGS[default_sample_size]="10000"
  PROFILING_SETTINGS[batch_session_prefix]="profiling-batch"
}

# YAML parser using yq
_parse_config_file() {
  local config_file="$1"
  
  if [[ ! -f "$config_file" ]]; then
    echo "⚠️  Config file not found: $config_file"
    return 1
  fi
  
  echo "📄 Parsing: $config_file"
  
  # Parse file_extensions section
  if yq eval '.file_extensions' "$config_file" >/dev/null 2>&1; then
    echo "  🔍 Parsing file_extensions..."
    local -a extension_types
    extension_types=($(yq eval '.file_extensions | keys | .[]' "$config_file" 2>/dev/null))
    for file_type in "${extension_types[@]}"; do
      local profiles=$(yq eval ".file_extensions.$file_type | join(\",\")" "$config_file" 2>/dev/null)
      if [[ -n "$profiles" && "$profiles" != "null" ]]; then
        FILE_TYPE_PROFILES[$file_type]="$profiles"
      fi
    done
  fi
  
  # Parse reports section (FIXED - renamed variable)
  if yq eval '.reports' "$config_file" >/dev/null 2>&1; then
    echo "  📋 Parsing reports..."
    local -a report_names
    report_names=($(yq eval '.reports | keys | .[]' "$config_file" 2>/dev/null))
    for report in "${report_names[@]}"; do
      # Get description
      local description=$(yq eval ".reports.$report.description" "$config_file" 2>/dev/null)
      if [[ -n "$description" && "$description" != "null" ]]; then
        PROFILING_REPORTS[$report]="$description"
      fi
      
      # Get file types for this report
      local report_file_types=$(yq eval ".reports.$report.file_types | join(\",\")" "$config_file" 2>/dev/null)
      if [[ -n "$report_file_types" && "$report_file_types" != "null" ]]; then
        PROFILING_FILE_TYPES[$report]="$report_file_types"
      fi
    done
  fi
  
  # Parse batch_profiles section (FIXED - renamed variable)
  if yq eval '.batch_profiles' "$config_file" >/dev/null 2>&1; then
    echo "  📦 Parsing batch_profiles..."
    local -a batch_suite_names
    batch_suite_names=($(yq eval '.batch_profiles | keys | .[]' "$config_file" 2>/dev/null))
    for suite in "${batch_suite_names[@]}"; do
      local suite_reports=$(yq eval ".batch_profiles.$suite.reports | join(\",\")" "$config_file" 2>/dev/null)
      if [[ -n "$suite_reports" && "$suite_reports" != "null" ]]; then
        PROFILING_BATCH_SUITES[$suite]="$suite_reports"
      fi
    done
  fi
  
  # Parse settings section (SIMPLE yq approach)
  if yq eval '.settings' "$config_file" >/dev/null 2>&1; then
    echo "  ⚙️  Parsing settings..."
    
    # Use yq to flatten all scalar values into key=value format
    while IFS='=' read -r key value; do
      [[ -n "$key" && -n "$value" ]] || continue
      
      # Expand environment variables safely
      if [[ "$value" =~ \$ ]]; then
        value=$(eval echo "\"$value\"" 2>/dev/null) || value="$value"
      fi
      
      PROFILING_SETTINGS[$key]="$value"
      echo "    ✅ $key = $value"
      
    done < <(yq eval '.settings | paths(scalars) as $p | {"key": ($p | join("_")), "value": getpath($p)} | .key + "=" + (.value | tostring)' "$config_file" 2>/dev/null)
  fi
  }

# Build file type to profiles mapping from individual report file types
_build_file_type_mapping() {
  echo "🔗 Building file type mappings..."
  
  # Clear existing mapping
  FILE_TYPE_PROFILES=()
  
  # For each report, add it to the file types it supports
  for report in "${(@k)PROFILING_FILE_TYPES}"; do
    local file_types="${PROFILING_FILE_TYPES[$report]}"
    # Split on commas and spaces
    local types_array=(${(s:,:)file_types})
    for file_type in "${types_array[@]}"; do
      # Remove whitespace
      file_type=$(echo "$file_type" | tr -d ' ')
      # Add report to this file type's list
      if [[ -n "${FILE_TYPE_PROFILES[$file_type]}" ]]; then
        FILE_TYPE_PROFILES[$file_type]="${FILE_TYPE_PROFILES[$file_type]},$report"
      else
        FILE_TYPE_PROFILES[$file_type]="$report"
      fi
    done
  done
}

# =============================================================================
# PROFILE DISCOVERY AND FILTERING
# =============================================================================

# Get available profiles for given file types
get-available-profiles() {
  local file_list="$1"  # Colon-separated list like "file1.csv:file2.json"
  
  if [[ -z "$file_list" ]]; then
    echo "Usage: get-available-profiles file1.csv:file2.json"
    return 1
  fi
  
  # Extract unique file extensions
  local extensions=()
  local files=(${(s.:.)file_list})
  for file in "${files[@]}"; do
    [[ -n "$file" ]] || continue
    local ext="${file##*.}"
    ext=$(echo "$ext" | tr '[:upper:]' '[:lower:]')
    # Add if not already present
    if [[ ! " ${extensions[@]} " =~ " ${ext} " ]]; then
      extensions+=("$ext")
    fi
  done
  
  echo "🔍 File types detected: ${(j:, :)extensions}"
  
  # Collect all available profiles for these file types
  local available_profiles=()
  for ext in "${extensions[@]}"; do
    if [[ -n "${FILE_TYPE_PROFILES[$ext]}" ]]; then
      local profiles=(${(s:,:)FILE_TYPE_PROFILES[$ext]})
      for profile in "${profiles[@]}"; do
        # Add if not already present
        if [[ ! " ${available_profiles[@]} " =~ " ${profile} " ]]; then
          available_profiles+=("$profile")
        fi
      done
    fi
  done
  
  echo "📋 Available profiles: ${(j:, :)available_profiles}"
  
  # Return the profiles (space-separated for easy iteration)
  printf '%s\n' "${available_profiles[@]}"
}

# Get available batch suites for given file types
get-available-batch-suites() {
  local file_list="$1"
  
  if [[ -z "$file_list" ]]; then
    echo "Usage: get-available-batch-suites file1.csv:file2.json"
    return 1
  fi
  
  # Get available individual profiles for these file types
  local available_profiles=($(get-available-profiles "$file_list" | tail -n +3))  # Skip the echo lines
  
  echo "🔍 Checking batch suites against available profiles..."
  
  # Check each batch suite
  local available_suites=()
  for suite in "${(@k)PROFILING_BATCH_SUITES}"; do
    local suite_profiles=(${(s:,:)PROFILING_BATCH_SUITES[$suite]})
    local has_compatible=false
    
    # Check if at least one profile in the suite is compatible
    for suite_profile in "${suite_profiles[@]}"; do
      if [[ " ${available_profiles[@]} " =~ " ${suite_profile} " ]]; then
        has_compatible=true
        break
      fi
    done
    
    if [[ "$has_compatible" == "true" ]]; then
      available_suites+=("$suite")
    fi
  done
  
  echo "📦 Available batch suites: ${(j:, :)available_suites}"
  
  # Return the suites
  printf '%s\n' "${available_suites[@]}"
}

# =============================================================================
# DEBUG AND STATUS FUNCTIONS
# =============================================================================

# Show current configuration status
show-profiling-config() {
  echo "🔧 Profiling Configuration Status"
  echo "================================="
  echo ""
  
  # Check if configuration is loaded
  if [[ ${#PROFILING_REPORTS[@]} -eq 0 ]]; then
    echo "❌ Configuration not loaded"
    echo "💡 Run: load-profiling-config"
    return 1
  fi
  
  echo "📋 Reports (${#PROFILING_REPORTS[@]}):"
  for report in "${(@k)PROFILING_REPORTS}"; do
    local file_types="${PROFILING_FILE_TYPES[$report]:-unknown}"
    echo "  • $report: ${PROFILING_REPORTS[$report]}"
    echo "    📄 File types: $file_types"
  done
  
  echo ""
  echo "📦 Batch Suites (${#PROFILING_BATCH_SUITES[@]}):"
  for suite in "${(@k)PROFILING_BATCH_SUITES}"; do
    echo "  • $suite: ${PROFILING_BATCH_SUITES[$suite]}"
  done
  
  echo ""
  echo "📁 File Type Mappings (${#FILE_TYPE_PROFILES[@]}):"
  for file_type in "${(@k)FILE_TYPE_PROFILES}"; do
    echo "  • $file_type: ${FILE_TYPE_PROFILES[$file_type]}"
  done
  
  echo ""
  echo "⚙️  Settings:"
  for setting in "${(@k)PROFILING_SETTINGS}"; do
    echo "  • $setting: ${PROFILING_SETTINGS[$setting]}"
  done
}

# Test configuration with sample files
test-profiling-config() {
  echo "🧪 Testing Configuration System"
  echo "==============================="
  echo ""
  
  # Load configuration
  load-profiling-config
  echo ""
  
  # Test file type detection
  echo "📊 Testing file type detection:"
  local test_files="data.csv:info.json:records.parquet"
  echo "Test files: $test_files"
  echo ""
  
  echo "Available profiles:"
  get-available-profiles "$test_files"
  echo ""
  
  echo "Available batch suites:"
  get-available-batch-suites "$test_files"
  echo ""
  
  # Show configuration status
  show-profiling-config
}

# =============================================================================
# ALIASES AND HELPERS
# =============================================================================

alias config-profiling='load-profiling-config'
alias show-config='show-profiling-config'
alias test-config='test-profiling-config'

# =============================================================================
# Phase 3: Profile Selection and Discovery
# Location: Add to $DOTFILES/zsh/specials/fzf_data.sh
# =============================================================================

# Global arrays for discovered profiles (populated by discover_profiles)
typeset -A DISCOVERED_PROFILES        # profiler_name -> "/path/to/file.py"
typeset -A PROFILE_METADATA          # profiler_name -> "config_desc|file_types|docstring_preview"

# =============================================================================
# PROFILE DISCOVERY FUNCTIONS
# =============================================================================

# Generate profile name from file path
generate_profile_name() {
  local py_file="$1"
  local reports_dir="$2"
  
  # Get relative path from reports directory
  local rel_path="${py_file#$reports_dir/}"
  
  # Remove .py extension
  rel_path="${rel_path%.py}"
  
  # Replace directory separators and hyphens with underscores
  local profile_name=$(echo "$rel_path" | sed 's|/|_|g' | sed 's|-|_|g')
  
  echo "$profile_name"
}

# Extract docstring from Python file (on-demand)
extract_docstring() {
  local py_file="$1"
  local max_lines="${2:-5}"  # Limit for preview
  
  local docstring=$(python -c "
import ast
try:
    with open('$py_file', 'r') as f:
        tree = ast.parse(f.read())
    docstring = ast.get_docstring(tree)
    if docstring:
        # Take only first few lines for preview
        lines = docstring.split('\n')[:$max_lines]
        print('\n'.join(lines))
except Exception:
    pass
" 2>/dev/null)
  
  echo "$docstring"
}

# Discover all available profiles
discover_profiles() {
  echo "🔍 Discovering available profiles..."
  
  # Clear existing discoveries
  DISCOVERED_PROFILES=()
  PROFILE_METADATA=()
  
  local profiling_dir="${PROFILING_SETTINGS[profiling_dir]}"
  local reports_dir="$profiling_dir/reports"
  
  if [[ ! -d "$reports_dir" ]]; then
    echo "⚠️  Reports directory not found: $reports_dir"
    return 1
  fi
  
  local discovered_count=0
  local config_missing_count=0
  
  # Use fd to find all .py files with no depth limit
  while IFS= read -r -d '' py_file; do
    [[ -f "$py_file" ]] || continue
    
    local profile_name=$(generate_profile_name "$py_file" "$reports_dir")
    DISCOVERED_PROFILES[$profile_name]="$py_file"
    
    # Check if profiler is in config
    local config_desc="${PROFILING_REPORTS[$profile_name]:-}"
    local file_types="${PROFILING_FILE_TYPES[$profile_name]:-all}"
    
    if [[ -z "$config_desc" ]]; then
      echo "  ⚠️  Found profiler '$profile_name' not in config: $py_file"
      config_missing_count=$((config_missing_count + 1))
      config_desc="(No description in config)"
    fi
    
    # Store basic metadata (we'll extract docstring on-demand in preview)
    PROFILE_METADATA[$profile_name]="$config_desc|$file_types"
    
    discovered_count=$((discovered_count + 1))
    
  done < <(fd -e py . "$reports_dir" -0 2>/dev/null)
  
  echo "✅ Discovered $discovered_count profile(s)"
  if [[ $config_missing_count -gt 0 ]]; then
    echo "💡 $config_missing_count profiler(s) not in config - consider adding them"
  fi
  
  return 0
}

# =============================================================================
# COMPATIBILITY FILTERING
# =============================================================================

# Check if profile is compatible with given file types
is_profile_compatible() {
  local profile_name="$1"
  local file_extensions="$2"  # Space-separated list like "csv json"
  
  # Get profile's supported file types
  local profile_file_types="${PROFILING_FILE_TYPES[$profile_name]:-}"
  
  # If no file types specified in config, accepts all files
  if [[ -z "$profile_file_types" || "$profile_file_types" == "all" ]]; then
    return 0
  fi
  
  # Check if at least one file extension matches
  local supported_types=(${(s:,:)profile_file_types})
  for ext in ${(s: :)file_extensions}; do
    for supported in "${supported_types[@]}"; do
      supported=$(echo "$supported" | tr -d ' ')  # Remove whitespace
      if [[ "$ext" == "$supported" ]]; then
        return 0
      fi
    done
  done
  
  return 1
}

# Get compatible profiles for given files
get_compatible_profiles() {
  local files=("$@")
  
  # Extract unique file extensions
  local extensions=()
  for file in "${files[@]}"; do
    local ext="${file##*.}"
    ext=$(echo "$ext" | tr '[:upper:]' '[:lower:]')
    # Add if not already present
    if [[ ! " ${extensions[@]} " =~ " ${ext} " ]]; then
      extensions+=("$ext")
    fi
  done
  
  local extensions_str="${(j: :)extensions}"
  echo "🔍 File types: ${(j:, :)extensions}" >&2
  
  # Find compatible individual profiles
  local compatible_profiles=()
  for profile in "${(@k)DISCOVERED_PROFILES}"; do
    if is_profile_compatible "$profile" "$extensions_str"; then
      compatible_profiles+=("$profile")
    fi
  done
  
  echo "📋 Compatible profiles: ${#compatible_profiles[@]}" >&2
  
  # Return the profiles
  printf '%s\n' "${compatible_profiles[@]}"
}

# Get compatible batch suites for given files  
get_compatible_batch_suites() {
  local files=("$@")
  
  # Get compatible individual profiles first
  local compatible_profiles=($(get_compatible_profiles "$@" 2>/dev/null))
  
  # Check each batch suite
  local compatible_suites=()
  for suite in "${(@k)PROFILING_BATCH_SUITES}"; do
    local suite_reports=(${(s:,:)PROFILING_BATCH_SUITES[$suite]})
    local has_compatible=false
    
    # Check if at least one report in the suite is compatible (union approach)
    for suite_report in "${suite_reports[@]}"; do
      suite_report=$(echo "$suite_report" | tr -d ' ')  # Remove whitespace
      if [[ " ${compatible_profiles[@]} " =~ " ${suite_report} " ]]; then
        has_compatible=true
        break
      fi
    done
    
    if [[ "$has_compatible" == "true" ]]; then
      compatible_suites+=("$suite")
    fi
  done
  
  echo "📦 Compatible batch suites: ${#compatible_suites[@]}" >&2
  
  # Return the suites
  printf '%s\n' "${compatible_suites[@]}"
}

# =============================================================================
# PROFILE SELECTION UI
# =============================================================================

# Generate preview for profile selection
_generate_profile_preview() {
  local item="$1"
  local selected_files="$2"  # Passed as environment variable or parameter
  
  # Check if this is a batch suite (starts with 🔄)
  if [[ "$item" == "🔄 "* ]]; then
    local suite_name="${item#🔄 }"
    local suite_reports="${PROFILING_BATCH_SUITES[$suite_name]:-}"
    local suite_desc="Batch suite"  # TODO: Could add suite descriptions to config
    
    echo "📦 Batch Suite: $suite_name"
    echo "📋 Reports: $suite_reports"
    echo "📄 Description: $suite_desc"
    echo ""
    echo "💻 Would execute batch processing:"
    echo "   python profile_runner.py --batch $suite_name \\"
    echo "     --files $selected_files"
    return
  fi
  
  # Individual profile preview
  local profile_name="$item"
  local py_file="${DISCOVERED_PROFILES[$profile_name]:-}"
  
  if [[ -z "$py_file" ]]; then
    echo "❌ Profile not found: $profile_name"
    return
  fi
  
  # Get metadata
  local metadata="${PROFILE_METADATA[$profile_name]:-||}"
  local config_desc="${metadata%%|*}"
  local file_types="${metadata#*|}"
  file_types="${file_types%%|*}"
  
  # Get additional info from config if available  
  local duration=""
  local fast_indicator=""
  
  echo "📋 $profile_name - $config_desc"
  echo "📄 File types: $file_types"
  echo "🗂️  Source: $py_file"
  
  # Extract docstring on-demand
  local docstring=$(extract_docstring "$py_file" 8)
  echo ""
  echo "📝 Docstring:"
  if [[ -n "$docstring" ]]; then
    echo "$docstring" | sed 's/^/   /'
  else
    echo "   (No docstring available)"
  fi
  
  echo ""
  echo "💻 Would execute:"
  echo "   python $(dirname "$py_file")/../profile_runner.py \\"
  echo "     $selected_files --report $profile_name"
}

# Main profile selection function
fdata-profile() {
  local files=("$@")
  
  if [[ ${#files[@]} -eq 0 ]]; then
    echo "Usage: fdata-profile file1 [file2...]"
    echo "Example: fdata-profile data.csv config.json"
    return 1
  fi
  
  # Ensure configuration is loaded
  if [[ ${#PROFILING_REPORTS[@]} -eq 0 ]]; then
    echo "🔧 Loading configuration..."
    load-profiling-config || return 1
  fi
  
  # Discover available profiles
  discover_profiles || return 1
  
  if [[ ${#DISCOVERED_PROFILES[@]} -eq 0 ]]; then
    echo "❌ No profiles discovered"
    echo "💡 Check: ${PROFILING_SETTINGS[profiling_dir]}/reports/"
    return 1
  fi
  
  # Get compatible profiles and batch suites
  local compatible_profiles=($(get_compatible_profiles "${files[@]}" 2>/dev/null))
  
  # Determine mode: single file vs multi-file
  local show_batch_suites=false
  if [[ ${#files[@]} -gt 1 ]]; then
    show_batch_suites=true
    echo "🔄 Multi-file mode: showing batch suites too"
  else
    echo "📄 Single-file mode: individual profiles only"
  fi
  
  # Build selection list
  local selection_list=()
  
  # Add individual profiles
  for profile in "${compatible_profiles[@]}"; do
    selection_list+=("$profile")
  done
  
  # Add batch suites if multi-file mode
  if [[ "$show_batch_suites" == "true" ]]; then
    local compatible_suites=($(get_compatible_batch_suites "${files[@]}" 2>/dev/null))
    for suite in "${compatible_suites[@]}"; do
      selection_list+=("🔄 $suite")  # Prefix to distinguish batch suites
    done
  fi
  
  if [[ ${#selection_list[@]} -eq 0 ]]; then
    echo "❌ No compatible profiles found for file types"
    echo "📁 Files: ${(j:, :)files}"
    echo "💡 Available profiles: ${(j:, :)${(@k)DISCOVERED_PROFILES}}"
    return 1
  fi
  
  # Export files for preview function
  export FDATA_SELECTED_FILES="${(j: :)files}"
  
  # Show selection with fzf
  local selected
  selected=$(printf '%s\n' "${selection_list[@]}" | \
    fzf --height=80% \
        --preview="_generate_profile_preview {} \"\$FDATA_SELECTED_FILES\"" \
        --preview-window="right:60%" \
        --header="🔍 Select profiler for: ${(j:, :)files} | ${#selection_list[@]} compatible" \
        --prompt="Profile: " \
        --border=rounded)
  
  unset FDATA_SELECTED_FILES
  
  if [[ -z "$selected" ]]; then
    echo "❌ No profile selected"
    return 1
  fi
  
  echo "✅ Selected: $selected"
  echo "💡 Phase 4 will implement actual execution"
  
  # TODO: Phase 4 will replace this with actual execution
  if [[ "$selected" == "🔄 "* ]]; then
    echo "🔄 Would run batch suite: ${selected#🔄 }"
  else
    echo "🔄 Would run individual profile: $selected"
  fi
}

# =============================================================================
# INTEGRATION WITH FDATA-PREVIEW  
# =============================================================================

# Enhanced fdata-preview function (update existing function)
# Add this binding to the existing fdata-preview function:
# 'ctrl-r:execute(fdata-profile {} < /dev/tty > /dev/tty)+abort'

# For multi-select mode, the binding becomes:
# 'ctrl-r:execute(fdata-profile {+} < /dev/tty > /dev/tty)+abort'

# =============================================================================
# TESTING AND DEBUG
# =============================================================================

# Test the discovery and compatibility system
test-profile-discovery() {
  echo "🧪 Testing Profile Discovery System"
  echo "=================================="
  echo ""
  
  # Load config
  load-profiling-config
  echo ""
  
  # Discover profiles
  discover_profiles
  echo ""
  
  # Test compatibility
  echo "🔍 Testing compatibility:"
  local test_files=("data.csv" "config.json" "records.parquet")
  echo "Test files: ${(j:, :)test_files}"
  echo ""
  
  echo "Compatible profiles:"
  get_compatible_profiles "${test_files[@]}"
  echo ""
  
  echo "Compatible batch suites:"  
  get_compatible_batch_suites "${test_files[@]}"
  echo ""
  
  echo "🎯 Testing profile selection UI:"
  echo "Run: fdata-profile data.csv config.json"
}

# Aliases
alias test-discovery='test-profile-discovery'
