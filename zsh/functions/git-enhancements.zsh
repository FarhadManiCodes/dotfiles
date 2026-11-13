# Git shell functions and aliases: gci, gst, gi.

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
  [[ -n $prefix ]] || return 1 # Alt-Enter with nothing typed
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

# .gitignore templates from gitignore.io: gi python node >> .gitignore
gi() {
  if (($# == 0)); then
    print -u2 'usage: gi <template>...  (gi list shows them)'
    return 2
  fi
  curl -fsSL --max-time 10 "https://www.toptal.com/developers/gitignore/api/${(j:,:)@}"
}
# ============================================================================
# ALIASES
# ============================================================================

alias ga='git add'
alias gc='git commit --verbose'
alias gca='git commit --verbose --all'
alias ginfo='git info' # repository, branch, remote and last commit

# The current branch drawn with git-graph; `glol master` adds master alongside.
# Only HEAD by default: git-graph orders commits by time, so all branches
# interleave whenever two moved together. It has no pager of its own.
glol() {
  git-graph --color always --model simple --style round --wrap none \
    --format '%h%d %s (%as) <%an>' HEAD "$@" | less -RFS
}
