#!/usr/bin/env zsh
# =============================================================================
# FZF Profile UI Module
# Location: $DOTFILES/zsh/productivity/fzf_profile/ui.sh
# =============================================================================

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