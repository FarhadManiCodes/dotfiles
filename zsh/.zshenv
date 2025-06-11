# For dotfiles
export XDG_CONFIG_HOME="$HOME/.config"
# For specific data
export XDG_DATA_HOME="$XDG_CONFIG_HOME/local/share"
# For cached files
export XDG_CACHE_HOME="$XDG_CONFIG_HOME/cache"

export EDITOR="vim"
export VISUAL="vim"

export DOTFILES="$HOME/dotfiles"

# Go PATH and environment
export PATH=$PATH:/usr/local/go/bin
export GOPROXY=https://proxy.golang.org,direct
export GOSUMDB=sum.golang.org
export GOPATH=$HOME/go
export CGO_ENABLED=0

export PATH="$PATH:/home/farhad/install/fzf/bin"

# fzf PATH and environment
export PATH="$PATH:/home/farhad/install/fzf/bin"

# fzf file discovery with fd (prioritized types)
export FZF_DEFAULT_COMMAND='(fd -e py -e ipynb -e sql -e csv -e json -e yaml -e yml -e md -e sh -e toml -e env -e cfg -e log -e pkl -e pickle -e parquet -e xlsx -e xls -e h5 -e pt -e pth -e onnx --type f --hidden --follow --color=always --exclude .git --exclude .svn --exclude __pycache__ --exclude .pytest_cache --exclude .coverage --exclude .mypy_cache --exclude .tox --exclude dist --exclude build --exclude target --exclude .venv --exclude venv --exclude env --exclude .env.local --exclude .conda --exclude conda-env --exclude .ipynb_checkpoints --exclude .jupyter --exclude .dvc/cache --exclude mlruns --exclude wandb --exclude .tensorboard --exclude models/checkpoints --exclude .vscode --exclude .idea --exclude .DS_Store --exclude Thumbs.db --exclude .Trash --exclude .cache --exclude .tmp --exclude .temp --exclude node_modules --exclude .docker --exclude .torch --exclude data/raw --exclude data/cache --exclude data/processed; fd --type f --hidden --follow --color=always --exclude .git --exclude .svn --exclude __pycache__ --exclude .pytest_cache --exclude .coverage --exclude .mypy_cache --exclude .tox --exclude dist --exclude build --exclude target --exclude .venv --exclude venv --exclude env --exclude .env.local --exclude .conda --exclude conda-env --exclude .ipynb_checkpoints --exclude .jupyter --exclude .dvc/cache --exclude mlruns --exclude wandb --exclude .tensorboard --exclude models/checkpoints --exclude .vscode --exclude .idea --exclude .DS_Store --exclude Thumbs.db --exclude .Trash --exclude .cache --exclude .tmp --exclude .temp --exclude node_modules --exclude .docker --exclude .torch --exclude data/raw --exclude data/cache --exclude data/processed) 2>/dev/null | awk '"'"'!seen[$0]++'"'"
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --color=always --exclude .git --exclude .svn --exclude __pycache__ --exclude .pytest_cache --exclude .coverage --exclude .mypy_cache --exclude .tox --exclude dist --exclude build --exclude target --exclude .venv --exclude venv --exclude env --exclude .env.local --exclude .conda --exclude conda-env --exclude .ipynb_checkpoints --exclude .jupyter --exclude .dvc/cache --exclude mlruns --exclude wandb --exclude .tensorboard --exclude models/checkpoints --exclude .vscode --exclude .idea --exclude .DS_Store --exclude Thumbs.db --exclude .Trash --exclude .cache --exclude .tmp --exclude .temp --exclude node_modules --exclude .docker --exclude .torch --exclude data/raw --exclude data/cache --exclude data/processed'

# fzf preview with bat
export FZF_CTRL_T_OPTS="--preview 'bat --color=always --style=numbers --line-range=:500 {}' --preview-window=right:50%:hidden --bind='ctrl-p:toggle-preview,alt-p:toggle-preview,?:toggle-preview'"

# fzf tmux integration
if [ -n "$TMUX" ]; then
  export FZF_TMUX=1
  export FZF_TMUX_OPTS='-p 80%,70%'
fi

# z.lua configuration (environment variables)
export _ZL_CMD=z
export _ZL_DATA="$HOME/.zlua"
export _ZL_NO_PROMPT_COMMAND=1
export _ZL_EXCLUDE_DIRS="$HOME/.cache,/tmp,/var/tmp,/usr/share"
export _ZL_ADD_ONCE=1
export _ZL_MAXAGE=5000
export _ZL_CD=cd
