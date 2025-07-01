#!/usr/bin/env zsh
# =============================================================================
# Enhanced FZF Profile Selection System - Phases 2 & 3
# Location: $DOTFILES/zsh/productivity/fzf_profile.sh
# =============================================================================

# Global configuration arrays (populated by load-profiling-config)
typeset -A PROFILING_REPORTS      # report_name -> description
typeset -A PROFILING_FILE_TYPES   # report_name -> "csv,json,parquet"
typeset -A PROFILING_BATCH_SUITES # suite_name -> "report1,report2,report3"
typeset -A PROFILING_SETTINGS     # setting_name -> value

# Global file type to reports mapping (built from individual reports)
typeset -A FILE_TYPE_PROFILES     # file_type -> "report1,report2,report3"

# Global arrays for discovered profiles (populated by discover_profiles)
typeset -A DISCOVERED_PROFILES        # profiler_name -> "/path/to/file.py"
typeset -A PROFILE_METADATA          # profiler_name -> "config_desc|file_types|docstring_preview"

# =============================================================================
# PHASE 2: CONFIGURATION LOADING FUNCTIONS
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
  
  # Default settings (essential baseline)
  PROFILING_SETTINGS[profiling_dir]="$HOME/projects/profiling"
  PROFILING_SETTINGS[results_dir]="/tmp/profiling_results"
  PROFILING_SETTINGS[default_sample_size]="10000"
  PROFILING_SETTINGS[batch_session_prefix]="profiling-batch"
}

# YAML parser using yq (FIXED - removed file_extensions parsing)
_parse_config_file() {
  local config_file="$1"
  
  if [[ ! -f "$config_file" ]]; then
    echo "⚠️  Config file not found: $config_file"
    return 1
  fi
  
  echo "📄 Parsing: $config_file"
  
  # Parse reports section
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
  
  # Parse batch_profiles section
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
  
  # Parse settings section (FIXED yq approach)
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

# FIXED: Build file type mapping ONLY from individual report file_types
_build_file_type_mapping() {
  echo "🔗 Building file type mappings from individual reports..."
  
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
      [[ -z "$file_type" ]] && continue
      
      # Add report to this file type's list
      if [[ -n "${FILE_TYPE_PROFILES[$file_type]}" ]]; then
        FILE_TYPE_PROFILES[$file_type]="${FILE_TYPE_PROFILES[$file_type]},$report"
      else
        FILE_TYPE_PROFILES[$file_type]="$report"
      fi
    done
  done
  
  echo "✅ File type mapping built: ${#FILE_TYPE_PROFILES[@]} types"
}

# =============================================================================
# PHASE 3: PROFILE DISCOVERY FUNCTIONS
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
        --preview="source \"$DOTFILES/zsh/productivity/fzf_profile.sh\" && _generate_profile_preview {} \"\$FDATA_SELECTED_FILES\"" \
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
# DEBUG AND STATUS FUNCTIONS (kept accessible)
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

# =============================================================================
# LEGACY COMPATIBILITY FUNCTIONS (from Phase 2)
# =============================================================================

# Get available profiles for given file types (legacy format)
get-available-profiles() {
  local file_list="$1"  # Colon-separated list like "file1.csv:file2.json"
  
  if [[ -z "$file_list" ]]; then
    echo "Usage: get-available-profiles file1.csv:file2.json"
    return 1
  fi
  
  # Convert to array format and call new function
  local files=(${(s.:.)file_list})
  get_compatible_profiles "${files[@]}"
}

# Get available batch suites for given file types (legacy format)
get-available-batch-suites() {
  local file_list="$1"
  
  if [[ -z "$file_list" ]]; then
    echo "Usage: get-available-batch-suites file1.csv:file2.json"
    return 1
  fi
  
  # Convert to array format and call new function
  local files=(${(s.:.)file_list})
  get_compatible_batch_suites "${files[@]}"
}

# =============================================================================
# TAB COMPLETION SUPPORT
# =============================================================================

# Completion function for fdata-profile
_fdata_profile_completion() {
  local context curcontext="$curcontext" state line
  typeset -A opt_args

  _arguments -C \
    '*:files:_files -g "*.csv *.tsv *.json *.jsonl *.parquet *.xlsx *.xls *.pkl *.pickle *.h5 *.hdf5 *.yaml *.yml"'
}

# Advanced completion with profile names
_fdata_profile_advanced_completion() {
  local context curcontext="$curcontext" state line
  typeset -A opt_args

  _arguments -C \
    '--help[Show help]' \
    '--list[List available profiles]' \
    '--config[Show configuration]' \
    '*:files:_files -g "*.csv *.tsv *.json *.jsonl *.parquet *.xlsx *.xls *.pkl *.pickle *.h5 *.hdf5 *.yaml *.yml"'
}

# Register completion
compdef _fdata_profile_completion fdata-profile

# =============================================================================
# ENHANCED MAIN FUNCTION WITH COMPLETION SUPPORT
# =============================================================================

# Enhanced fdata-profile with additional options
fdata-profile() {
  # Handle special flags first
  case "$1" in
    --help|-h)
      echo "📊 fdata-profile - Data Profiling Tool"
      echo "======================================"
      echo ""
      echo "Usage:"
      echo "  fdata-profile file1.csv [file2.json ...]"
      echo "  fdata-profile --list                      # List available profiles"
      echo "  fdata-profile --config                    # Show configuration"
      echo "  fdata-profile --help                      # Show this help"
      echo ""
      echo "Examples:"
      echo "  fdata-profile data.csv                    # Single file profiling"
      echo "  fdata-profile *.csv                       # Multiple CSV files"
      echo "  fdata-profile data.csv config.json        # Mixed file types"
      echo ""
      echo "Supported file types:"
      echo "  CSV/TSV: .csv, .tsv"
      echo "  JSON: .json, .jsonl"
      echo "  Parquet: .parquet"
      echo "  Excel: .xlsx, .xls"
      echo "  Pickle: .pkl, .pickle"
      echo "  HDF5: .h5, .hdf5"
      echo "  YAML: .yaml, .yml"
      echo ""
      echo "Tab completion is available for file names in current directory."
      return 0
      ;;
    --list)
      echo "📋 Available Profiles"
      echo "===================="
      
      # Ensure configuration is loaded
      if [[ ${#PROFILING_REPORTS[@]} -eq 0 ]]; then
        echo "🔧 Loading configuration..."
        load-profiling-config >/dev/null 2>&1 || {
          echo "❌ Failed to load configuration"
          return 1
        }
      fi
      
      # Discover profiles
      discover_profiles >/dev/null 2>&1
      
      if [[ ${#DISCOVERED_PROFILES[@]} -eq 0 ]]; then
        echo "❌ No profiles found"
        echo "💡 Check: ${PROFILING_SETTINGS[profiling_dir]}/reports/"
        return 1
      fi
      
      echo "Individual profiles:"
      for profile in "${(@k)DISCOVERED_PROFILES}"; do
        local desc="${PROFILING_REPORTS[$profile]:-No description}"
        local file_types="${PROFILING_FILE_TYPES[$profile]:-all}"
        echo "  • $profile"
        echo "    📄 $desc"
        echo "    🎯 File types: $file_types"
        echo ""
      done
      
      if [[ ${#PROFILING_BATCH_SUITES[@]} -gt 0 ]]; then
        echo "Batch suites:"
        for suite in "${(@k)PROFILING_BATCH_SUITES}"; do
          echo "  • $suite: ${PROFILING_BATCH_SUITES[$suite]}"
        done
      fi
      
      return 0
      ;;
    --config)
      show-profiling-config
      return 0
      ;;
  esac

  local files=("$@")
  
  if [[ ${#files[@]} -eq 0 ]]; then
    echo "Usage: fdata-profile file1 [file2...]"
    echo "Examples:"
    echo "  fdata-profile data.csv"
    echo "  fdata-profile *.csv"
    echo "  fdata-profile data.csv config.json"
    echo ""
    echo "Use 'fdata-profile --help' for more information"
    echo "Use 'fdata-profile --list' to see available profiles"
    return 1
  fi
  
  # Validate files exist
  local missing_files=()
  for file in "${files[@]}"; do
    if [[ ! -f "$file" ]]; then
      missing_files+=("$file")
    fi
  done
  
  if [[ ${#missing_files[@]} -gt 0 ]]; then
    echo "❌ Files not found:"
    for file in "${missing_files[@]}"; do
      echo "  • $file"
    done
    echo ""
    echo "💡 Use tab completion to select existing files"
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
    echo "💡 Use 'fdata-profile --list' to see all profiles and their file types"
    return 1
  fi
  
  # Export files for preview function
  export FDATA_SELECTED_FILES="${(j: :)files}"
  
  # Show selection with fzf
  local selected
  selected=$(printf '%s\n' "${selection_list[@]}" | \
    fzf --height=80% \
        --preview="source \"$DOTFILES/zsh/productivity/fzf_profile.sh\" && _generate_profile_preview {} \"\$FDATA_SELECTED_FILES\"" \
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
# ALIASES AND HELPERS (accessible from main shell)
# =============================================================================

alias config-profiling='load-profiling-config'
alias show-config='show-profiling-config'
alias test-config='test-profiling-config'
alias test-discovery='test-profile-discovery'

# Quick aliases for common usage
alias profile='fdata-profile'
alias profiles='fdata-profile --list'
alias profile-config='fdata-profile --config'
