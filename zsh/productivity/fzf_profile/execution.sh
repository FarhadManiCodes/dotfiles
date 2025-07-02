#!/usr/bin/env zsh
# =============================================================================
# FZF Profile Execution Module
# Location: $DOTFILES/zsh/productivity/fzf_profile/execution.sh
# =============================================================================

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