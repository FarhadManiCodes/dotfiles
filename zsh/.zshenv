# ~/.zshenv - Environment variables (always loaded)

# Locale
export LC_ALL=en_US.UTF-8
export LANG=en_US.UTF-8
export LANGUAGE=en_US.UTF-8

# XDG Base Directory
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_STATE_HOME="$HOME/.local/state"
export XDG_CACHE_HOME="$HOME/.cache"

# IPython
export IPYTHONDIR="${XDG_CONFIG_HOME}/ipython"

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
  $path
)

# C++ — ccache cmake integration
export CMAKE_C_COMPILER_LAUNCHER=ccache
export CMAKE_CXX_COMPILER_LAUNCHER=ccache
# Always emit compile_commands.json (Ninja/Makefile generators) so clangd has it
# no matter how the tree was configured — cmake-init, a preset, or a bare cmake.
# Without this, only the tmux Prefix-C path produced it.
export CMAKE_EXPORT_COMPILE_COMMANDS=ON

# Apptainer — keep cache + build scratch on DISK, not the RAM-backed /tmp (tmpfs).
# CACHEDIR: persistent base-image/layer cache (reused across builds; clear with `apptainer cache clean`).
# TMPDIR:   per-build scratch (ephemeral; auto-cleaned after a successful build).
export APPTAINER_CACHEDIR="$XDG_CACHE_HOME/apptainer"
export APPTAINER_TMPDIR="$XDG_CACHE_HOME/apptainer/tmp"

# OpenBLAS — limit threads to physical cores, reserve main thread for Python.
# Governs the OpenBLAS bundled inside numpy/scipy wheels (they ignore system BLAS).
export OPENBLAS_NUM_THREADS=$(( $(nproc) / 2 ))

# AOCL BLIS — the same cap for C++. `-lblas` resolves to /usr/lib/libblas.so ->
# AOCL libblis-mt, which with no BLIS_NUM_THREADS/OMP_NUM_THREADS defaults to all
# 16 logical cores (measured). Pinned to physical cores to match the Python side
# and leave headroom for interactive work, consistent with -j and the rclone
# CPUWeight. Costs about 7.6% on an idle-machine 2000^3 dgemm: 5 runs each gave
# 469 GFLOP/s at 16 threads vs 433 at 8, with non-overlapping ranges. Accepted
# deliberately — SMT wins on throughput here, but saturating all 16 logical
# cores leaves nothing for interactive work.
export BLIS_NUM_THREADS=$(( $(nproc) / 2 ))
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

