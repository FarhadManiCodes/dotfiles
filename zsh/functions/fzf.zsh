# ============================================================================
# FZF Global Configuration
# ============================================================================

# Default fzf options (applied to all fzf invocations)
# Colors: One Half Dark theme
export FZF_DEFAULT_OPTS="
  --height 40%
  --layout=reverse
  --border
  --color=fg:#dcdfe4,bg:#282c34,hl:#e06c75
  --color=fg+:#dcdfe4,bg+:#2c323c,hl+:#e06c75
  --color=info:#61afef,prompt:#98c379,pointer:#c678dd
  --color=marker:#e5c07b,spinner:#56b6c2,header:#56b6c2
  --bind 'ctrl-p:toggle-preview'
  --bind 'ctrl-d:preview-down,ctrl-u:preview-up'
  --preview-window 'right:50%:hidden'"

# Open as tmux popup when inside a tmux session
[[ -n "$TMUX" ]] && export FZF_DEFAULT_OPTS="$FZF_DEFAULT_OPTS --tmux center,80%"

# Default command for bare `fzf` and Ctrl+T
# Uses fd: fast, respects .gitignore, excludes .git. --one-file-system (here
# and in every finder below, search.zsh and vifm-pick) keeps fd out of the
# ~/Cloud rclone mounts: from ~ it walked the whole Drive (minutes) instead of
# 0.3 s locally.
export FZF_DEFAULT_COMMAND='fd --one-file-system --type f --hidden --follow --exclude .git'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"

# Ctrl+T — file search with bat preview
export FZF_CTRL_T_OPTS="--preview 'bat --color=always --line-range :50 {}'"

# Alt+C — directory jump with eza tree preview
export FZF_ALT_C_COMMAND='fd --one-file-system --type d --hidden --follow --exclude .git'
export FZF_ALT_C_OPTS="--preview 'eza --tree --icons --level=2 {}'"

# Ctrl+R — history search; exact match + full command preview
export FZF_CTRL_R_OPTS="
  --exact
  --preview 'echo {}'
  --preview-window 'down:3:wrap'"

# ============================================================================
# Data Science Finders (cherry-picked from old fzf-enhancements)
#
# fnb and fdata are MIRRORED in bash/vifm-pick (vifm needs a script, and these
# cd, which only works in the interactive shell). The fdata extension list is
# identical in both — change one, change the other.
# ============================================================================

# Jupyter notebook finder — Enter: edit, Ctrl+D: cd to folder
# Enter used to launch jupyter (or tmux-jupyter-auto). Neither exists any
# more: the tmux helper was deleted in 6388290 and jupyter is not installed, so
# both branches only ever printed "not available". Opens in $EDITOR instead,
# matching fdata and the application/x-ipynb+json -> vim.desktop mapping in
# mimeapps.list.
fnb() {
  local -a fd_cmd=(fd --one-file-system --type f --extension ipynb)
  local preview='
    echo "📊 Size: $(du -h --apparent-size {} 2>/dev/null | cut -f1)"
    echo "📅 Modified: $(date -r {} "+%F %R" 2>/dev/null)"
    echo "📝 Cells: $(jq ".cells | length" {} 2>/dev/null || echo unknown)"'
  local result=$("${fd_cmd[@]}" 2>/dev/null | fzf --preview "$preview" \
    --preview-window='right:30%' \
    --expect 'ctrl-d' \
    --bind 'ctrl-o:execute(timeout 2 open-detached "$(dirname {})")' \
    --header 'Enter: edit notebook, Ctrl+D: cd to folder, Ctrl+O: open folder')

  local key file
  _fzf_split "$result" key file

  if [[ -n "$file" ]]; then
    local dir=$(dirname "$file")
    if [[ "$key" == "ctrl-d" ]]; then
      cd "$dir" && pwd
    else
      ${EDITOR:-vim} "$file"
    fi
  fi
}

# Data/model file finder — Enter: edit, Ctrl+D: cd, Ctrl+V: copy path
fdata() {
  local -a exts=(csv tsv jsonl ndjson json yaml yml parquet avro orc feather
    xlsx xls pkl pickle joblib h5 hdf5 pt pth onnx)
  local -a fd_cmd=(fd --one-file-system --type f --extension=${^exts}
    --exclude __pycache__ --exclude node_modules --exclude venv)
  local preview='
    echo "📁 $(basename {})"
    echo "📊 $(du -h --apparent-size {} 2>/dev/null | cut -f1)"
    echo
    bat --color=always --style=plain --line-range=:12 {} 2>/dev/null \
      || head -8 {} 2>/dev/null'
  local result
  result=$("${fd_cmd[@]}" 2>/dev/null | fzf --preview="$preview" \
    --preview-window='right:40%' \
    --expect 'ctrl-d,ctrl-v' \
    --bind 'ctrl-o:execute(open-detached "$(dirname {})")' \
    --header '📊 Data & Model Files | Enter: edit | Ctrl+D: cd | Ctrl+V: copy path | Ctrl+O: open folder')

  local key file
  _fzf_split "$result" key file

  if [[ -n "$file" ]]; then
    case "$key" in
      ctrl-d)
        cd "$(dirname "$file")"
        echo "📁 Changed to: $(pwd) — $(basename "$file")"
        ;;
      ctrl-v)
        local full_path=$(realpath "$file" 2>/dev/null || echo "$file")
        if command -v wl-copy >/dev/null 2>&1; then
          echo -n "$full_path" | wl-copy && echo "📋 Copied: $full_path"
        else
          echo "📋 Path: $full_path"
        fi
        ;;
      *)
        local size=$(stat -c%s "$file" 2>/dev/null || echo "0")
        if [[ "$size" -gt 50000000 ]]; then
          cd "$(dirname "$file")" && echo "🚨 Large file (>50MB) — navigated to folder instead"
        else
          "${EDITOR:-vim}" "$file"
        fi
        ;;
    esac
  fi
}
