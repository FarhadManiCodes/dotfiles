export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8
export LANGUAGE=en_US.UTF-8

# XKB specific variables
export XKB_DEFAULT_RULES=evdev
export XKB_DEFAULT_MODEL=pc105
export XKB_DEFAULT_LAYOUT=us
# For dotfile
export XDG_CONFIG_HOME="$HOME/.config"
# For specific data
export XDG_DATA_HOME="$XDG_CONFIG_HOME/local/share"
# For cached files
export XDG_CACHE_HOME="$XDG_CONFIG_HOME/cache"

export EDITOR="vim"
export VISUAL="vim"

export DOTFILES="$HOME/dotfiles"


# add paths
export PATH="$HOME/.local/bin:$PATH"
export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig:$PKG_CONFIG_PATH
export LD_LIBRARY_PATH=/usr/local/lib:$LD_LIBRARY_PATH

# Go PATH and environment
export PATH=$PATH:/usr/local/go/bin
export PATH=$PATH:$HOME/go/bin
export GOPROXY=https://proxy.golang.org,direct
export GOSUMDB=sum.golang.org
export GOPATH=$HOME/go
export CGO_ENABLED=0


# fzf PATH and environment
export PATH="$PATH:/home/farhad/install/fzf/bin"

# fzf file discovery with fd (prioritized types)
export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git 2>/dev/null || find . -type f 2>/dev/null'
# ===== FZF THEME SETTINGS =====
export FZF_DEFAULT_OPTS='
  --height 60%
  --layout=reverse
  --border=rounded
  --info=inline
  --prompt="❯ "
  --pointer="❯"
  --marker="❯"
  --tiebreak=end
  --ansi
  --color=fg:#abb2bf,bg:#282c34,hl:#61afef
  --color=fg+:#ffffff,bg+:#3e4451,hl+:#61afef
  --color=info:#e5c07b,prompt:#61afef,pointer:#e06c75
  --color=marker:#98c379,spinner:#e5c07b,header:#c678dd'

export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"

export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --color=always --exclude .git --exclude .svn --exclude __pycache__ --exclude .pytest_cache --exclude .coverage --exclude .mypy_cache --exclude .tox --exclude dist --exclude build --exclude target --exclude .venv --exclude venv --exclude env --exclude .env.local --exclude .conda --exclude conda-env --exclude .ipynb_checkpoints --exclude .jupyter --exclude .dvc/cache --exclude mlruns --exclude wandb --exclude .tensorboard --exclude models/checkpoints --exclude .vscode --exclude .idea --exclude .DS_Store --exclude Thumbs.db --exclude .Trash --exclude .cache --exclude .tmp --exclude .temp --exclude node_modules --exclude .docker --exclude .torch --exclude data/raw --exclude data/cache --exclude data/processed'

# fzf preview with bat
export FZF_CTRL_T_OPTS="--preview 'bat --color=always --style=numbers --line-range=:500 {}' --preview-window=right:50%:hidden --bind='ctrl-p:toggle-preview,alt-p:toggle-preview,?:toggle-preview'"

# fzf tmux integration
if [ -n "$TMUX" ]; then
  export FZF_TMUX=1
  export FZF_TMUX_OPTS='-p 80%,70%'
fi

export BAT_THEME="OneHalfDark"

# zoxide setting
export _ZO_ECHO=1           # Print matched directory before jumping
export _ZO_RESOLVE_SYMLINKS=1  # Resolve symlinks when adding paths
export _ZO_FZF_OPTS="--height=40% --layout=reverse --border"  # Customize fzf if using zi

# node.js
export NVM_DIR="$HOME/.config/nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
