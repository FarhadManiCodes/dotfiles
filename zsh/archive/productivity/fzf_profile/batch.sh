#!/usr/bin/env zsh
# =============================================================================
# FZF Profile Batch Management Module (Lazy Loaded)
# Location: $DOTFILES/zsh/productivity/fzf_profile/batch.sh
# =============================================================================

# =============================================================================
# BATCH SESSION MANAGEMENT FUNCTIONS
# =============================================================================

# Create and manage batch profiling session
create-batch-session() {
  local files=("$@")
  local profile_type="$PROFILE_TYPE"  # Set by fdata-profile caller
  
  if [[ ${#files[@]} -eq 0 ]]; then
    echo "❌ No files provided for batch processing"
    return 1
  fi
  
  # Generate unique session name with timestamp
  local session_name="profiling-batch-$(date +%H%M%S)"
  
  # Ensure we're not already in the batch session
  if [[ -n "$TMUX" ]]; then
    local current_session=$(tmux display-message -p '#S')
    if [[ "$current_session" == profiling-batch-* ]]; then
      echo "⚠️  Already in batch session: $current_session"
      return 1
    fi
  fi
  
  echo "🔄 Creating batch session: $session_name"
  echo "📁 Files (${#files[@]}): ${(j:, :)files}"
  echo "🎯 Profile type: $profile_type"
  
  # Create progress tracking directory
  local progress_dir="/tmp/profiling_progress/$session_name"
  mkdir -p "$progress_dir"
  
  # Create batch session (detached)
  if ! tmux new-session -d -s "$session_name" -c "$PWD"; then
    echo "❌ Failed to create batch session"
    return 1
  fi
  
  # Set environment variables for the batch session
  tmux send-keys -t "$session_name" "export PROFILING_BATCH_MODE=true" Enter
  tmux send-keys -t "$session_name" "export PROFILING_SESSION_ID=$session_name" Enter
  tmux send-keys -t "$session_name" "export PROFILING_PROGRESS_DIR=$progress_dir" Enter
  tmux send-keys -t "$session_name" "export PROFILING_OUTPUT_DIR=/tmp/profiling_results/$(date +%Y%m%d)" Enter
  
  # Execute batch profiles
  execute-batch-profiles "$session_name" "$profile_type" "${files[@]}"
  
  # Show initial batch summary in current terminal
  echo ""
  echo "📊 Batch Session Started"
  echo "======================="
  echo "Session: $session_name"
  echo "Progress: $progress_dir"
  echo "Files: ${(j:, :)files}"
  echo "Profile: $profile_type"
  echo ""
  
  # Show initial status
  show_batch_results_summary "$progress_dir" "$session_name"
  
  echo ""
  echo "💡 Batch execution started in tmux session: $session_name"
  echo "💡 You can:"
  echo "   - Monitor: tmux attach -t $session_name"
  echo "   - Switch: tmux switch-client -t $session_name (if in tmux)"
  echo "   - Check progress: show_batch_results_summary '$progress_dir' '$session_name'"
  echo ""
  
  # Ask user if they want to switch to the session
  echo -n "🔀 Switch to batch session now? [Y/n]: "
  read -r switch_choice
  
  case "${switch_choice:-Y}" in
    [Yy]*)
      if [[ -n "$TMUX" ]]; then
        echo "🔀 Switching to batch session for monitoring..."
        tmux switch-client -t "$session_name"
      else
        echo "🎯 Attaching to batch session..."
        tmux attach-session -t "$session_name"
      fi
      ;;
    *)
      echo "✅ Staying in current terminal. Batch runs in background."
      echo "💡 Use: tmux attach -t $session_name (when ready to monitor)"
      ;;
  esac
  
  return 0
}

# Execute profiles in parallel tmux windows within batch session
execute-batch-profiles() {
  local batch_session="$1"
  local profile_type="$2"
  shift 2
  local files=("$@")
  
  local progress_dir="/tmp/profiling_progress/$batch_session"
  
  # Determine if this is a single profile or batch suite
  local is_batch_suite=false
  local suite_reports=()
  
  if [[ "$profile_type" == "🔄 "* ]]; then
    is_batch_suite=true
    local suite_name="${profile_type#🔄 }"
    local suite_reports_str="${PROFILING_BATCH_SUITES[$suite_name]}"
    
    if [[ -z "$suite_reports_str" ]]; then
      echo "❌ Batch suite '$suite_name' not found in configuration"
      return 1
    fi
    
    suite_reports=(${(s:,:)suite_reports_str})
    # Clean whitespace from report names
    suite_reports=("${suite_reports[@]// /}")
    
    echo "📦 Executing batch suite '$suite_name' with ${#suite_reports[@]} profiles"
  else
    echo "🔄 Executing single profile '$profile_type'"
  fi
  
  # Create execution windows (accounting for windows starting at 1)
  local window_counter=1  # Windows start from 1 in your config
  local is_first_window=true
  
  for file in "${files[@]}"; do
    local file_basename=$(basename "$file")
    local file_clean=$(echo "$file_basename" | sed 's/[^a-zA-Z0-9_-]/_/g')
    
    if [[ "$is_batch_suite" == "true" ]]; then
      # Create window for each profile in the suite for this file
      for report in "${suite_reports[@]}"; do
        [[ -z "$report" ]] && continue
        
        local window_name="${file_clean}_${report}"
        local progress_prefix="${file_clean}_${report}"
        
        # Handle first window (rename existing) vs new windows
        if [[ "$is_first_window" == "true" ]]; then
          # Rename the initial window (window 1)
          tmux rename-window -t "$batch_session:1" "$window_name"
          local target_window="$batch_session:1"
          is_first_window=false
        else
          # Create new window (tmux will auto-number starting from 2)
          tmux new-window -t "$batch_session" -n "$window_name"
          local target_window="$batch_session:$window_name"
        fi
        
        # Set up progress tracking for this window
        setup-profile-progress "$progress_dir" "$file" "$report" "$progress_prefix" "$target_window"
        
        # Execute the profile in this window
        execute-profile-in-window "$target_window" "$report" "$file" "$progress_prefix" "$progress_dir"
        
        ((window_counter++))
      done
    else
      # Single profile mode
      local window_name="${file_clean}_${profile_type}"
      local progress_prefix="${file_clean}_${profile_type}"
      
      # Handle first window (rename existing) vs new windows
      if [[ "$is_first_window" == "true" ]]; then
        # Rename the initial window (window 1)
        tmux rename-window -t "$batch_session:1" "$window_name"
        local target_window="$batch_session:1"
        is_first_window=false
      else
        # Create new window (tmux will auto-number starting from 2)
        tmux new-window -t "$batch_session" -n "$window_name"
        local target_window="$batch_session:$window_name"
      fi
      
      # Set up progress tracking for this window
      setup-profile-progress "$progress_dir" "$file" "$profile_type" "$progress_prefix" "$target_window"
      
      # Execute the profile in this window
      execute-profile-in-window "$target_window" "$profile_type" "$file" "$progress_prefix" "$progress_dir"
      
      ((window_counter++))
    fi
  done
  
  echo "✅ Created $((window_counter - 1)) execution windows"
  
  # Create a summary/navigation window
  tmux new-window -t "$batch_session" -n "batch-summary"
  setup-batch-summary-window "$batch_session" "$progress_dir" $((window_counter - 1))
  
  # Select the summary window
  tmux select-window -t "$batch_session:batch-summary"
  
  return 0
}

# Set up progress tracking for a single profile execution
setup-profile-progress() {
  local progress_dir="$1"
  local file="$2" 
  local profile="$3"
  local progress_prefix="$4"
  local tmux_window="$5"
  
  # Create progress files
  echo "pending" > "$progress_dir/${progress_prefix}.status"
  echo "$(date +%s.%N)" > "$progress_dir/${progress_prefix}.start_time"
  echo "$file" > "$progress_dir/${progress_prefix}.file"
  echo "$profile" > "$progress_dir/${progress_prefix}.profile"
  echo "$tmux_window" > "$progress_dir/${progress_prefix}.window"
  
  # Create empty log file
  touch "$progress_dir/${progress_prefix}.log"
}

# Execute a profile in a specific tmux window
execute-profile-in-window() {
  local target_window="$1"
  local profile="$2"
  local file="$3"
  local progress_prefix="$4"
  local progress_dir="$5"  # Pass progress dir as parameter
  
  # Get profiling directory
  local profiling_dir="${PROFILING_SETTINGS[profiling_dir]:-$HOME/projects/profiling}"
  local results_dir="${PROFILING_SETTINGS[results_dir]:-/tmp/profiling_results}/$(date +%Y%m%d)"
  
  # Build command with explicit absolute paths - no environment variables
  local progress_file="$progress_dir/${progress_prefix}.status"
  
  local cmd="echo 'Starting profile: $profile on $file...' && "
  cmd+="echo 'running' > \"$progress_file\" && "
  cmd+="python3 \"$profiling_dir/profile_runner.py\" --report \"$profile\" --file \"$file\" --output-dir \"$results_dir\" && "
  cmd+="echo 'complete' > \"$progress_file\" && "
  cmd+="echo 'Profile completed successfully' || "
  cmd+="(echo 'error' > \"$progress_file\" && echo 'Profile failed')"
  
  # Send the command to the window
  tmux send-keys -t "$target_window" "$cmd" Enter
}

# Set up the batch summary/navigation window  
setup-batch-summary-window() {
  local batch_session="$1"
  local progress_dir="$2"
  local window_count="$3"
  
  local summary_window="$batch_session:batch-summary"
  
  # Simple monitoring script
  local monitor_cmd="
echo '🔄 Batch Session: $batch_session'
echo '📊 Windows: $window_count'
echo ''
echo 'Press Enter to monitor, w for window list, q to quit...'
read -k 1 choice
case \$choice in
  'q'|'Q') exit 0 ;;
  'w'|'W') tmux choose-tree -t '$batch_session' ;;
esac

while true; do
  clear
  echo '🔄 Batch Progress - \$(date +%H:%M:%S)'
  echo '========================='
  
  local total=0
  local done=0
  
  for f in \"$progress_dir\"/*.status; do
    [[ -f \"\$f\" ]] || continue
    total=\$((total + 1))
    local s=\$(cat \"\$f\" 2>/dev/null || echo 'pending')
    [[ \"\$s\" == 'complete' ]] && done=\$((done + 1))
  done
  
  echo \"📈 \$done / \$total completed\"
  echo ''
  
  for f in \"$progress_dir\"/*.status; do
    [[ -f \"\$f\" ]] || continue
    local name=\${f##*/}
    name=\${name%.status}
    local s=\$(cat \"\$f\" 2>/dev/null || echo 'pending')
    case \$s in
      'complete') echo \"✅ \$name\" ;;
      'running') echo \"🔄 \$name\" ;;
      'error') echo \"❌ \$name\" ;;
      *) echo \"⏳ \$name\" ;;
    esac
  done
  
  echo ''
  if [[ \$total -gt 0 ]] && [[ \$done -eq \$total ]]; then
    echo '🎉 All done! Press any key to exit...'
    read -k 1
    exit 0
  fi
  
  echo 'Ctrl+C to stop, w for windows'
  sleep 3
done
"
  
  # Send the monitoring script to the summary window
  tmux send-keys -t "$summary_window" "$monitor_cmd" Enter
}

# Create dynamic batch session for multiple profiles on multiple files
create_dynamic_batch_session() {
  local profiles=()
  local files=()
  local parsing_files=false
  
  # Parse arguments: profiles before --, files after --
  for arg in "$@"; do
    if [[ "$arg" == "--" ]]; then
      parsing_files=true
      continue
    fi
    
    if [[ "$parsing_files" == "true" ]]; then
      files+=("$arg")
    else
      profiles+=("$arg")
    fi
  done
  
  if [[ ${#profiles[@]} -eq 0 ]] || [[ ${#files[@]} -eq 0 ]]; then
    echo "❌ No profiles or files provided for dynamic batch processing"
    return 1
  fi
  
  # Generate unique session name with timestamp
  local session_name="profiling-batch-$(date +%H%M%S)"
  
  # Ensure we're not already in the batch session
  if [[ -n "$TMUX" ]]; then
    local current_session=$(tmux display-message -p '#S')
    if [[ "$current_session" == profiling-batch-* ]]; then
      echo "⚠️  Already in batch session: $current_session"
      return 1
    fi
  fi
  
  echo "🔄 Creating dynamic batch session: $session_name"
  echo "📁 Files (${#files[@]}): ${(j:, :)files}"
  echo "🎯 Profiles (${#profiles[@]}): ${(j:, :)profiles}"
  
  # Create progress tracking directory
  local progress_dir="/tmp/profiling_progress/$session_name"
  mkdir -p "$progress_dir"
  
  # Create batch session (detached)
  if ! tmux new-session -d -s "$session_name" -c "$PWD"; then
    echo "❌ Failed to create batch session"
    return 1
  fi
  
  # Set environment variables for the batch session
  tmux send-keys -t "$session_name" "export PROFILING_BATCH_MODE=true" Enter
  tmux send-keys -t "$session_name" "export PROFILING_SESSION_ID=$session_name" Enter
  tmux send-keys -t "$session_name" "export PROFILING_PROGRESS_DIR=$progress_dir" Enter
  tmux send-keys -t "$session_name" "export PROFILING_OUTPUT_DIR=/tmp/profiling_results/$(date +%Y%m%d)" Enter
  
  # Execute dynamic batch profiles
  execute_dynamic_batch_profiles "$session_name" "${profiles[@]}" -- "${files[@]}"
  
  # Show initial batch summary in current terminal
  echo ""
  echo "📊 Dynamic Batch Session Started"
  echo "================================"
  echo "Session: $session_name"
  echo "Progress: $progress_dir"
  echo "Files (${#files[@]}): ${(j:, :)files}"
  echo "Profiles (${#profiles[@]}): ${(j:, :)profiles}"
  echo ""
  
  # Show initial status
  show_batch_results_summary "$progress_dir" "$session_name"
  
  echo ""
  echo "💡 Dynamic batch execution started in tmux session: $session_name"
  echo "💡 You can:"
  echo "   - Monitor: tmux attach -t $session_name"
  echo "   - Switch: tmux switch-client -t $session_name (if in tmux)"
  echo "   - Check progress: show_batch_results_summary '$progress_dir' '$session_name'"
  echo ""
  
  # Ask user if they want to switch to the session
  echo -n "🔀 Switch to batch session now? [Y/n]: "
  read -r switch_choice
  
  case "${switch_choice:-Y}" in
    [Yy]*)
      if [[ -n "$TMUX" ]]; then
        echo "🔀 Switching to batch session for monitoring..."
        tmux switch-client -t "$session_name"
      else
        echo "🎯 Attaching to batch session..."
        tmux attach-session -t "$session_name"
      fi
      ;;
    *)
      echo "✅ Staying in current terminal. Batch runs in background."
      echo "💡 Use: tmux attach -t $session_name (when ready to monitor)"
      ;;
  esac
  
  return 0
}

# Execute dynamic profiles (multiple profiles on multiple files)
execute_dynamic_batch_profiles() {
  local batch_session="$1"
  shift
  
  local profiles=()
  local files=()
  local parsing_files=false
  
  # Parse arguments: profiles before --, files after --
  for arg in "$@"; do
    if [[ "$arg" == "--" ]]; then
      parsing_files=true
      continue
    fi
    
    if [[ "$parsing_files" == "true" ]]; then
      files+=("$arg")
    else
      profiles+=("$arg")
    fi
  done
  
  local progress_dir="/tmp/profiling_progress/$batch_session"
  
  echo "📦 Executing ${#profiles[@]} profiles on ${#files[@]} files"
  
  # Create execution windows (accounting for windows starting at 1)
  local window_counter=1  # Windows start from 1 in your config
  local is_first_window=true
  
  # Create a window for each file + profile combination
  for file in "${files[@]}"; do
    local file_basename=$(basename "$file")
    local file_clean=$(echo "$file_basename" | sed 's/[^a-zA-Z0-9_-]/_/g')
    
    for profile in "${profiles[@]}"; do
      # Handle batch suite profiles
      if [[ "$profile" == "🔄 "* ]]; then
        local suite_name="${profile#🔄 }"
        local suite_reports_str="${PROFILING_BATCH_SUITES[$suite_name]}"
        
        if [[ -n "$suite_reports_str" ]]; then
          local suite_reports=(${(s:,:)suite_reports_str})
          suite_reports=("${suite_reports[@]// /}")  # Clean whitespace
          
          # Create window for each report in the suite for this file
          for report in "${suite_reports[@]}"; do
            [[ -z "$report" ]] && continue
            
            local window_name="${file_clean}_${report}"
            local progress_prefix="${file_clean}_${report}"
            
            # Handle first window (rename existing) vs new windows
            if [[ "$is_first_window" == "true" ]]; then
              # Rename the initial window (window 1)
              tmux rename-window -t "$batch_session:1" "$window_name"
              local target_window="$batch_session:1"
              is_first_window=false
            else
              # Create new window (tmux will auto-number starting from 2)
              tmux new-window -t "$batch_session" -n "$window_name"
              local target_window="$batch_session:$window_name"
            fi
            
            # Set up progress tracking for this window
            setup-profile-progress "$progress_dir" "$file" "$report" "$progress_prefix" "$target_window"
            
            # Execute the profile in this window
            execute-profile-in-window "$target_window" "$report" "$file" "$progress_prefix" "$progress_dir"
            
            ((window_counter++))
          done
        fi
      else
        # Regular profile
        local window_name="${file_clean}_${profile}"
        local progress_prefix="${file_clean}_${profile}"
        
        # Handle first window (rename existing) vs new windows
        if [[ "$is_first_window" == "true" ]]; then
          # Rename the initial window (window 1)
          tmux rename-window -t "$batch_session:1" "$window_name"
          local target_window="$batch_session:1"
          is_first_window=false
        else
          # Create new window (tmux will auto-number starting from 2)
          tmux new-window -t "$batch_session" -n "$window_name"
          local target_window="$batch_session:$window_name"
        fi
        
        # Set up progress tracking for this window
        setup-profile-progress "$progress_dir" "$file" "$profile" "$progress_prefix" "$target_window"
        
        # Execute the profile in this window
        execute-profile-in-window "$target_window" "$profile" "$file" "$progress_prefix" "$progress_dir"
        
        ((window_counter++))
      fi
    done
  done
  
  echo "✅ Created $((window_counter - 1)) execution windows"
  
  # Create a summary/navigation window
  tmux new-window -t "$batch_session" -n "batch-summary"
  setup-batch-summary-window "$batch_session" "$progress_dir" $((window_counter - 1))
  
  # Select the summary window
  tmux select-window -t "$batch_session:batch-summary"
  
  return 0
}

# Generate batch execution summary
generate_batch_summary() {
  local progress_dir="$1"
  local session_id="$2"
  local output_file="$3"
  
  if [[ ! -d "$progress_dir" ]]; then
    echo "❌ Progress directory not found: $progress_dir"
    return 1
  fi
  
  local results_dir="${PROFILING_SETTINGS[results_dir]:-/tmp/profiling_results}/$(date +%Y%m%d)"
  
  # Create summary JSON
  cat > "$output_file" << EOF
{
  "session_id": "$session_id",
  "generated_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "progress_dir": "$progress_dir",
  "results_dir": "$results_dir",
  "executions": [
EOF
  
  local first_entry=true
  local total_executions=0
  local completed_executions=0
  local failed_executions=0
  local total_duration=0
  
  for status_file in "$progress_dir"/*.status; do
    [[ -f "$status_file" ]] || continue
    
    local prefix=${status_file##*/}
    prefix=${prefix%.status}
    local file_status=$(cat "$status_file" 2>/dev/null || echo 'unknown')
    
    local execution_file=$(cat "$progress_dir/${prefix}.file" 2>/dev/null || echo 'unknown')
    local profile=$(cat "$progress_dir/${prefix}.profile" 2>/dev/null || echo 'unknown')
    local window=$(cat "$progress_dir/${prefix}.window" 2>/dev/null || echo 'unknown')
    local start_time=$(cat "$progress_dir/${prefix}.start_time" 2>/dev/null || echo '')
    local end_time=$(cat "$progress_dir/${prefix}.end_time" 2>/dev/null || echo '')
    
    # Calculate duration if both times are available
    local duration=""
    if [[ -n "$start_time" && -n "$end_time" ]]; then
      duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo '')
      if [[ -n "$duration" ]] && [[ "$duration" =~ ^[0-9]+\.?[0-9]*$ ]]; then
        total_duration=$(echo "$total_duration + $duration" | bc -l 2>/dev/null || echo "$total_duration")
      fi
    fi
    
    # Add comma separator for subsequent entries
    if [[ "$first_entry" != "true" ]]; then
      echo "    ," >> "$output_file"
    fi
    first_entry=false
    
    # Write execution entry
    cat >> "$output_file" << EOF
    {
      "prefix": "$prefix",
      "file": "$execution_file",
      "profile": "$profile",
      "window": "$window",
      "status": "$file_status",
      "start_time": "$start_time",
      "end_time": "$end_time",
      "duration": "$duration"
    }
EOF
    
    ((total_executions++))
    case "$file_status" in
      'complete') ((completed_executions++)) ;;
      'error') ((failed_executions++)) ;;
    esac
  done
  
  # Close executions array and add summary
  cat >> "$output_file" << EOF
  ],
  "summary": {
    "total_executions": $total_executions,
    "completed": $completed_executions,
    "failed": $failed_executions,
    "pending": $((total_executions - completed_executions - failed_executions)),
    "total_duration": "$total_duration",
    "success_rate": "$(echo "scale=2; $completed_executions * 100 / $total_executions" | bc -l 2>/dev/null || echo '0')%"
  }
}
EOF
  
  echo "📄 Batch summary generated: $output_file"
  return 0
}

# Show simple batch results summary  
show_batch_results_summary() {
  local progress_dir="$1"
  local session_id="$2"
  
  if [[ ! -d "$progress_dir" ]]; then
    echo "❌ Progress directory not found: $progress_dir"
    return 1
  fi
  
  echo "📊 Batch: $session_id"
  echo "===================="
  
  # Simple status count
  local total=0
  local completed=0
  local running=0
  local errors=0
  
  for status_file in "$progress_dir"/*.status; do
    [[ -f "$status_file" ]] || continue
    ((total++))
    local file_status=$(cat "$status_file" 2>/dev/null || echo 'pending')
    case "$file_status" in
      'complete') ((completed++)) ;;
      'running') ((running++)) ;;
      'error') ((errors++)) ;;
    esac
  done
  
  if [[ $total -eq 0 ]]; then
    echo "⏳ Starting up..."
    return 0
  fi
  
  echo "📈 $total total | ✅ $completed done | 🔄 $running active | ❌ $errors failed"
  
  # Show simple file list
  echo ""
  echo "📋 Files:"
  for status_file in "$progress_dir"/*.status; do
    [[ -f "$status_file" ]] || continue
    local prefix=${status_file##*/}
    prefix=${prefix%.status}
    local file_status=$(cat "$status_file" 2>/dev/null || echo 'pending')
    
    case "$file_status" in
      'complete') echo "  ✅ $prefix" ;;
      'running') echo "  🔄 $prefix" ;;
      'error') echo "  ❌ $prefix" ;;
      *) echo "  ⏳ $prefix" ;;
    esac
  done
}