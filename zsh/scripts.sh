# activate the python v_end on the start
source "${HOME}/virtualenv/py_review/bin/activate"
. "$HOME/.cargo/env"
# Go optimizations
source "$HOME/.cargo/env"

# Go interactive features
# Add any Go-specific shell functions or aliases here
# Example: alias gob='go build'

# fzf shell integration (interactive features)
source <(fzf --zsh)

# fzf appearance settings (OneDark theme)
export FZF_DEFAULT_OPTS='
  --height 60%
  --layout=reverse
  --border=rounded
  --info=inline
  --prompt="❯ "
  --pointer="❯"
  --marker="❯"
  --preview-window=right:50%:hidden
  --bind="ctrl-p:toggle-preview"
  --bind="alt-p:toggle-preview"
  --bind="?:toggle-preview"
  --bind="ctrl-u:preview-page-up,ctrl-d:preview-page-down"
  --bind="ctrl-f:page-down,ctrl-b:page-up"
  --tiebreak=end
  --ansi
  --color=fg:#abb2bf,bg:#282c34,hl:#61afef
  --color=fg+:#ffffff,bg+:#3e4451,hl+:#61afef
  --color=info:#e5c07b,prompt:#61afef,pointer:#e06c75
  --color=marker:#98c379,spinner:#e5c07b,header:#c678dd'

# to zoxide to work
eval "$(zoxide init zsh)"
