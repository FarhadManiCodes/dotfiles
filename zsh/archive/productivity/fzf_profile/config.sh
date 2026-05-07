#!/usr/bin/env zsh
# =============================================================================
# FZF Profile Configuration Module
# Location: $DOTFILES/zsh/productivity/fzf_profile/config.sh
# =============================================================================

# Global configuration arrays (populated by load-profiling-config)
typeset -A PROFILING_REPORTS      # report_name -> description
typeset -A PROFILING_FILE_TYPES   # report_name -> "csv,json,parquet"
typeset -A PROFILING_BATCH_SUITES # suite_name -> "report1,report2,report3"
typeset -A PROFILING_SETTINGS     # setting_name -> value

# Global file type to reports mapping (built from individual reports)
typeset -A FILE_TYPE_PROFILES     # file_type -> "report1,report2,report3"

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