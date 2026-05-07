# ~/.zshenv - Environment variables (always loaded)

# Locale
export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8
export LANGUAGE=en_US.UTF-8

# XDG Base Directory
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_CACHE_HOME="$HOME/.cache"

# Editor
export EDITOR="vim"
export VISUAL="vim"

# Dotfiles
export DOTFILES="$HOME/dotfiles"

# PATH — typeset -U ensures no duplicates even when sourced multiple times
typeset -U path
path=(
  $HOME/.local/bin
  $HOME/.cargo/bin
  /usr/local/go/bin
  $HOME/go/bin
  $path
)

# Go
export GOPATH="$HOME/go"
export CGO_ENABLED=0

# C++ — ccache cmake integration
export CMAKE_C_COMPILER_LAUNCHER=ccache
export CMAKE_CXX_COMPILER_LAUNCHER=ccache

# OpenBLAS — limit threads to physical cores, reserve main thread for Python
export OPENBLAS_NUM_THREADS=$(( $(nproc) / 2 ))
export OPENBLAS_MAIN_FREE=1

# Less
export LESS="-RF"

# Bat
export MANPAGER="sh -c 'col -bx | bat -l man -p'"
export MANROFFOPT="-c"

# Zoxide
export _ZO_ECHO=1
export _ZO_RESOLVE_SYMLINKS=1
export _ZO_EXCLUDE_DIRS="/tmp:/proc:/sys:/dev:/run:$HOME:$HOME/Downloads"

# Wayland
export MOZ_ENABLE_WAYLAND=1

export NO_AT_BRIDGE=1
