#!/usr/bin/env zsh
# =============================================================================
# Enhanced FZF Profile Selection System - Modular Orchestrator
# Location: $DOTFILES/zsh/productivity/fzf_profile.sh
# =============================================================================

# Module directory path
local _PROFILE_MODULE_DIR="$DOTFILES/zsh/productivity/fzf_profile"

# Check if modules directory exists
if [[ ! -d "$_PROFILE_MODULE_DIR" ]]; then
  echo "❌ Error: FZF Profile modules directory not found: $_PROFILE_MODULE_DIR"
  return 1
fi

# =============================================================================
# CORE MODULE LOADING
# =============================================================================

# Load essential modules (always loaded for performance)
source "$_PROFILE_MODULE_DIR/config.sh"    || { echo "❌ Failed to load config module"; return 1; }
source "$_PROFILE_MODULE_DIR/discovery.sh" || { echo "❌ Failed to load discovery module"; return 1; }
source "$_PROFILE_MODULE_DIR/ui.sh"        || { echo "❌ Failed to load ui module"; return 1; }
source "$_PROFILE_MODULE_DIR/execution.sh" || { echo "❌ Failed to load execution module"; return 1; }
source "$_PROFILE_MODULE_DIR/core.sh"      || { echo "❌ Failed to load core module"; return 1; }
source "$_PROFILE_MODULE_DIR/completion.sh" || { echo "❌ Failed to load completion module"; return 1; }

# Note: batch.sh is lazy-loaded in core.sh when batch functionality is needed

# =============================================================================
# INITIALIZATION
# =============================================================================

# Auto-load configuration if not already loaded
if [[ ${#PROFILING_REPORTS[@]} -eq 0 ]]; then
  load-profiling-config >/dev/null 2>&1
fi

# Clean up temporary variables
unset _PROFILE_MODULE_DIR

# =============================================================================
# MODULE LOADED SUCCESSFULLY
# =============================================================================
# All functions from the modules are now available:
# - fdata-profile (main function)
# - load-profiling-config, show-profiling-config
# - discover_profiles, get_compatible_profiles, get_compatible_batch_suites
# - run_single_profile, run_batch_suite, show_execution_results
# - _generate_profile_preview
# - create-batch-session (lazy loaded)
# - Tab completion and aliases
# =============================================================================