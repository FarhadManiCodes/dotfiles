#!/usr/bin/env zsh
# =============================================================================
# Enhanced FZF Profile Selection System - Optimized & Efficient
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
# CONFIGURATION LOADING FUNCTIONS
# =============================================================================

# Load configuration with cascade: tools -> user -> defaults
load-profiling-config() {
  # Check if yq is available
  if ! command -v yq >/dev/null 2>&1; then
    echo "❌ Error: yq not found (required for configuration parsing)"
    return 1
  fi
  
  # Clear existing configuration
  PROFILING_REPORTS=()
  PROFILING_FILE_TYPES=()
  PROFILING_BATCH_SUITES=()
  PROFILING_SETTINGS=()
  FILE_TYPE_PROFILES=()
  
  # Load defaults first (lowest priority)
  _load_default_config
  
  # Try to load user config (medium priority)
  local user_config="$HOME/.config/profiling/config.yml"
  if [[ -f "$user_config" ]]; then
    _parse_config_file "$user_config"
  fi
  
  # Try to load centralized tools config (highest priority)
  local profiling_dir="${PROFILING_SETTINGS[profiling_dir]:-$HOME/projects/profiling}"
  local tools_config="$profiling_dir/config.yml"
  if [[ -f "$tools_config" ]]; then
    _parse_config_file "$tools_config"
  fi
  
  # Build file type to profiles mapping
  _build_file_type_mapping
  
  return 0
}

# Load built-in default configuration
_load_default_config() {
  # Default settings (essential baseline)
  PROFILING_SETTINGS[profiling_dir]="$HOME/projects/profiling"
  PROFILING_SETTINGS[results_dir]="/tmp/profiling_results"
  PROFILING_SETTINGS[default_sample_size]="10000"
  PROFILING_SETTINGS[batch_session_prefix]="profiling-batch"
}

# Enhanced YAML parser with nested structure support
_parse_config_file() {
  local config_file="$1"
  
  if [[ ! -f "$config_file" ]]; then
    return 1
  fi
  
  # Parse reports section with nested support
  if yq eval '.reports' "$config_file" >/dev/null 2>&1; then
    # Handle nested structure: reports.test.line_count, etc.
    local top_level_keys=($(yq eval '.reports | keys | .[]' "$config_file" 2>/dev/null))
    
    for top_key in "${top_level_keys[@]}"; do
      # Check if this top-level key contains nested reports
      local nested_keys=($(yq eval ".reports.$top_key | keys | .[]" "$config_file" 2>/dev/null))
      
      for nested_key in "${nested_keys[@]}"; do
        # Build profile name: test + line_count = test_line_count
        local profile_name="${top_key}_${nested_key}"
        
        # Get description
        local description=$(yq eval ".reports.$top_key.$nested_key.description" "$config_file" 2>/dev/null)
        if [[ -n "$description" && "$description" != "null" ]]; then
          PROFILING_REPORTS[$profile_name]="$description"
        fi
        
        # Get file types
        local file_types_raw=$(yq eval ".reports.$top_key.$nested_key.file_types" "$config_file" 2>/dev/null)
        if [[ -n "$file_types_raw" && "$file_types_raw" != "null" ]]; then
          local file_types=$(echo "$file_types_raw" | yq eval 'join(",")' - 2>/dev/null)
          if [[ -n "$file_types" && "$file_types" != "null" ]]; then
            PROFILING_FILE_TYPES[$profile_name]="$file_types"
          fi
        fi
      done
    done
  fi
  
  # Parse batch_profiles section
  if yq eval '.batch_profiles' "$config_file" >/dev/null 2>&1; then
    local batch_suite_names=($(yq eval '.batch_profiles | keys | .[]' "$config_file" 2>/dev/null))
    for suite in "${batch_suite_names[@]}"; do
      local suite_reports=$(yq eval ".batch_profiles.$suite.reports | join(\",\")" "$config_file" 2>/dev/null)
      if [[ -n "$suite_reports" && "$suite_reports" != "null" ]]; then
        PROFILING_BATCH_SUITES[$suite]="$suite_reports"
      fi
    done
  fi
  
  # Parse settings section
  if yq eval '.settings' "$config_file" >/dev/null 2>&1; then
    local settings_keys=($(yq eval '.settings | keys | .[]' "$config_file" 2>/dev/null))
    for key in "${settings_keys[@]}"; do
      local value=$(yq eval ".settings.$key" "$config_file" 2>/dev/null)
      if [[ -n "$value" && "$value" != "null" ]]; then
        # Expand environment variables if present
        if [[ "$value" =~ \$ ]]; then
          value=$(eval echo "\"$value\"" 2>/dev/null) || value="$value"
        fi
        PROFILING_SETTINGS[$key]="$value"
      fi
    done
  fi
}

# Build file type mapping from individual report file_types
_build_file_type_mapping() {
  # Clear existing mapping
  FILE_TYPE_PROFILES=()
  
  # For each report, add it to the file types it supports
  for report in "${(@k)PROFILING_FILE_TYPES}"; do
    local file_types="${PROFILING_FILE_TYPES[$report]}"
    local types_array=(${(s:,:)file_types})
    for file_type in "${types_array[@]}"; do
      file_type=$(echo "$file_type" | tr -d ' ')
      [[ -z "$file_type" ]] && continue
      
      if [[ -n "${FILE_TYPE_PROFILES[$file_type]}" ]]; then
        FILE_TYPE_PROFILES[$file_type]="${FILE_TYPE_PROFILES[$file_type]},$report"
      else
        FILE_TYPE_PROFILES[$file_type]="$report"
      fi
    done
  done
}

# =============================================================================
# PROFILE DISCOVERY FUNCTIONS
# =============================================================================

# Generate profile name from file path
generate_profile_name() {
  local py_file="$1"
  local reports_dir="$2"
  
  local rel_path="${py_file#$reports_dir/}"
  rel_path="${rel_path%.py}"
  local profile_name=$(echo "$rel_path" | sed 's|/|_|g' | sed 's|-|_|g')
  
  echo "$profile_name"
}

# Extract docstring from Python file (on-demand)
extract_docstring() {
  local py_file="$1"
  local max_lines="${2:-5}"
  
  local docstring=$(python3 -c "
import ast
try:
    with open('$py_file', 'r') as f:
        tree = ast.parse(f.read())
    docstring = ast.get_docstring(tree)
    if docstring:
        lines = docstring.split('\n')[:$max_lines]
        print('\n'.join(lines))
except Exception:
    pass
" 2>/dev/null)
  
  echo "$docstring"
}

# Discover all available profiles (cleaned up)
discover_profiles() {
  # Clear existing discoveries
  DISCOVERED_PROFILES=()
  PROFILE_METADATA=()
  
  local profiling_dir="${PROFILING_SETTINGS[profiling_dir]}"
  local reports_dir="$profiling_dir/reports"
  
  if [[ ! -d "$reports_dir" ]]; then
    echo "⚠️  Reports directory not found: $reports_dir"
    return 1
  fi
  
  # Use fd to find all .py files
  while IFS= read -r -d '' py_file; do
    [[ -f "$py_file" ]] || continue
    
    local profile_name=$(generate_profile_name "$py_file" "$reports_dir")
    DISCOVERED_PROFILES[$profile_name]="$py_file"
    
    # Check if profiler is in config (only warn if missing)
    local config_desc="${PROFILING_REPORTS[$profile_name]:-}"
    local file_types="${PROFILING_FILE_TYPES[$profile_name]:-all}"
    
    if [[ -z "$config_desc" ]]; then
      echo "  ⚠️  Found profiler '$profile_name' not in config: $py_file"
      config_desc="(No description in config)"
    fi
    
    # Store basic metadata
    PROFILE_METADATA[$profile_name]="$config_desc|$file_types"
    
  done < <(fd -e py . "$reports_dir" -0 2>/dev/null)
  
  return 0
}

# =============================================================================
# COMPATIBILITY FILTERING
# =============================================================================

# Check if profile is compatible with given file types
is_profile_compatible() {
  local profile_name="$1"
  local file_extensions="$2"  # Space-separated list like "csv json"
  
  local profile_file_types="${PROFILING_FILE_TYPES[$profile_name]:-}"
  
  # If no file types specified in config, accepts all files
  if [[ -z "$profile_file_types" || "$profile_file_types" == "all" ]]; then
    return 0
  fi
  
  # Check if at least one file extension matches
  local supported_types=(${(s:,:)profile_file_types})
  for ext in ${(s: :)file_extensions}; do
    for supported in "${supported_types[@]}"; do
      supported=$(echo "$supported" | tr -d ' ')
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
    if [[ ! " ${extensions[@]} " =~ " ${ext} " ]]; then
      extensions+=("$ext")
    fi
  done
  
  local extensions_str="${(j: :)extensions}"
  
  # Find compatible individual profiles
  local compatible_profiles=()
  for profile in "${(@k)DISCOVERED_PROFILES}"; do
    if is_profile_compatible "$profile" "$extensions_str"; then
      compatible_profiles+=("$profile")
    fi
  done
  
  printf '%s\n' "${compatible_profiles[@]}"
}

# Get compatible batch suites for given files  
get_compatible_batch_suites() {
  local files=("$@")
  
  local compatible_profiles=($(get_compatible_profiles "$@" 2>/dev/null))
  
  local compatible_suites=()
  for suite in "${(@k)PROFILING_BATCH_SUITES}"; do
    local suite_reports=(${(s:,:)PROFILING_BATCH_SUITES[$suite]})
    local has_compatible=false
    
    for suite_report in "${suite_reports[@]}"; do
      suite_report=$(echo "$suite_report" | tr -d ' ')
      if [[ " ${compatible_profiles[@]} " =~ " ${suite_report} " ]]; then
        has_compatible=true
        break
      fi
    done
    
    if [[ "$has_compatible" == "true" ]]; then
      compatible_suites+=("$suite")
    fi
  done
  
  printf '%s\n' "${compatible_suites[@]}"
}

# =============================================================================
# PROFILE SELECTION UI
# =============================================================================

# Efficient preview function with smart file finding
_generate_profile_preview() {
  local item="$1"
  local selected_files="$2"
  
  # Check if this is a batch suite (starts with 🔄)
  if [[ "$item" == "🔄 "* ]]; then
    local suite_name="${item#🔄 }"
    echo "📦 Batch Suite: $suite_name"
    echo ""
    
    # Read configuration directly (preview runs in subprocess, no access to parent vars)
    local profiling_dir="${PROFILING_SETTINGS[profiling_dir]:-$HOME/projects/profiling}"
    local config_file="$profiling_dir/config.yml"
    local user_config="$HOME/.config/profiling/config.yml"
    
    # Try to find a config file to read from
    local config_to_read=""
    if [[ -f "$config_file" ]]; then
      config_to_read="$config_file"
    elif [[ -f "$user_config" ]]; then
      config_to_read="$user_config"
    fi
    
    if [[ -n "$config_to_read" && -x "$(command -v yq)" ]]; then
      # Read batch suite reports directly from config
      local suite_reports=$(yq eval ".batch_profiles.$suite_name.reports | join(\",\")" "$config_to_read" 2>/dev/null)
      local suite_description=$(yq eval ".batch_profiles.$suite_name.description" "$config_to_read" 2>/dev/null)
      
      # Show description if available
      if [[ -n "$suite_description" && "$suite_description" != "null" ]]; then
        echo "📄 Description: $suite_description"
        echo ""
      fi
      
      if [[ -n "$suite_reports" && "$suite_reports" != "null" ]]; then
        local profilers=(${(s:,:)suite_reports})
        echo "📋 Individual Profilers (${#profilers[@]}):"
        local counter=1
        for profiler in "${profilers[@]}"; do
          profiler=$(echo "$profiler" | tr -d ' ')  # Remove whitespace
          [[ -z "$profiler" ]] && continue
          echo "   $counter. $profiler"
          counter=$((counter + 1))
        done
        echo ""
      else
        echo "❌ No profilers configured for this batch suite"
        echo ""
      fi
    else
      echo "❌ No configuration file found or yq not available"
      echo ""
    fi
    
    echo "💻 Command: python profile_runner.py --batch $suite_name --files $selected_files"
    return
  fi
  
  # Individual profile preview
  local profile_name="$item"
  
  # Get profiling directory
  local profiling_dir="${PROFILING_SETTINGS[profiling_dir]:-$HOME/projects/profiling}"
  local reports_dir="$profiling_dir/reports"
  
  # Smart file finding - try multiple strategies
  local py_file=""
  
  # Strategy 1: Flat structure (test_line_count.py)
  local flat_path="$reports_dir/${profile_name}.py"
  if [[ -f "$flat_path" ]]; then
    py_file="$flat_path"
  else
    # Strategy 2: Nested structure (test/line_count.py)
    if [[ "$profile_name" == *"_"* ]]; then
      local first_part="${profile_name%%_*}"
      local rest_part="${profile_name#*_}"
      local nested_path="$reports_dir/${first_part}/${rest_part}.py"
      
      if [[ -f "$nested_path" ]]; then
        py_file="$nested_path"
      fi
    fi
  fi
  
  # Strategy 3: Complex splitting for names like test_basic_stats
  if [[ -z "$py_file" && "$profile_name" == *"_"* ]]; then
    local name_parts=(${(s:_:)profile_name})
    
    if [[ ${#name_parts[@]} -gt 2 ]]; then
      for i in {1..$((${#name_parts[@]}-1))}; do
        local dir_part="${(j:_:)name_parts[1,$i]}"
        local file_part="${(j:_:)name_parts[$((i+1)),-1]}"
        local complex_path="$reports_dir/${dir_part}/${file_part}.py"
        
        if [[ -f "$complex_path" ]]; then
          py_file="$complex_path"
          break
        fi
      done
    fi
  fi
  
  if [[ -z "$py_file" ]]; then
    echo "❌ Profile not found: $profile_name"
    return
  fi
  
  # Show essential info only
  echo "📋 $profile_name"
  echo "📁 $py_file"
  
  # Extract docstring efficiently
  echo ""
  echo "📝 Description:"
  local docstring_output=$(python3 -c "
import ast
try:
    with open('$py_file', 'r') as f:
        tree = ast.parse(f.read())
    docstring = ast.get_docstring(tree)
    if docstring:
        lines = docstring.split('\n')[:5]
        for line in lines:
            if line.strip():
                print('   ' + line.strip())
    else:
        print('   (No description available)')
except:
    print('   (Could not read file)')
" 2>/dev/null)
  
  if [[ -n "$docstring_output" ]]; then
    echo "$docstring_output"
  else
    echo "   (No description available)"
  fi
  
  echo ""
  echo "💻 Command: python profile_runner.py --report $profile_name --files $selected_files"
}

# =============================================================================
# PROFILE EXECUTION FUNCTIONS
# =============================================================================

# Execute a single profile on specified files
run_single_profile() {
  local profile_name="$1"
  shift
  local files=("$@")
  
  echo "🔄 Running profile '$profile_name' on ${#files[@]} file(s)..."
  
  # Get profiling directory
  local profiling_dir="${PROFILING_SETTINGS[profiling_dir]:-$HOME/projects/profiling}"
  local results_dir="${PROFILING_SETTINGS[results_dir]:-/tmp/profiling_results}"
  
  # Check if profile_runner.py exists
  if [[ ! -f "$profiling_dir/profile_runner.py" ]]; then
    echo "❌ Profile runner not found: $profiling_dir/profile_runner.py"
    echo "💡 Check profiling directory configuration"
    return 1
  fi
  
  # Build command
  local cmd="python3 \"$profiling_dir/profile_runner.py\""
  cmd="$cmd --report \"$profile_name\""
  cmd="$cmd --output-dir \"$results_dir\""
  
  for file in "${files[@]}"; do
    cmd="$cmd --file \"$file\""
  done
  
  # Execute with timing
  local start_time=$(date +%s.%N)
  
  if eval "$cmd"; then
    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc -l)
    local duration_formatted=$(printf "%.1f" "$duration")
    
    echo "✅ Completed in ${duration_formatted}s"
    show_execution_results "$profile_name" "$results_dir" "${files[@]}"
  else
    echo "❌ Profile execution failed"
    echo "💡 Command: $cmd"
    echo "💡 Check logs: $results_dir/latest/error.log"
  fi
}

# Execute a batch suite on specified files
run_batch_suite() {
  local suite_name="$1"
  shift
  local files=("$@")
  
  echo "🔄 Running batch suite '$suite_name' on ${#files[@]} file(s)..."
  
  # Get profiling directory  
  local profiling_dir="${PROFILING_SETTINGS[profiling_dir]:-$HOME/projects/profiling}"
  local results_dir="${PROFILING_SETTINGS[results_dir]:-/tmp/profiling_results}"
  
  # Check if profile_runner.py exists
  if [[ ! -f "$profiling_dir/profile_runner.py" ]]; then
    echo "❌ Profile runner not found: $profiling_dir/profile_runner.py"
    echo "💡 Check profiling directory configuration"
    return 1
  fi
  
  # Build command
  local cmd="python3 \"$profiling_dir/profile_runner.py\""
  cmd="$cmd --batch \"$suite_name\""
  cmd="$cmd --output-dir \"$results_dir\""
  
  for file in "${files[@]}"; do
    cmd="$cmd --file \"$file\""
  done
  
  # Execute with timing
  local start_time=$(date +%s.%N)
  
  if eval "$cmd"; then
    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc -l)
    local duration_formatted=$(printf "%.1f" "$duration")
    
    echo "✅ Batch completed in ${duration_formatted}s"
    show_batch_results "$suite_name" "$results_dir" "${files[@]}"
  else
    echo "❌ Batch execution failed"
    echo "💡 Command: $cmd"
    echo "💡 Check logs: $results_dir/latest/error.log"
  fi
}

# Display execution results with key metrics
show_execution_results() {
  local profile_name="$1"
  local results_dir="$2"
  shift 2
  local files=("$@")
  
  # Look for latest results - check both symlink and newest timestamped file
  local latest_dir="$results_dir/latest"
  local summary_file="$latest_dir/summary.json"
  local json_file="$latest_dir/results.json"
  
  # If latest symlink doesn't exist, find the most recent result file
  if [[ ! -f "$summary_file" ]]; then
    local recent_json=$(ls -t "$results_dir"/${profile_name}_*.json 2>/dev/null | head -1)
    if [[ -n "$recent_json" ]]; then
      summary_file="$recent_json"
      json_file="$recent_json"
      latest_dir="$(dirname "$recent_json")"
    fi
  fi
  
  if [[ -f "$summary_file" ]]; then
    # Extract key metrics from JSON summary (graceful fallback if jq not available)
    if command -v jq >/dev/null 2>&1; then
      local row_count=$(jq -r '.results.total_lines // .total_rows // "unknown"' "$summary_file" 2>/dev/null)
      local file_count=$(jq -r '.files_processed // "1"' "$summary_file" 2>/dev/null)
      
      if [[ "$row_count" != "unknown" ]]; then
        echo "📊 Processed: $row_count rows in $file_count file(s)"
      fi
    fi
  fi
  
  echo "📁 Results: $latest_dir/"
  
  # Smart result display - small preview or automatic pager for large results
  # json_file is already set above
  if [[ -f "$json_file" ]]; then
    local line_count=$(wc -l < "$json_file" 2>/dev/null || echo "0")
    local char_count=$(wc -c < "$json_file" 2>/dev/null || echo "0")
    
    # Auto-display criteria: small files (< 30 lines and < 5KB)
    if [[ "$line_count" -lt 30 ]] && [[ "$char_count" -lt 5120 ]]; then
      echo ""
      echo "📋 Results preview:"
      head -25 "$json_file" 2>/dev/null | sed 's/^/   /' || echo "   (Preview unavailable)"
      
      # If there are more lines, show truncation notice
      if [[ "$line_count" -gt 25 ]]; then
        echo "   ... ($(($line_count - 25)) more lines)"
        echo ""
        echo "💡 Press Enter to view full results in pager, or 'v' for new tmux pane"
        local view_choice=""
        read -k 1 view_choice < /dev/tty
        case "$view_choice" in
          "v"|"V")
            if [[ -n "$TMUX" ]]; then
              show_detailed_results "$latest_dir"
            else
              echo "💡 Tmux not available - showing in pager instead"
              show_results_in_pager "$json_file"
            fi
            ;;
          *)
            show_results_in_pager "$json_file"
            ;;
        esac
      fi
    else
      # Large results - automatically show in pager
      echo ""
      echo "📊 Large results detected ($line_count lines, ${char_count} chars)"
      echo "🔍 Opening in pager..."
      show_results_in_pager "$json_file"
    fi
  fi
  
  # Offer tmux pane option if not already handled above
  if [[ -n "$TMUX" ]] && [[ "$line_count" -lt 30 ]] && [[ "$char_count" -lt 5120 ]]; then
    echo ""
    echo "💡 Press 'v' to view detailed results in new pane (5s timeout)"
    local view_choice=""
    read -t 5 -k 1 view_choice 2>/dev/null < /dev/tty
    if [[ "$view_choice" == "v" || "$view_choice" == "V" ]]; then
      echo "Opening results in new tmux pane..."
      show_detailed_results "$latest_dir"
    fi
  fi
}

# Display batch execution results
show_batch_results() {
  local suite_name="$1"
  local results_dir="$2"
  shift 2
  local files=("$@")
  
  # Look for latest results
  local latest_dir="$results_dir/latest"
  local summary_file="$latest_dir/summary.json"
  
  if [[ -f "$summary_file" ]]; then
    # Extract key metrics from JSON summary (graceful fallback if jq not available)
    if command -v jq >/dev/null 2>&1; then
      local row_count=$(jq -r '.results.total_lines // .total_rows // "unknown"' "$summary_file" 2>/dev/null)
      local file_count=$(jq -r '.files_processed // "1"' "$summary_file" 2>/dev/null)
      local profiles_run=$(jq -r '.profiles_executed // "unknown"' "$summary_file" 2>/dev/null)
      
      if [[ "$row_count" != "unknown" ]]; then
        echo "📊 Processed: $row_count rows in $file_count file(s) using $profiles_run profile(s)"
      fi
    fi
  fi
  
  echo "📁 Results: $latest_dir/"
  
  # Smart result display for batch results too
  local json_file="$latest_dir/results.json"
  if [[ ! -f "$json_file" ]]; then
    # Try to find any recent JSON file for batch results
    local recent_json=$(ls -t "$results_dir"/*.json 2>/dev/null | head -1)
    if [[ -n "$recent_json" ]]; then
      json_file="$recent_json"
    fi
  fi
  
  if [[ -f "$json_file" ]]; then
    local line_count=$(wc -l < "$json_file" 2>/dev/null || echo "0")
    local char_count=$(wc -c < "$json_file" 2>/dev/null || echo "0")
    
    # For batch results, be more conservative - show in pager if > 40 lines or > 8KB
    if [[ "$line_count" -gt 40 ]] || [[ "$char_count" -gt 8192 ]]; then
      echo ""
      echo "📊 Large batch results detected ($line_count lines, ${char_count} chars)"
      echo "🔍 Opening in pager..."
      show_results_in_pager "$json_file"
    fi
  fi
  
  # Offer tmux pane option for batch results
  if [[ -n "$TMUX" ]]; then
    echo ""
    echo "💡 Press 'v' to view detailed results in new pane (5s timeout)"
    local view_choice=""
    read -t 5 -k 1 view_choice 2>/dev/null < /dev/tty
    if [[ "$view_choice" == "v" || "$view_choice" == "V" ]]; then
      echo "Opening results in new tmux pane..."
      show_detailed_results "$latest_dir"
    fi
  fi
}

# Show results in pager with smart formatting
show_results_in_pager() {
  local json_file="$1"
  
  if [[ ! -f "$json_file" ]]; then
    echo "❌ Results file not found: $json_file"
    return 1
  fi
  
  # Determine the best pager and formatting approach
  local pager_cmd=""
  
  # Check for bat (with JSON syntax highlighting)
  if command -v bat >/dev/null 2>&1; then
    pager_cmd="bat --style=numbers,header --language=json"
  # Check for jq (with color formatting)
  elif command -v jq >/dev/null 2>&1; then
    pager_cmd="jq '.' --color-output"
  # Fallback to less with basic formatting
  else
    pager_cmd="less -R"
  fi
  
  # Display with chosen pager
  eval "$pager_cmd \"$json_file\""
}

# Show detailed results in a new tmux pane
show_detailed_results() {
  local results_dir="$1"
  
  # If results_dir points to a non-existent 'latest' directory, use the parent
  if [[ "$results_dir" == */latest ]] && [[ ! -d "$results_dir" ]]; then
    results_dir="${results_dir%/latest}"
    echo "💡 Using actual results directory: $results_dir"
  fi
  
  if [[ ! -d "$results_dir" ]]; then
    echo "❌ Results directory not found: $results_dir"
    return 1
  fi
  
  # Find the most recent result files for a more focused view
  local recent_files=$(ls -t "$results_dir"/*.json 2>/dev/null | head -5)
  
  if [[ -n "$recent_files" ]]; then
    # Create a command that shows recent results with nice formatting
    local view_cmd="echo '📁 Recent Profiling Results:' && echo '' && "
    view_cmd+="ls -lat '$results_dir'/*.json 2>/dev/null | head -10 && echo '' && "
    view_cmd+="echo '📄 Latest result preview:' && echo '' && "
    
    # Add bat/jq formatting if available
    if command -v bat >/dev/null 2>&1; then
      view_cmd+="bat --style=numbers,header --language=json \$(ls -t '$results_dir'/*.json | head -1) && "
    elif command -v jq >/dev/null 2>&1; then
      view_cmd+="jq '.' \$(ls -t '$results_dir'/*.json | head -1) && "
    else
      view_cmd+="cat \$(ls -t '$results_dir'/*.json | head -1) && "
    fi
    
    view_cmd+="echo '' && echo 'Press q to close' && read"
    
    # Create a new tmux pane with the enhanced view
    tmux split-window -v -c "$results_dir" "$view_cmd"
  else
    # Fallback to directory listing
    tmux split-window -v -c "$results_dir" \
      "echo '📁 Results Directory: $results_dir' && echo '' && ls -la && echo '' && echo 'Press q to close' && read"
  fi
}

# =============================================================================
# MAIN PROFILE SELECTION FUNCTION
# =============================================================================

# Enhanced fdata-profile with clean output and multi-profile support
fdata-profile() {
  local multi_profile_mode="false"
  local files=()
  
  # Parse arguments
  while [[ $# -gt 0 ]]; do
    case $1 in
      --help|-h)
        echo "📊 fdata-profile - Data Profiling Tool"
        echo "Usage: fdata-profile [OPTIONS] file1.csv [file2.json ...]"
        echo "       fdata-profile --multi file1.csv [file2.json ...]   # Multi-select mode"
        echo "       fdata-profile --list    # List available profiles"
        echo "       fdata-profile --config  # Show configuration"
        echo ""
        echo "Options:"
        echo "  --multi, -m    Enable multi-profile selection mode"
        return 0
        ;;
      --list)
        if [[ ${#PROFILING_REPORTS[@]} -eq 0 ]]; then
          load-profiling-config >/dev/null 2>&1
        fi
        discover_profiles >/dev/null 2>&1
        
        if [[ ${#DISCOVERED_PROFILES[@]} -eq 0 ]]; then
          echo "❌ No profiles found"
          return 1
        fi
        
        echo "📋 Available Profiles:"
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
      --multi|-m)
        multi_profile_mode="true"
        shift
        ;;
      --*)
        echo "❌ Unknown option: $1"
        echo "Use 'fdata-profile --help' for more information"
        return 1
        ;;
      *)
        files+=("$1")
        shift
        ;;
    esac
  done
  
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
  
  # Ensure configuration is loaded (silent)
  if [[ ${#PROFILING_REPORTS[@]} -eq 0 ]]; then
    load-profiling-config >/dev/null 2>&1 || return 1
  fi
  
  # Discover available profiles (silent)
  discover_profiles >/dev/null 2>&1 || return 1
  
  if [[ ${#DISCOVERED_PROFILES[@]} -eq 0 ]]; then
    echo "❌ No profiles found"
    return 1
  fi
  
  # Get compatible profiles and batch suites
  local compatible_profiles=($(get_compatible_profiles "${files[@]}" 2>/dev/null))
  
  # Build selection list
  local selection_list=()
  
  # Add individual profiles
  for profile in "${compatible_profiles[@]}"; do
    selection_list+=("$profile")
  done
  
  # Add batch suites if multi-file mode
  if [[ ${#files[@]} -gt 1 ]]; then
    local compatible_suites=($(get_compatible_batch_suites "${files[@]}" 2>/dev/null))
    for suite in "${compatible_suites[@]}"; do
      selection_list+=("🔄 $suite")
    done
  fi
  
  if [[ ${#selection_list[@]} -eq 0 ]]; then
    echo "❌ No compatible profiles found"
    return 1
  fi
  
  # Export files for preview function
  export FDATA_SELECTED_FILES="${(j: :)files}"
  
  # Configure fzf options based on mode
  local fzf_options=(
    --height=80%
    --preview="source \"$DOTFILES/zsh/productivity/fzf_profile.sh\" && _generate_profile_preview {} \"\$FDATA_SELECTED_FILES\""
    --preview-window="right:60%"
    --prompt="Profile: "
    --border=rounded
  )
  
  local header_text="🔍 Select profiler for: ${(j:, :)files} | ${#selection_list[@]} compatible"
  
  if [[ "$multi_profile_mode" == "true" ]]; then
    fzf_options+=(--multi)
    header_text="🔍 Multi-select: Tab to select profiles, Enter to confirm | Files: ${(j:, :)files} | ${#selection_list[@]} compatible"
  fi
  
  fzf_options+=(--header="$header_text")
  
  # Show selection with fzf
  local selected
  selected=$(printf '%s\n' "${selection_list[@]}" | fzf "${fzf_options[@]}")
  
  unset FDATA_SELECTED_FILES
  
  if [[ -z "$selected" ]]; then
    echo "❌ No profile selected"
    return 1
  fi
  
  # Process results based on mode
  if [[ "$multi_profile_mode" == "true" ]]; then
    # Handle multiple selected profiles
    local selected_profiles=()
    while IFS= read -r profile; do
      [[ -n "$profile" ]] && selected_profiles+=("$profile")
    done <<< "$selected"
    
    if [[ ${#selected_profiles[@]} -eq 0 ]]; then
      echo "❌ No profiles selected"
      return 1
    fi
    
    # Execute multiple profiles sequentially
    echo "✅ Selected profiles (${#selected_profiles[@]}): ${(j:, :)selected_profiles}"
    echo "📁 Files: ${(j:, :)files}"
    echo "🔄 Running ${#selected_profiles[@]} profile(s) on ${#files[@]} file(s):"
    echo ""
    
    local counter=1
    local total_start_time=$(date +%s.%N)
    
    for profile in "${selected_profiles[@]}"; do
      echo "[$counter/${#selected_profiles[@]}] Processing: $profile"
      
      if [[ "$profile" == "🔄 "* ]]; then
        local suite_name="${profile#🔄 }"
        run_batch_suite "$suite_name" "${files[@]}"
      else
        run_single_profile "$profile" "${files[@]}"
      fi
      
      echo ""
      ((counter++))
    done
    
    # Show total execution summary
    local total_end_time=$(date +%s.%N)
    local total_duration=$(echo "$total_end_time - $total_start_time" | bc -l)
    local total_duration_formatted=$(printf "%.1f" "$total_duration")
    echo "🎉 All profiles completed in ${total_duration_formatted}s"
    
  else
    # Single profile mode - execute the selected profile
    echo "✅ Selected: $selected"
    echo "📁 Files: ${(j:, :)files}"
    echo ""
    
    if [[ "$selected" == "🔄 "* ]]; then
      local suite_name="${selected#🔄 }"
      run_batch_suite "$suite_name" "${files[@]}"
    else
      run_single_profile "$selected" "${files[@]}"
    fi
  fi
}

# =============================================================================
# STATUS AND UTILITY FUNCTIONS
# =============================================================================

# Show current configuration status
show-profiling-config() {
  echo "🔧 Profiling Configuration Status"
  echo "================================="
  
  if [[ ${#PROFILING_REPORTS[@]} -eq 0 ]]; then
    echo "❌ Configuration not loaded"
    echo "💡 Run: load-profiling-config"
    return 1
  fi
  
  echo ""
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
  echo "⚙️  Settings:"
  for setting in "${(@k)PROFILING_SETTINGS}"; do
    echo "  • $setting: ${PROFILING_SETTINGS[$setting]}"
  done
}

# =============================================================================
# TAB COMPLETION SUPPORT
# =============================================================================

# Completion function for fdata-profile
_fdata_profile_completion() {
  local context curcontext="$curcontext" state line
  typeset -A opt_args

  _arguments -C \
    '--help[Show help]' \
    '--list[List available profiles]' \
    '--config[Show configuration]' \
    '--multi[Enable multi-profile selection mode]' \
    '-m[Enable multi-profile selection mode]' \
    '*:files:_files -g "*.csv *.tsv *.json *.jsonl *.parquet *.xlsx *.xls *.pkl *.pickle *.h5 *.hdf5 *.yaml *.yml"'
}

# Register completion
compdef _fdata_profile_completion fdata-profile

# =============================================================================
# ALIASES AND HELPERS
# =============================================================================

alias config-profiling='load-profiling-config'
alias show-config='show-profiling-config'
alias profile='fdata-profile'
alias profiles='fdata-profile --list'
alias profile-config='fdata-profile --config'
