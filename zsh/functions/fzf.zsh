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
# Uses fd: fast, respects .gitignore, excludes .git
export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"

# Ctrl+T — file search with bat preview
export FZF_CTRL_T_OPTS="--preview 'bat --color=always --line-range :50 {}'"

# Alt+C — directory jump with eza tree preview
export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'
export FZF_ALT_C_OPTS="--preview 'eza --tree --icons --level=2 {}'"

# Ctrl+R — history search; exact match + full command preview
export FZF_CTRL_R_OPTS="--exact --preview 'echo {}' --preview-window 'down:3:wrap' --bind 'ctrl-p:toggle-preview'"

# ============================================================================
# Data Science Finders (cherry-picked from old fzf-enhancements)
# ============================================================================

# Jupyter notebook finder — Enter: open, Ctrl+D: cd to folder
fnb() {
  local result=$(fd --type f --extension ipynb 2>/dev/null |
    fzf --preview 'echo "📊 Size: $(ls -lh {} 2>/dev/null | awk "{print \$5}" || echo "unknown")" && echo "📅 Modified: $(ls -l {} 2>/dev/null | awk "{print \$6, \$7, \$8}" || echo "unknown")" && echo "📝 Cells: $(jq ".cells | length" {} 2>/dev/null || echo "unknown")"' \
      --preview-window='right:30%' \
      --expect 'ctrl-d' \
      --bind 'ctrl-o:execute(timeout 2 xdg-open $(dirname {}) 2>/dev/null &)' \
      --header 'Enter: open notebook, Ctrl+D: cd to folder, Ctrl+O: open folder')

  local key=$(echo "$result" | head -1)
  local file=$(echo "$result" | tail -1)

  if [ -n "$file" ]; then
    local dir=$(dirname "$file")
    if [ "$key" = "ctrl-d" ]; then
      cd "$dir" && pwd
    else
      echo "📁 Changing to: $dir"
      cd "$dir"
      if [ -n "$TMUX" ]; then
        tmux-jupyter-auto 2>/dev/null || echo "tmux-jupyter-auto not available"
      else
        jupyter notebook "$(basename "$file")" 2>/dev/null || echo "Jupyter not available"
      fi
    fi
  fi
}

# Data/model file finder — Enter: edit, Ctrl+D: cd, Ctrl+V: copy path
fdata() {
  local result
  result=$(fd --type f \
    -e csv -e tsv -e jsonl -e ndjson \
    -e json -e yaml -e yml \
    -e parquet -e avro -e orc -e feather \
    -e xlsx -e xls \
    -e pkl -e pickle -e joblib \
    -e h5 -e hdf5 \
    -e pt -e pth -e onnx \
    --exclude __pycache__ --exclude .git --exclude node_modules --exclude .venv --exclude venv \
    --exclude "*.tmp" --exclude "*.cache" |
    fzf --preview='echo "📁 $(basename {})" && echo "📊 $(ls -lh {} 2>/dev/null | awk "{print \$5}" || echo "unknown")" && echo "" &&
                   if command -v bat >/dev/null 2>&1; then
                     bat --color=always --style=plain --line-range=:12 {} 2>/dev/null || head -8 {} 2>/dev/null
                   else
                     head -8 {} 2>/dev/null
                   fi' \
      --preview-window='right:40%' \
      --expect 'ctrl-d,ctrl-v' \
      --bind 'ctrl-o:execute(xdg-open $(dirname {}) 2>/dev/null &)' \
      --header '📊 Data & Model Files | Enter: edit | Ctrl+D: cd | Ctrl+V: copy path | Ctrl+O: open folder')

  local key=$(echo "$result" | head -1)
  local file=$(echo "$result" | tail -1)

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
