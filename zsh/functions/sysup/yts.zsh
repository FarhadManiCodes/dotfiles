# See docs/architecture/zsh.md, "yts, the one locally-built app", for why this
# exists. A subshell keeps our cwd and `emulate` away from sysup's inhibitor
# trap. Both directories are arguments so tests can drive this without
# touching the real checkout or install — `make install` runs `uv venv
# --clear`, which would wipe a live prefix. Defaults match yts's Makefile.
_sysup_yts() (
  emulate -L zsh
  trap - EXIT INT TERM
  local repo=${1:-"$HOME/projects/yts"}
  local prefix=${2:-"$HOME/.local/share/yts-gui"}
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
  # --untracked-files=all, not =no: an untracked new module ships exactly like
  # a modified one under `uv pip install .`; yts's .gitignore already excludes
  # ordinary build litter, so this doesn't trip on that.
  changes=$(git -C "$repo" status --porcelain --untracked-files=all) || return 1
  if [[ -n $changes ]]; then
    echo "    !! uncommitted changes in $repo — not installing"
    echo "       installed ${installed[1,7]:-unknown}, checkout ${head[1,7]}"
    return 1
  fi

  echo "    Installing ${installed[1,7]:-unknown} -> ${head[1,7]}"
  # Gate on the tests before touching the installed build: `make install`
  # clears the app venv, so a failure part-way leaves nothing to fall back to.
  # stdout only, like the install below: a swallowed stderr leaves a non-fatal
  # step reporting a bare SHA, which is easy to scroll past and gives nothing
  # to act on.
  make -C "$repo" test >/dev/null || {
    echo "    !! tests fail at ${head[1,7]} — keeping the installed build"
    return 1
  }
  make -C "$repo" install >/dev/null || {
    echo "    !! make install failed — the installed build may be incomplete"
    return 1
  }
  # The launchers are the point of the whole step, so prove one imports rather
  # than trusting that pip reported success.
  "$prefix/venv/bin/python" -c 'import yts.app, yts.fuzzel' 2>/dev/null || {
    echo "    !! the installed build does not import"
    return 1
  }
  echo "    Installed ${head[1,7]}"
)
