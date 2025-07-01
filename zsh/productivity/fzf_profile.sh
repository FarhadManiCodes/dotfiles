#!/usr/bin/env zsh
# =============================================================================
# Enhanced FZF Profile Selection System - Phases 2 & 3 (FIXED VERSION)
# Location: $DOTFILES/zsh/productivity/fzf_profile.sh
# =============================================================================

# =============================================================================
# CRITICAL FIX: GLOBAL ARRAY DECLARATIONS (Must be at top)
# =============================================================================
typeset -gA PROFILING_REPORTS      # report_name -> description
typeset -gA PROFILING_FILE_TYPES   # report_name -> "csv,json,parquet"
typeset -gA PROFILING_BATCH_SUITES # suite_name -> "report1,report2,report3"
typeset -gA PROFILING_SETTINGS     # setting_name -> value
typeset -gA FILE_TYPE_PROFILES     # file_type -> "report1,report2,report3"
typeset -gA DISCOVERED_PROFILES    # profiler_name -> "/path/to/file.py"
typeset -gA PROFILE_METADATA       # profiler_name -> "config_desc|file_types|docstring_preview"

# =============================================================================
# PHASE 2: CONFIGURATION LOADING FUNCTIONS
# =============================================================================

# Load configuration with cascade: tools -> user -> defaults (FIXED)
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
  
  # CRITICAL FIX: Ensure all arrays are properly declared
  typeset -gA PROFILING_REPORTS
  typeset -gA PROFILING_FILE_TYPES
  typeset -gA PROFILING_BATCH_SUITES
  typeset -gA PROFILING_SETTINGS
  typeset -gA FILE_TYPE_PROFILES
  
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

# Load built-in default configuration (FIXED)
_load_default_config() {
  echo "🔧 Loading default configuration..."
  
  # CRITICAL FIX: Ensure array is accessible
  typeset -gA PROFILING_SETTINGS
  
  # Default settings (essential baseline)
  PROFILING_SETTINGS[profiling_dir]="$HOME/projects/profiling"
  PROFILING_SETTINGS[results_dir]="/tmp/profiling_results"
  PROFILING_SETTINGS[default_sample_size]="10000"
  PROFILING_SETTINGS[batch_session_prefix]="profiling-batch"
  
  echo "✅ Default settings loaded (${#PROFILING_SETTINGS[@]} items)"
}

# Enhanced _parse_config_file function - SIMPLE VERSION

_parse_config_file() {
  local config_file="$1"
  
  if [[ ! -f "$config_file" ]]; then
    echo "⚠️  Config file not found: $config_file"
    return 1
  fi
  
  echo "📄 Parsing (enhanced): $config_file"
  
  # Parse reports section with nested support
  if yq eval '.reports' "$config_file" >/dev/null 2>&1; then
    echo "  📋 Parsing reports (nested structure support)..."
    
    # Handle nested structure: reports.test.line_count, etc.
    # First, get all top-level keys under reports (like "test")
    local top_level_keys=($(yq eval '.reports | keys | .[]' "$config_file" 2>/dev/null))
    
    for top_key in "${top_level_keys[@]}"; do
      echo "    🔍 Processing top-level key: $top_key"
      
      # Check if this top-level key contains nested reports
      local nested_keys=($(yq eval ".reports.$top_key | keys | .[]" "$config_file" 2>/dev/null))
      
      for nested_key in "${nested_keys[@]}"; do
        # Build profile name: test + line_count = test_line_count
        local profile_name="${top_key}_${nested_key}"
        echo "      📝 Processing: $top_key.$nested_key → $profile_name"
        
        # Get description
        local description=$(yq eval ".reports.$top_key.$nested_key.description" "$config_file" 2>/dev/null)
        if [[ -n "$description" && "$description" != "null" ]]; then
          PROFILING_REPORTS[$profile_name]="$description"
          echo "        ✅ Description: $description"
        fi
        
        # Get file types
        local file_types_raw=$(yq eval ".reports.$top_key.$nested_key.file_types" "$config_file" 2>/dev/null)
        if [[ -n "$file_types_raw" && "$file_types_raw" != "null" ]]; then
          # Convert array to comma-separated string
          local file_types=$(echo "$file_types_raw" | yq eval 'join(",")' - 2>/dev/null)
          if [[ -n "$file_types" && "$file_types" != "null" ]]; then
            PROFILING_FILE_TYPES[$profile_name]="$file_types"
            echo "        📄 File types: $file_types"
          fi
        fi
      done
    done
  fi
  
  # Parse batch_profiles section (unchanged)
  if yq eval '.batch_profiles' "$config_file" >/dev/null 2>&1; then
    echo "  📦 Parsing batch_profiles..."
    local batch_suite_names=($(yq eval '.batch_profiles | keys | .[]' "$config_file" 2>/dev/null))
    for suite in "${batch_suite_names[@]}"; do
      local suite_reports=$(yq eval ".batch_profiles.$suite.reports | join(\",\")" "$config_file" 2>/dev/null)
      if [[ -n "$suite_reports" && "$suite_reports" != "null" ]]; then
        PROFILING_BATCH_SUITES[$suite]="$suite_reports"
        echo "    ✅ Batch suite: $suite → $suite_reports"
      fi
    done
  fi
  
  # Parse settings section (simplified)
  if yq eval '.settings' "$config_file" >/dev/null 2>&1; then
    echo "  ⚙️  Parsing settings..."
    
    # Get all settings keys and process them individually
    local settings_keys=($(yq eval '.settings | keys | .[]' "$config_file" 2>/dev/null))
    for key in "${settings_keys[@]}"; do
      local value=$(yq eval ".settings.$key" "$config_file" 2>/dev/null)
      if [[ -n "$value" && "$value" != "null" ]]; then
        # Expand environment variables if present
        if [[ "$value" =~ \$ ]]; then
          value=$(eval echo "\"$value\"" 2>/dev/null) || value="$value"
        fi
        PROFILING_SETTINGS[$key]="$value"
        echo "    ✅ $key = $value"
      fi
    done
  fi
}
# FIXED: Build file type mapping ONLY from individual report file_types
_build_file_type_mapping() {
  echo "🔗 Building file type mappings from individual reports..."
  
  # CRITICAL FIX: Ensure arrays are accessible
  typeset -gA FILE_TYPE_PROFILES
  typeset -gA PROFILING_FILE_TYPES
  
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

# Discover all available profiles (FIXED)
discover_profiles() {
  echo "🔍 Discovering available profiles..."
  
  # CRITICAL FIX: Ensure arrays are accessible
  typeset -gA DISCOVERED_PROFILES
  typeset -gA PROFILE_METADATA
  typeset -gA PROFILING_REPORTS
  typeset -gA PROFILING_FILE_TYPES
  typeset -gA PROFILING_SETTINGS
  
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
  
  # CRITICAL FIX: Ensure arrays are accessible
  typeset -gA PROFILING_FILE_TYPES
  
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

# Get compatible profiles for given files (FIXED)
get_compatible_profiles() {
  local files=("$@")
  
  # CRITICAL FIX: Ensure arrays are accessible
  typeset -gA DISCOVERED_PROFILES
  typeset -gA PROFILING_FILE_TYPES
  
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

# Get compatible batch suites for given files (FIXED)
get_compatible_batch_suites() {
  local files=("$@")
  
  # CRITICAL FIX: Ensure arrays are accessible
  typeset -gA PROFILING_BATCH_SUITES
  
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
  local selected_files="$2"
  
  # Check if this is a batch suite (starts with 🔄)
  if [[ "$item" == "🔄 "* ]]; then
    local suite_name="${item#🔄 }"
    echo "📦 Batch Suite: $suite_name"
    echo "📄 Description: Batch processing suite"
    echo ""
    echo "💻 Would execute batch processing:"
    echo "   python profile_runner.py --batch $suite_name \\"
    echo "     --files $selected_files"
    return
  fi
  
  # Individual profile preview - SMART FILE DETECTION
  local profile_name="$item"
  
  # Get profiling directory (use default if not set)
  local profiling_dir="${PROFILING_SETTINGS[profiling_dir]:-$HOME/projects/profiling}"
  local reports_dir="$profiling_dir/reports"
  
  echo "📋 Profile: $profile_name"
  
  # Try to find the Python file - multiple strategies
  local py_file=""
  
  # Strategy 1: Flat structure (test_line_count.py)
  local flat_path="$reports_dir/${profile_name}.py"
  if [[ -f "$flat_path" ]]; then
    py_file="$flat_path"
    echo "✅ Found (flat): $(basename "$py_file")"
  else
    # Strategy 2: Nested structure (test/line_count.py)
    # Split on first underscore: test_line_count → test + line_count
    if [[ "$profile_name" == *"_"* ]]; then
      local first_part="${profile_name%%_*}"      # test
      local rest_part="${profile_name#*_}"        # line_count
      local nested_path="$reports_dir/${first_part}/${rest_part}.py"
      
      if [[ -f "$nested_path" ]]; then
        py_file="$nested_path"
        echo "✅ Found (nested): $first_part/$(basename "$py_file")"
      fi
    fi
  fi
  
  # If still not found, try different split points for complex names
  if [[ -z "$py_file" && "$profile_name" == *"_"* ]]; then
    # Try splitting at different underscores for names like test_basic_stats
    local name_parts=(${(s:_:)profile_name})  # Split into array
    
    if [[ ${#name_parts[@]} -gt 2 ]]; then
      # Try test_basic/stats.py, test/basic_stats.py, etc.
      for i in {1..$((${#name_parts[@]}-1))}; do
        local dir_part="${(j:_:)name_parts[1,$i]}"        # test_basic, test
        local file_part="${(j:_:)name_parts[$((i+1)),-1]}" # stats, basic_stats
        local complex_path="$reports_dir/${dir_part}/${file_part}.py"
        
        if [[ -f "$complex_path" ]]; then
          py_file="$complex_path"
          echo "✅ Found (complex): $dir_part/$(basename "$py_file")"
          break
        fi
      done
    fi
  fi
  
  if [[ -z "$py_file" ]]; then
    echo "❌ File not found for profile: $profile_name"
    echo ""
    echo "🔍 Searched locations:"
    echo "   • $reports_dir/${profile_name}.py (flat)"
    if [[ "$profile_name" == *"_"* ]]; then
      local first_part="${profile_name%%_*}"
      local rest_part="${profile_name#*_}"
      echo "   • $reports_dir/${first_part}/${rest_part}.py (nested)"
    fi
    echo ""
    echo "💡 Check your profiling directory: $reports_dir"
    return
  fi
  
  # Show file information
  echo "📁 Location: $py_file"
  local size=$(ls -lh "$py_file" 2>/dev/null | awk '{print $5}' || echo "?")
  local modified=$(ls -l "$py_file" 2>/dev/null | awk '{print $6, $7, $8}' || echo "?")
  echo "📊 Size: $size | Modified: $modified"
  
  # Extract docstring directly
  echo ""
  echo "📝 Docstring:"
  local docstring_output=$(python3 -c "
import ast
try:
    with open('$py_file', 'r') as f:
        tree = ast.parse(f.read())
    docstring = ast.get_docstring(tree)
    if docstring:
        lines = docstring.split('\n')[:6]  # First 6 lines for preview
        for line in lines:
            print('   ' + line.strip())
    else:
        print('   (No docstring found)')
except Exception as e:
    print('   (Error reading file)')
" 2>/dev/null)
  
  if [[ -n "$docstring_output" ]]; then
    echo "$docstring_output"
  else
    echo "   (Could not extract docstring)"
  fi
  
  echo ""
  echo "💻 Would execute:"
  echo "   python $(dirname "$py_file")/../profile_runner.py \\"
  echo "     --report $profile_name --files $selected_files"
}
# Main profile selection function (FIXED)

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
      return 0
      ;;
    --list)
      echo "📋 Available Profiles"
      if [[ ${#PROFILING_REPORTS[@]} -eq 0 ]]; then
        load-profiling-config >/dev/null 2>&1
      fi
      discover_profiles >/dev/null 2>&1
      
      if [[ ${#DISCOVERED_PROFILES[@]} -eq 0 ]]; then
        echo "❌ No profiles found"
        return 1
      fi
      
      for profile in "${(@k)DISCOVERED_PROFILES}"; do
        local desc="${PROFILING_REPORTS[$profile]:-No description}"
        local file_types="${PROFILING_FILE_TYPES[$profile]:-all}"
        echo "  • $profile - $desc"
        echo "    File types: $file_types"
      done
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
    echo "Use 'fdata-profile --help' for more information"
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
      selection_list+=("🔄 $suite")
    done
  fi
  
  if [[ ${#selection_list[@]} -eq 0 ]]; then
    echo "❌ No compatible profiles found for file types"
    echo "📁 Files: ${(j:, :)files}"
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
  
  # ENHANCED OUTPUT SECTION
  echo ""
  echo "✅ Selected: $selected"
  echo ""
  echo "📁 Input files (${#files[@]}):"
  local counter=1
  for file in "${files[@]}"; do
    local size=$(ls -lh "$file" 2>/dev/null | awk '{print $5}' || echo "?")
    local ext="${file##*.}"
    echo "   $counter. $(basename "$file") ($ext, $size)"
    counter=$((counter + 1))
done
  echo ""
  echo "🎯 Execution Plan:"
  if [[ "$selected" == "🔄 "* ]]; then
    local suite_name="${selected#🔄 }"
    local suite_reports="${PROFILING_BATCH_SUITES[$suite_name]:-unknown}"
    echo "   Type: Batch suite"
    echo "   Suite: $suite_name"
    echo "   Reports: $suite_reports"
    echo ""
    echo "💡 Phase 4 will implement actual execution"
    echo "🔄 Would run batch suite '$suite_name' on ${#files[@]} file(s)"
  else
    echo "   Type: Individual profile"
    echo "   Profile: $selected"
    echo "   Description: ${PROFILING_REPORTS[$selected]:-unknown}"
    echo "   File types: ${PROFILING_FILE_TYPES[$selected]:-unknown}"
    echo ""
    echo "💡 Phase 4 will implement actual execution"
    echo "🔄 Would run individual profile '$selected' on ${#files[@]} file(s)"
  fi
}

# =============================================================================
# DEBUG AND STATUS FUNCTIONS
# =============================================================================

# Show current configuration status (FIXED)
show-profiling-config() {
  echo "🔧 Profiling Configuration Status"
  echo "================================="
  echo ""
  
  # CRITICAL FIX: Ensure arrays are accessible
  typeset -gA PROFILING_REPORTS
  typeset -gA PROFILING_FILE_TYPES
  typeset -gA PROFILING_BATCH_SUITES
  typeset -gA PROFILING_SETTINGS
  typeset -gA FILE_TYPE_PROFILES
  
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

# Test configuration with sample files (FIXED)
test-profiling-config() {
  echo "🧪 Testing Configuration System"
  echo "==============================="
  echo ""
  
  # CRITICAL FIX: Ensure arrays are accessible
  typeset -gA PROFILING_REPORTS
  typeset -gA PROFILING_FILE_TYPES
  typeset -gA PROFILING_BATCH_SUITES
  typeset -gA PROFILING_SETTINGS
  typeset -gA FILE_TYPE_PROFILES
  
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

# Test the discovery and compatibility system (FIXED)
test-profile-discovery() {
  echo "🧪 Testing Profile Discovery System"
  echo "=================================="
  echo ""
  
  # CRITICAL FIX: Ensure arrays are accessible
  typeset -gA PROFILING_REPORTS
  typeset -gA PROFILING_FILE_TYPES
  typeset -gA PROFILING_BATCH_SUITES
  typeset -gA PROFILING_SETTINGS
  typeset -gA DISCOVERED_PROFILES
  typeset -gA PROFILE_METADATA
  
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
