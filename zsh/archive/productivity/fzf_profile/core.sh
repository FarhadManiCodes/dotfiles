#!/usr/bin/env zsh
# =============================================================================
# FZF Profile Core Module
# Location: $DOTFILES/zsh/productivity/fzf_profile/core.sh
# =============================================================================

# Lazy loading function for batch module
_load_batch_module() {
  if ! typeset -f create-batch-session >/dev/null 2>&1; then
    source "$DOTFILES/zsh/productivity/fzf_profile/batch.sh"
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
        echo ""
        echo "Interactive Keys:"
        echo "  Ctrl-R         Switch from single to multi-select mode"
        echo "  Tab            Select multiple profiles (in multi-select mode)"
        echo "  Enter          Confirm selection and execute"
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
  
  # Validate files exist and convert to absolute paths
  local missing_files=()
  local absolute_files=()
  for file in "${files[@]}"; do
    if [[ ! -f "$file" ]]; then
      missing_files+=("$file")
    else
      # Convert to absolute path
      local abs_path=$(realpath "$file" 2>/dev/null || readlink -f "$file" 2>/dev/null || echo "$(cd "$(dirname "$file")" && pwd)/$(basename "$file")")
      absolute_files+=("$abs_path")
    fi
  done
  
  # Replace files array with absolute paths
  files=("${absolute_files[@]}")
  
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
  else
    # Add keybinding for single mode to switch to multi mode
    header_text="$header_text | Ctrl-R: Switch to multi-select mode"
    fzf_options+=(--bind="ctrl-r:abort")
  fi
  
  fzf_options+=(--header="$header_text")
  
  # Show selection with fzf
  local selected
  selected=$(printf '%s\n' "${selection_list[@]}" | fzf "${fzf_options[@]}")
  local fzf_exit_code=$?
  
  unset FDATA_SELECTED_FILES
  
  # Handle Ctrl-R keybinding (fzf exits with code 130 when --bind abort is triggered)
  if [[ $fzf_exit_code -eq 130 ]] && [[ "$multi_profile_mode" != "true" ]]; then
    echo "🔄 Switching to multi-select mode..."
    fdata-profile --multi "${files[@]}"
    return $?
  fi
  
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
    
    # BATCH MODE DETECTION: Multi-file + multi-profile = batch processing
    if [[ ${#files[@]} -gt 1 ]] && [[ ${#selected_profiles[@]} -gt 1 ]]; then
      echo "🔄 Batch processing mode detected!"
      echo "📁 Files (${#files[@]}): ${(j:, :)files}"
      echo "🎯 Profiles (${#selected_profiles[@]}): ${(j:, :)selected_profiles}"
      echo ""
      
      # Ask user if they want to use batch session
      echo "💡 Options:"
      echo "  1. Batch session (parallel execution in tmux)"
      echo "  2. Sequential execution (current terminal)"
      echo -n "Choose [1-2, default=1]: "
      read -r batch_choice
      
      case "${batch_choice:-1}" in
        1)
          echo "🚀 Creating batch session for parallel execution..."
          # Load batch module lazily
          _load_batch_module
          # For multi-profile batch, we'll create a custom batch suite
          create_dynamic_batch_session "${selected_profiles[@]}" -- "${files[@]}"
          return $?
          ;;
        2)
          echo "▶️  Proceeding with sequential execution..."
          ;;
        *)
          echo "❌ Invalid choice"
          return 1
          ;;
      esac
    fi
    
    # Execute multiple profiles sequentially (traditional mode)
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
    # Single profile mode
    echo "✅ Selected: $selected"
    echo "📁 Files: ${(j:, :)files}"
    echo ""
    
    # BATCH MODE DETECTION: Multi-file + single profile/suite = batch processing
    if [[ ${#files[@]} -gt 1 ]] && [[ -n "$TMUX" ]]; then
      echo "🔄 Multi-file execution detected!"
      echo ""
      
      # Ask user if they want to use batch session
      echo "💡 Options:"
      echo "  1. Batch session (parallel execution in tmux windows)"
      echo "  2. Sequential execution (current terminal)"
      echo -n "Choose [1-2, default=1]: "
      read -r batch_choice
      
      case "${batch_choice:-1}" in
        1)
          echo "🚀 Creating batch session for parallel execution..."
          # Load batch module lazily
          _load_batch_module
          export PROFILE_TYPE="$selected"
          create-batch-session "${files[@]}"
          return $?
          ;;
        2)
          echo "▶️  Proceeding with sequential execution..."
          ;;
        *)
          echo "❌ Invalid choice"
          return 1
          ;;
      esac
    fi
    
    # Execute single profile (traditional mode)
    if [[ "$selected" == "🔄 "* ]]; then
      local suite_name="${selected#🔄 }"
      run_batch_suite "$suite_name" "${files[@]}"
    else
      run_single_profile "$selected" "${files[@]}"
    fi
  fi
}