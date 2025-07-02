#!/usr/bin/env zsh
# =============================================================================
# FZF Profile Completion and Aliases Module
# Location: $DOTFILES/zsh/productivity/fzf_profile/completion.sh
# =============================================================================

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