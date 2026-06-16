# ============================================================================
# Search Functions (ripgrep + fzf + fd)
# Live/interactive search - type and results update dynamically
# Ctrl+p toggles preview
# ============================================================================

# ----------------------------------------------------------------------------
# fhist - fuzzy search shell history, edit and run
# Usage: fhist [initial-query]
# ----------------------------------------------------------------------------
fhist() {
  local initial_query="${*:-}"
  local selected=$(fc -l 1 | fzf --tac --no-sort --query="$initial_query" \
      --preview 'echo {}' \
      --preview-window='hidden,down:3:wrap' \
      --bind 'ctrl-p:toggle-preview')

  [[ -z "$selected" ]] && return 0
  local cmd=$(echo "$selected" | sed 's/^[[:space:]]*[0-9]*[[:space:]]*//')

  # Put in command line buffer for editing before execution
  print -z "$cmd"
}

# ----------------------------------------------------------------------------
# _rg_live - helper for live ripgrep search functions
# Usage: _rg_live "rg-args" [initial-query]
# ----------------------------------------------------------------------------
_rg_live() {
  local rg_args="$1"
  shift
  local initial_query="${*:-}"

  local result=$(fzf --ansi --disabled --query="$initial_query" \
      --bind "change:reload:rg --color=always --line-number $rg_args {q} || true" \
      --bind "start:reload:rg --color=always --line-number $rg_args {q} || true" \
      --delimiter=: \
      --preview 'bat --color=always --highlight-line {2} {1} 2>/dev/null' \
      --preview-window='hidden,right:60%:+{2}-10' \
      --bind 'ctrl-p:toggle-preview' \
      --expect='ctrl-d' \
      --header='Enter: nvim | Ctrl-d: cd to folder')

  [[ -z "$result" ]] && return 0

  local key selection
  _fzf_split "$result" key selection
  [[ -z "$selection" ]] && return 0

  local file="${selection%%:*}"
  local line="${${selection#*:}%%:*}"

  case "$key" in
    ctrl-d)
      builtin cd "$(dirname "$file")"
      ;;
    *)
      nvim "+$line" "$file"
      ;;
  esac
}

# ----------------------------------------------------------------------------
# rgf - live ripgrep search → open file at line in nvim
# Usage: rgf [initial-query]
# ----------------------------------------------------------------------------
rgf() { _rg_live "" "$@"; }

# ----------------------------------------------------------------------------
# rgcpp - live search C/C++ files only
# ----------------------------------------------------------------------------
rgcpp() { _rg_live "--type cpp --type c" "$@"; }

# ----------------------------------------------------------------------------
# rgtex - live search LaTeX files only
# ----------------------------------------------------------------------------
rgtex() { _rg_live "-g '*.tex' -g '*.sty' -g '*.cls' -g '*.bib'" "$@"; }

# ----------------------------------------------------------------------------
# rgpy - live search Python files only
# ----------------------------------------------------------------------------
rgpy() { _rg_live "--type py" "$@"; }

# ----------------------------------------------------------------------------
# ff - find file by name → open with handlr (xdg-open fallback)
# Usage: ff [pattern]
# Keys: Enter → open | Ctrl-d → cd | Ctrl-o → open folder
# ----------------------------------------------------------------------------
ff() {
  local result=$(fd --type f "$@" 2>/dev/null | \
    fzf --preview 'bat --color=always --line-range=:100 {}' \
        --preview-window='hidden,right:60%' \
        --bind 'ctrl-p:toggle-preview' \
        --expect='ctrl-d,ctrl-o' \
        --header='Enter: open | Ctrl-d: cd | Ctrl-o: open folder')

  [[ -z "$result" ]] && return 0

  local key file
  _fzf_split "$result" key file
  [[ -z "$file" ]] && return 0

  case "$key" in
    ctrl-d)
      builtin cd "$(dirname "$file")"
      ;;
    ctrl-o)
      xdg-open "$(dirname "$file")" 2>/dev/null &
      ;;
    *)
      case "$file" in
        *.md|*.markdown)
          glow -p "$file"
          ;;
        *)
          local mime
          mime=$(file --mime-type -b "$file")
          if [[ "$mime" == text/* ]]; then
            xdg-open "$file"
          else
            xdg-open "$file" 2>/dev/null &
          fi
          ;;
      esac
      ;;
  esac
}

# ----------------------------------------------------------------------------
# fdir - find directory → cd into it
# Usage: fdir [pattern]
# Keys: Enter → cd, Ctrl-o → open in file manager
# ----------------------------------------------------------------------------
fdir() {
  local result=$(fd --type d "$@" 2>/dev/null | \
    fzf --preview 'eza -la --color=always {}' \
        --preview-window='hidden,right:60%' \
        --bind 'ctrl-p:toggle-preview' \
        --expect='ctrl-o' \
        --header='Enter: cd | Ctrl-o: open folder')

  [[ -z "$result" ]] && return 0

  local key dir
  _fzf_split "$result" key dir
  [[ -z "$dir" ]] && return 0

  case "$key" in
    ctrl-o)
      xdg-open "$dir" 2>/dev/null &
      ;;
    *)
      builtin cd "$dir"
      ;;
  esac
}

# ----------------------------------------------------------------------------
# rgt - live search with interactive type selection
# ----------------------------------------------------------------------------
rgt() {
  local types="cpp\nc\npy\ntex\nmd\njson\nyaml\ntoml\nsh\nrust\ngo"
  local type=$(echo -e "$types" | fzf --prompt="File type: " --height=40%)
  [[ -z "$type" ]] && return 0
  _rg_live "--type $type" "$@"
}

# ----------------------------------------------------------------------------
# fgit - find git repositories, preview status, open lazygit or fetch
# Usage: fgit [search-path]
# Keys: Enter → lazygit, Ctrl-f → git fetch, Ctrl-d → cd to repo
# ----------------------------------------------------------------------------
fgit() {
  local search_path="${1:-$HOME}"

  local result=$(fd --type d --hidden '^\.git$' "$search_path" 2>/dev/null | \
    sed 's|/\.git$||' | \
    fzf --preview 'git -C {} log --oneline -10 2>/dev/null; echo ""; git -C {} status -s 2>/dev/null' \
        --preview-window='right:50%:hidden' \
        --bind 'ctrl-p:toggle-preview' \
        --expect='ctrl-f,ctrl-d' \
        --header='Enter: lazygit | Ctrl-f: fetch | Ctrl-d: cd')

  [[ -z "$result" ]] && return 0

  local key repo
  _fzf_split "$result" key repo
  [[ -z "$repo" ]] && return 0

  case "$key" in
    ctrl-f)
      echo "Fetching $repo..."
      git -C "$repo" fetch --all --prune
      ;;
    ctrl-d)
      builtin cd "$repo"
      ;;
    *)
      lazygit -p "$repo"
      ;;
  esac
}

# ----------------------------------------------------------------------------
# fbranch - fuzzy git branch checkout
# ----------------------------------------------------------------------------
fbranch() {
  local branch=$(git branch -a --color=always | \
    fzf --ansi --preview 'git log --oneline --color=always {1} | head -20' \
        --preview-window='hidden,right:50%' \
        --bind 'ctrl-p:toggle-preview' | \
    sed 's/^[* ]*//' | sed 's/remotes\/[^/]*\///')
  [[ -n "$branch" ]] && git checkout "$branch"
}

# ----------------------------------------------------------------------------
# fman - fuzzy man page search
# ----------------------------------------------------------------------------
fman() {
  local page=$(man -k . 2>/dev/null | \
    fzf --preview 'man {1} 2>/dev/null | col -b | head -100' \
        --preview-window='hidden,right:60%' \
        --bind 'ctrl-p:toggle-preview')
  [[ -n "$page" ]] && man "$(echo "$page" | awk '{print $1}')"
}
