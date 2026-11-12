# Enhanced Git Shell Integration for Data Science
# ~/dotfiles/zsh/functions/git-enhancements.zsh

# ============================================================================
# COMMIT
# ============================================================================

# This repo's commit prefixes used more than once, most used first
# ("chore(nvim): "), then the base types for a new repo or a new kind of change.
_gci_prefixes() {
  {
    git log -200 --format=%s 2>/dev/null \
      | grep -oE '^[a-z]+(\([^)]*\))?!?: ' \
      | sort | uniq -c | sort -rn \
      | awk '$1 > 1 { sub(/^ *[0-9]+ /, ""); print }'
    print -l 'feat: ' 'fix: ' 'docs: ' 'refactor: ' 'chore: ' 'style: ' 'test: ' 'perf: '
  } | awk '!seen[$0]++'
}

# Pick a prefix, then write the message in the editor with the diff below it.
# Enter takes the highlighted entry, or the typed text when nothing matches;
# Alt-Enter always takes the typed text. Either way it ends in ": ".
# Quitting the editor without typing cancels: the prefix is a template, which
# git requires edited.
gci() {
  git rev-parse --git-dir >/dev/null || return
  if git diff --cached --quiet; then
    print -u2 "gci: nothing staged"
    return 1
  fi
  local prefix
  prefix=$(_gci_prefixes \
    | fzf --exact --prompt='prefix: ' --height=40% --bind 'enter:accept-or-print-query,alt-enter:print-query') \
    || return
  prefix=$(print -r -- "$prefix" | sed 's/[: ]*$/: /')
  # nvim opens commit messages at line 1, column 1 (autocmds.lua skips the
  # cursor restore); startinsert! begins typing after the prefix instead.
  GIT_EDITOR="nvim -c 'startinsert!'" git commit --verbose --template =(print -r -- "$prefix")
}

# ============================================================================
# GIT STATUS
# ============================================================================

# git status without the hints or the branch and upstream lines; starship shows
# the branch. Colors and columns are forced only on a terminal, which git cannot
# see through the pipe.
gst() {
  setopt local_options pipefail
  local -a tty=()
  [[ -t 1 ]] && tty=(-c color.status=always -c column.status=always)
  COLUMNS=$COLUMNS git -c advice.statusHints=false "${tty[@]}" \
    status --no-ahead-behind "$@" \
    | awk '
      /^(On branch |Your branch is up to date |Your branch and .* refer to different commits)/ { next }
      !seen && /^$/ { next }
      { seen = 1; print }'
}

# Custom gitignore generator (replicating the 'gi' command)
function gi() {
  curl -sLw "\n" --max-time 10 https://www.toptal.com/developers/gitignore/api/$@
}
# ============================================================================
# ALIASES - Git Workflow Shortcuts
# ============================================================================

# Git add aliases (from oh-my-zsh git plugin)
alias ga='git add'
alias gaa='git add --all'
alias gapa='git add --patch'
alias gav='git add --verbose'

# Git commit aliases (from oh-my-zsh git plugin)
alias gc='git commit --verbose'
alias gca='git commit --verbose --all'
alias gcam='git commit --all --message'
alias gcmsg='git commit --message'
alias gcf='git config --list'

# Git log aliases (from oh-my-zsh git plugin)
alias glo='git log --oneline --decorate'
alias glog='git log --oneline --decorate --graph'
alias gloga='git log --oneline --decorate --graph --all'
alias glol='git log --graph --pretty="%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ar) %C(bold blue)<%an>%Creset"'
alias glola='git log --graph --pretty="%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ar) %C(bold blue)<%an>%Creset" --all'
alias glols='git log --graph --pretty="%Cred%h%Creset -%C(auto)%d%Creset %s %Cgreen(%ar) %C(bold blue)<%an>%Creset" --stat'

# Enhanced git log aliases (your custom ones)
alias gl='git lg'   # Pretty git log (your custom format)
alias gld='git lgd' # Detailed git log with files (your custom format)

# Git utility aliases
alias gdvc='git dvc-status' # Combined git + DVC status
alias ginfo='git info'      # Quick repo info

# Git navigation aliases
alias gco='git checkout'
alias gcb='git checkout -b'

# Experiment management aliases
alias gexp='git exp-start' # Start new experiment branch
alias gexpl='git exp-list' # List experiment branches
