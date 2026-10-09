# See docs/architecture/zsh.md, "yts, the one locally-built app", for why this
# exists. A subshell keeps our cwd and `emulate` away from sysup's inhibitor
# trap. The directories are arguments so tests can drive this without
# touching the real checkout, install state or binary. Defaults match yts's
# Makefile: the install state (the installed commit) under
# ~/.local/share/yts-gui, the binaries in ~/.local/bin.
_sysup_yts() (
  emulate -L zsh
  trap - EXIT INT TERM
  local repo=${1:-"$HOME/projects/yts"}
  local prefix=${2:-"$HOME/.local/share/yts-gui"}
  local bindir=${3:-"$HOME/.local/bin"}
  local head installed changes

  if [[ ! -d $repo/.git ]]; then
    echo "    no checkout at $repo — skipping"
    return 0
  fi
  if [[ ! -d $prefix ]]; then
    echo "    not installed — skipping (run 'make install' in $repo)"
    return 0
  fi
  head=$(git -C "$repo" rev-parse HEAD) || return 1
  if [[ -r $prefix/.installed-commit ]]; then
    installed=$(<"$prefix/.installed-commit")
    installed=${installed//[[:space:]]/}
  else
    installed=""
  fi
  if [[ $installed == $head ]]; then
    echo "    already installed at ${head[1,7]}"
    return 0
  fi

  # Never promote a working tree (docs/architecture/zsh.md has the reasoning).
  # --untracked-files=all, not =no: an untracked file the build picks up (a new
  # header a tracked source includes) ships exactly like a modified one; yts's
  # .gitignore already excludes build/, so this doesn't trip on build litter.
  changes=$(git -C "$repo" status --porcelain --untracked-files=all) || return 1
  if [[ -n $changes ]]; then
    echo "    !! uncommitted changes in $repo — not installing"
    echo "       installed ${installed[1,7]:-unknown}, checkout ${head[1,7]}"
    return 1
  fi

  echo "    Installing ${installed[1,7]:-unknown} -> ${head[1,7]}"
  # -j8, the physical core count: cmake --build (inside make) reads this.
  export CMAKE_BUILD_PARALLEL_LEVEL=8
  # Gate on the tests before touching the installed build. `make install`
  # builds before it copies, so a failed build also leaves the previous binary
  # in place. stdout only, like the install below: a swallowed stderr leaves a
  # non-fatal step reporting a bare SHA, which is easy to scroll past and gives
  # nothing to act on.
  make -C "$repo" test >/dev/null || {
    echo "    !! tests fail at ${head[1,7]} — keeping the installed build"
    return 1
  }
  make -C "$repo" install >/dev/null || {
    echo "    !! make install failed — the installed build may be incomplete"
    return 1
  }
  # The binary is the point of the whole step, so prove it runs rather than
  # trusting that the install reported success.
  "$bindir/yts" --version >/dev/null 2>&1 || {
    echo "    !! the installed yts does not run"
    return 1
  }
  echo "    Installed ${head[1,7]}"
)
