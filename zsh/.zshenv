# ~/.zshenv - Environment variables (always loaded)

# Locale. LANG only, on purpose -- it is the fallback every category inherits.
#
# LC_ALL=en_US.UTF-8 used to be here and was removed 2026-09-04. It sits at the top of the
# precedence chain, so it silently overrode every per-category setting: `LC_TIME=de_DE.UTF-8
# date` did nothing, in this file, in environment.d, or inline on a command. It is meant as a
# temporary override for deterministic script output, not a permanent setting. Removing it
# changed no behaviour on its own -- with LANG set and no LC_* set, every category still
# resolves to en_US.UTF-8 -- it only stopped blocking the German categories now in
# environment.d/defaults.conf.
#
# LANGUAGE=en_US.UTF-8 went with it. LANGUAGE is a GNU gettext variable taking a
# colon-separated list of *language codes* (en_US:en), never a locale with a charset, so
# ".UTF-8" could not match and gettext fell through to LC_MESSAGES anyway.
export LANG=en_US.UTF-8

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

# Central Python virtualenvs.
#
# Here rather than in zsh/functions/virtualenv.zsh, which is where it used to
# live, because that file is sourced from .zshrc and so only runs in
# INTERACTIVE shells. The variable was therefore unset for scripts, for
# non-interactive `zsh -c`, and for any agent or tool invocation -- while
# CLAUDE.md's environment table listed it beside DOTFILES and XDG_* as though
# it were always present. It could still look set in those contexts by being
# inherited from the interactive shell that launched them, which is what made
# the gap easy to miss.
#
# Only the export moved. Creating the directory stays in virtualenv.zsh: this
# file runs on every single zsh invocation, and doing filesystem work there to
# support an interactive-only tool would be the wrong trade.
export CENTRAL_VENVS="$HOME/.central_venvs"

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

# OpenBLAS — match worker count to this machine's 8 physical cores, not its 16
# logical CPUs. nproc / 2 is a machine-specific approximation, not a topology query.
# Applies to non-OpenMP OpenBLAS builds, including those bundled in numpy/scipy wheels.
export OPENBLAS_NUM_THREADS=$(( $(nproc) / 2 ))

# AOCL BLIS — the same worker count for C++ projects linking AOCL explicitly
# (see docs/system-notes.md; there is no global -lblas adapter). With neither
# BLIS_NUM_THREADS nor OMP_NUM_THREADS, it used all 16 logical CPUs (measured).
# Matching the physical-core count aims to reduce contention, but does not pin
# workers or reserve CPUs. Costs about 7.6% on an idle-machine 2000^3 dgemm: 5 runs each gave
# 469 GFLOP/s at 16 threads vs 433 at 8, with non-overlapping ranges. Accepted
# deliberately — SMT won throughput in that test; interactive headroom is a
# policy goal, not guaranteed CPU isolation.
export BLIS_NUM_THREADS=$(( $(nproc) / 2 ))
# Disable OpenBLAS automatic CPU affinity where enabled; does not reserve a main CPU.
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
