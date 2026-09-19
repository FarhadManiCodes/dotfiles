# =============================================================================
# Direnv-based Virtual Environment Management (Powered by uv)
# Location: ~/.config/zsh/functions/virtualenv.zsh
# =============================================================================

# CENTRAL_VENVS is exported from zsh/.zshenv, NOT here -- this file is sourced
# from .zshrc, so anything defined here exists only in interactive shells. See
# the comment there for why that mattered.
#
# This file's own `_VENV_` globals are unexported: implementation, not a knob.
typeset -g _VENV_DEFAULT_PYTHON="3.13"

# Creating the directory does stay here: .zshenv runs on every zsh invocation
# and should not touch the filesystem for an interactive-only tool. Guarded on
# the variable being non-empty so a `zsh -f` (no rcs) cannot mkdir "".
[[ -n "$CENTRAL_VENVS" && ! -d "$CENTRAL_VENVS" ]] && mkdir -p "$CENTRAL_VENVS"

# Both hard dependencies; fzf is optional and reported by _select_env instead.
for _venv_tool in uv direnv; do
  command -v "$_venv_tool" >/dev/null 2>&1 ||
    echo "⚠️  $_venv_tool not found! Virtual environment functions will not work."
done
unset _venv_tool

# =============================================================================
# VALIDATION HELPERS
# =============================================================================

# The shared lint set is appended to each template rather than repeated in it.
# "none" has no list of its own -- it installs requirements.txt if there is one.
typeset -gA _VENV_TEMPLATE_PACKAGES=(
  basic "requests pytest"
  ds    "ipython jupyter pandas numpy scipy matplotlib seaborn scikit-learn plotly"
  de    "ipython jupyter pandas polars duckdb sqlalchemy great-expectations requests pyarrow"
  ml    "ipython jupyter pandas numpy matplotlib seaborn scikit-learn plotly"
)
typeset -ga _VENV_LINT_PACKAGES=(black flake8 pylint mypy)
typeset -ga _VENV_TEMPLATES=("${(ok)_VENV_TEMPLATE_PACKAGES[@]}" none)

# (Ie) is an exact-element match; a substring test would accept a partial name.
_is_template() { (( ${_VENV_TEMPLATES[(Ie)$1]} )); }

# Match a Python version number: 3.9, 3.12, 3.12.1 (any major, so 3.15+ keeps working)
_is_version() {
  local arg="$1"
  [[ "$arg" =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ ]]
}

_is_local_name() {
  local name="$1"
  [[ "$name" == "local" || "$name" == "." ]]
}

# A name must be one path component: "../x", "a/b" and ".." all make _env_path
# resolve OUTSIDE $CENTRAL_VENVS, and vr runs `rm -rf` on whatever it returns.
# Whitespace is out too -- _select_env returns the second word of its listing,
# so a picked "my app" came back as "my".
_is_valid_name() {
  [[ -n "$1" && "$1" != *[/[:space:]]* && "$1" != ".." ]]
}

# =============================================================================
# CORE HELPER FUNCTIONS
# =============================================================================

_env_path() {
  local name="$1"
  if _is_local_name "$name"; then
    echo ".venv"
  else
    echo "$CENTRAL_VENVS/$name"
  fi
}

_env_exists() {
  local name="$1"
  _is_valid_name "$name" || return 1
  [[ -d "$(_env_path "$name")" ]]
}

# Human-readable size of a dir, "?" if unreadable. The fallback must apply to the
# captured value: `du | cut` exits 0 even when du fails, so a `||` never fires.
_dir_size() { local size=$(du -sh "$1" 2>/dev/null | cut -f1); echo "${size:-?}"; }

# Bare Python version (e.g. 3.13.1) for a venv's python binary
_py_ver() { local ver=$("$1" --version 2>/dev/null | awk '{print $2}'); echo "${ver:-?}"; }

# _get_envrc_env [file] — name of the env an .envrc points to ("local" or central name)
_get_envrc_env() {
  local file="${1:-.envrc}"
  [[ -f "$file" ]] || return 1
  local content="$(<"$file")"

  # Local .venv — _create_envrc writes `source .venv/bin/activate` (./ optional)
  if [[ "$content" == *"source "(|./)".venv/bin/activate"* ]]; then
    echo "local"
    return 0
  fi

  # Centralized — the name is the path component after $CENTRAL_VENVS, read from
  # the variable so relocating it can't break this silently. Glob, not a sed
  # regex: the "." in the path would be a regex wildcard.
  if [[ -n "$CENTRAL_VENVS" && "$content" == *"source ${CENTRAL_VENVS}/"* ]]; then
    local rest="${content#*source ${CENTRAL_VENVS}/}"
    echo "${rest%%/*}"
  fi
}

# Sets the CALLER's $name (zsh locals are dynamically scoped), defaulting to local.
_prompt_name() {
  read "name?Environment name (Enter for local): "
  [[ -z "$name" ]] && name="local"
}

_reload_direnv() {
  if direnv allow . && direnv reload; then
    echo "✅ Environment reloaded"
  else
    echo "❌ Failed to reload direnv"
    return 1
  fi
}

_select_env() {
  local prompt="${1:-🐍 Select environment: }"

  # A project-local .venv is offered FIRST when the current directory has one.
  # It is deliberately not added to _list_environments: that backs `vl`'s
  # "Centralized environments ($CENTRAL_VENVS)" heading, which a local entry
  # would make untrue. `uv venv` creates .venv by default, so this is the common
  # project layout, and without it a bare `va` reported "(no environments
  # found)" with a perfectly good .venv sitting in the current directory.
  local -a entries
  [[ -d ".venv" ]] && entries+=("   🐍 local (./.venv)")

  # fast: the picker only needs names — skip the per-venv du/python walk.
  # The "(no environments found)" placeholder is dropped, or picking it would
  # feed awk a line whose $2 is the word "environments".
  local line
  while IFS= read -r line; do
    [[ "$line" == *"(no environments found)"* ]] && continue
    entries+=("$line")
  done < <(_list_environments fast)

  # Informational output goes to stderr throughout: stdout here IS the return
  # value (callers use `selected=$(_select_env)`), so anything echoed to stdout
  # is taken as an environment name.
  if (( ${#entries[@]} == 0 )); then
    echo "📋 No environments found (create one with: vc <name>, or vc local)" >&2
    return 1
  fi

  if ! command -v fzf >/dev/null; then
    printf '%s\n' "📋 Available environments:" "${entries[@]}" >&2
    echo "💡 Install fzf for interactive selection" >&2
    return 1
  fi

  printf '%s\n' "${entries[@]}" | fzf --prompt="$prompt" --height=40% | awk '{print $2}'
}

# Write the .envrc that activates env "$1"; back up any non-generated .envrc first
_create_envrc() {
  local env_name="$1"
  local venv_path="$(_env_path "$env_name")"

  # Safety check for existing custom .envrc
  if [[ -f ".envrc" ]]; then
    # If it doesn't contain our signature, it might be a manual file
    if ! grep -q "# Auto-generated" .envrc; then
        echo "⚠️  Existing .envrc found (not auto-generated)."
        echo "   It might contain custom variables."
        read "reply?Overwrite? [y/N]: "
        [[ ! "$reply" =~ ^[Yy]$ ]] && echo "❌ Skipped .envrc creation" && return 0

        # Create backup
        cp .envrc ".envrc.bak.$(date +%s)"
        echo "💾 Backed up old .envrc"
    fi
  fi

  cat > .envrc << EOF
# Auto-generated - Virtual Environment: $env_name
source $venv_path/bin/activate
EOF
  direnv allow .
  echo "📄 Created .envrc"
}

# _list_environments [fast]
# fast: print names only — skips the per-venv `du -sh` (full disk walk) and
# `python --version` fork. Used by the interactive picker, which only needs names.
_list_environments() {
  local fast="$1"
  # (N-/): no match yields nothing, and only directories match, following
  # symlinks as the old `[[ -d ]]` test did. The -d guard keeps an unset
  # CENTRAL_VENVS from globbing "/*".
  local -a envs
  [[ -d "$CENTRAL_VENVS" ]] && envs=("$CENTRAL_VENVS"/*(N-/))
  (( ${#envs} )) || { echo "   (no environments found)"; return; }

  local env_dir
  for env_dir in "${envs[@]}"; do
    [[ -n "$fast" ]] && { echo "   🐍 ${env_dir:t}"; continue; }
    echo "   🐍 ${env_dir:t} ($(_dir_size "$env_dir")) [Py $(_py_ver "$env_dir/bin/python")]"
  done
}

_install_template() {
  local template="${1:-none}"
  local python_path="$VIRTUAL_ENV/bin/python"

  if [[ "$template" == "none" ]]; then
    [[ -f "requirements.txt" ]] || { echo "📝 Empty environment created"; return; }
    echo "📦 Installing from requirements.txt..."
    uv pip install -r requirements.txt --python "$python_path"
    return
  fi

  # ${+assoc[key]} distinguishes an unknown template from one with no packages.
  if (( ! ${+_VENV_TEMPLATE_PACKAGES[$template]} )); then
    echo "❌ Unknown template: $template"
    echo "💡 Available: ${_VENV_TEMPLATES[*]}"
    return 1
  fi

  echo "📦 Installing $template packages..."
  uv pip install ${=_VENV_TEMPLATE_PACKAGES[$template]} "${_VENV_LINT_PACKAGES[@]}" \
    --python "$python_path"
  [[ "$template" == "ml" ]] &&
    echo "💡 For PyTorch/TensorFlow, run 'uv pip install torch' manually."
}

# =============================================================================
# MAIN FUNCTIONS
# =============================================================================

# Create virtual environment
# Usage: vc [name] [template] [version]
vc() {
  local name template version arg

  # Classify each argument by what it looks like, not by its position. The
  # positional ladder this replaces needed one branch per argument shape, and
  # both misparse bugs it had came from shapes it did not cover. Order is now
  # free: `vc ds myapp` and `vc myapp ds` mean the same thing.
  for arg in "$@"; do
    if _is_version "$arg"; then
      version="$arg"
    elif _is_template "$arg"; then
      template="$arg"
    elif [[ -z "$name" ]]; then
      name="$arg"
    else
      echo "❌ Unexpected argument: $arg"
      echo "Usage: vc [name] [template] [version]   (run 'vh' for examples)"
      return 1
    fi
  done
  : ${template:=none} ${version:=$_VENV_DEFAULT_PYTHON}
  [[ -z "$name" ]] && _prompt_name

  # Only reachable from the prompt now, since a template-shaped argument becomes
  # $template above. A slashed or spaced name would escape $CENTRAL_VENVS or
  # break the picker's name parsing.
  if _is_template "$name" || ! _is_valid_name "$name"; then
    echo "❌ Error: Invalid environment name '$name'"
    echo "💡 Use a plain name, no spaces or '/', and not a template name"
    return 1
  fi

  # Check if environment already exists
  if _env_exists "$name" && ! _is_local_name "$name"; then
    echo "❌ Error: Environment '$name' already exists at $(_env_path "$name")"
    echo "💡 Activate it with 'va $name', remove it with 'vr $name', or rename"
    return 1
  fi

  # Check for existing local .venv
  if _is_local_name "$name" && [[ -d ".venv" ]]; then
    echo "⚠️  Warning: .venv already exists in this directory"
    read "confirm?Overwrite? [y/N]: "
    if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
      echo "❌ Cancelled"
      return 0
    fi
    rm -rf .venv
  fi

  local venv_path="$(_env_path "$name")"
  local display_name="$name"
  _is_local_name "$name" && display_name=".venv (local)"

  echo "🐍 Creating virtual environment: $display_name"
  echo "   Location: $venv_path"
  echo "   Python: $version"
  echo "   Template: $template"
  echo ""

  # Create virtual environment with uv
  uv venv "$venv_path" --python "$version" || {
    echo "❌ Failed to create environment"
    echo "💡 Check that Python $version is available"
    return 1
  }

  # Create .envrc for direnv
  _create_envrc "$name"

  # Activate and install template
  source "$venv_path/bin/activate"
  _install_template "$template"

  echo ""
  echo "✅ Environment '$display_name' created!"
  _is_local_name "$name" || echo "💡 Use 'va $name' to activate in other directories"
  echo "💡 direnv will auto-activate when you cd here"
}

# Activate/switch environment
va() {
  local selected="$1"

  # Interactive selection if no argument. Deliberately BEFORE the local branch
  # below, so that choosing "local" in the picker does exactly what typing
  # `va local` does — session activation, no .envrc written. Ordered the other
  # way round, a picked "local" fell through to the .envrc handling instead.
  [[ -z "$selected" ]] && {
    selected=$(_select_env)
    [[ -z "$selected" ]] && return 0
  }

  # Handle local activation ("local" or ".", typed or picked)
  if _is_local_name "$selected"; then
    if [[ ! -d ".venv" ]]; then
      echo "❌ No local .venv found in current directory"
      echo "💡 Create one with: vc local"
      return 1
    fi
    source .venv/bin/activate
    echo "✅ Activated local .venv"
    return 0
  fi

  # Validate environment exists
  if ! _env_exists "$selected"; then
    echo "❌ Environment '$selected' not found"
    echo "💡 Available environments:"
    _list_environments
    return 1
  fi

  # Smart .envrc handling
  if [[ -f ".envrc" ]]; then
    local current_env=$(_get_envrc_env)
    echo "📄 Found existing .envrc"
    [[ -n "$current_env" ]] && echo "🔗 Currently points to: $current_env"
    echo "🎯 You want to use: $selected"

    [[ "$current_env" == "$selected" ]] && {
      echo "✅ Already configured correctly"
      _reload_direnv
      return 0
    }

    echo ""
    echo "1) Override .envrc (make $selected project default)"
    echo "2) Session only (manual activation)"
    echo "3) Cancel"
    read "choice?Choice [1-3]: "

    case "$choice" in
      1) echo "🔄 Updating .envrc..."; _create_envrc "$selected" ;;
      2) source "$(_env_path "$selected")/bin/activate"; echo "✅ Session activated: $selected" ;;
      *) echo "❌ Cancelled"; return 0 ;;
    esac
  else
    echo "📄 Creating .envrc for: $selected"
    _create_envrc "$selected"
  fi
}

# Project environment management
vp() {
  local current_env=$(_get_envrc_env)

  if [[ -n "$current_env" ]]; then
    echo "📋 Found .envrc pointing to: $current_env"
    if _env_exists "$current_env"; then
      _reload_direnv
    else
      echo "❌ Environment '$current_env' not found!"
      echo "💡 Use 'va' to select or 'vc' to create it"
    fi
    return 0
  fi

  # No .envrc yet - an existing local .venv wins over a centralized lookup
  if [[ -d ".venv" ]]; then
    echo "🎯 Found local .venv"
    _create_envrc "local"
    return 0
  fi

  local project_name="${PWD:t}"

  if _env_exists "$project_name"; then
    echo "🎯 Found environment: $project_name"
    _create_envrc "$project_name"
  else
    echo "❓ No environment for project: $project_name"
    echo "💡 Create with: vc $project_name [template] [version]"
  fi
}

# Deactivate environment. Early return, not `[[ ]] && { } || echo`: that form
# also runs the || branch whenever the last command in the block fails.
vd() {
  [[ -n "$VIRTUAL_ENV" ]] || { echo "ℹ️  No active environment"; return; }
  deactivate
  echo "✅ Environment deactivated"
}

# Forget project (remove .envrc)
vf() {
  [[ -f ".envrc" ]] || { echo "ℹ️  No .envrc found"; return; }
  rm ".envrc"
  echo "🗑️  Removed .envrc"
}

# Sync from requirements.txt
vs() {
  [[ -n "$VIRTUAL_ENV" ]] || { echo "❌ No active environment. Activate first."; return 1; }
  [[ -f "requirements.txt" ]] || { echo "❌ No requirements.txt found"; return 1; }

  # `uv pip sync`, not `install -r`: this makes the environment MATCH the file,
  # which is what "sync" means and what `install -r` never did. Anything not
  # listed is uninstalled, per-venv tools like ipykernel included.
  echo "📦 Syncing to requirements.txt (removes anything not listed)..."
  uv pip sync requirements.txt --python "$VIRTUAL_ENV/bin/python"
}

# Remove environment
vr() {
  local env_name="$1"

  [[ -z "$env_name" ]] && {
    echo "Usage: vr <environment_name>"
    echo ""
    echo "Available environments:"
    _list_environments
    return 1
  }

  if ! _env_exists "$env_name"; then
    echo "❌ Environment '$env_name' not found"
    return 1
  fi

  local venv_path="$(_env_path "$env_name")"
  local size=$(_dir_size "$venv_path")

  echo "🗑️  Remove: $env_name"
  echo "   Location: $venv_path"
  echo "   Size: $size"
  read "REPLY?⚠️  Cannot be undone! Continue? [y/N]: "

  [[ $REPLY =~ ^[Yy]$ ]] || {
    echo "❌ Cancelled"
    return 0
  }

  # Deactivate only if the active venv IS this one -- exact basename match,
  # not substring (removing "myapp" must not deactivate "myapp2").
  [[ -n "$VIRTUAL_ENV" && "${VIRTUAL_ENV:t}" == "${venv_path:t}" ]] && {
    deactivate
    echo "✅ Deactivated"
  }

  rm -rf "$venv_path"
  echo "✅ Environment '$env_name' removed"
}

# List environments (centralized only)
vl() {
  echo "🐍 Virtual Environments (uv managed)"
  echo "==================================="

  # Show active environment
  if [[ -n "$VIRTUAL_ENV" ]]; then
    local current="${VIRTUAL_ENV:t}"
    if [[ "$current" == ".venv" ]]; then
      current="local (.venv)"
    fi
    local managed=$([[ -f ".envrc" ]] && echo "direnv" || echo "manual")
    echo "🟢 Active: $current ($managed)"
  else
    echo "⚪ No environment active"
  fi

  # Show centralized environments
  echo ""
  echo "📁 Centralized environments ($CENTRAL_VENVS):"
  _list_environments

  # Show current directory info
  local current_env=$(_get_envrc_env)
  echo ""
  echo "📂 Current directory: ${PWD:t}"
  if [[ -n "$current_env" ]]; then
    if [[ "$current_env" == "local" ]]; then
      echo "   📄 .envrc → local (.venv)"
    else
      echo "   📄 .envrc → $current_env"
    fi
  else
    echo "   ❌ No .envrc (not direnv-managed)"
  fi

  # Show local .venv if exists
  if [[ -d ".venv" ]]; then
    echo "   🏠 Local .venv: $(_dir_size .venv) [Py $(_py_ver .venv/bin/python)]"
  fi
}

# =============================================================================
# UTILITIES
# =============================================================================

# Check health of .envrc files
check_envrc_health() {
  echo "🔍 Checking .envrc files..."
  local issues=0

  local envrc_file dir env_name target found
  while IFS= read -r -d '' envrc_file; do
    dir="${envrc_file:h}"
    env_name=$(_get_envrc_env "$envrc_file")
    found=""

    # A local env is checked against $dir, not the working directory, so this
    # cannot go through _env_exists (which resolves "local" to ./.venv).
    if [[ "$env_name" == "local" ]]; then
      target="local .venv"
      [[ -d "$dir/.venv" ]] && found=1
    elif [[ -n "$env_name" ]]; then
      target="$env_name"
      _env_exists "$env_name" && found=1
    else
      echo "⚠️  $dir/.envrc (unrecognized format)"
      ((issues++))
      continue
    fi

    if [[ -n "$found" ]]; then
      echo "✅ $dir/.envrc → $target"
    else
      echo "❌ $dir/.envrc → $target (missing)"
      ((issues++))
    fi
  done < <(find . -name ".envrc" -type f -print0 2>/dev/null)

  ((issues == 0)) && echo "✅ All .envrc files healthy" || echo "⚠️  Found $issues issue(s)"
}

# Show Python/uv/direnv info
show_python_info() {
  # Same dead-`||` trap as _dir_size, hence the captured value.
  local pip_ver=$(pip --version 2>/dev/null | cut -d' ' -f2)

  echo ""
  echo "🐍 Python Environment Info"
  echo "=========================="
  echo "System Python: $(python --version 2>/dev/null || echo "Not found")"
  echo "System Pip: ${pip_ver:-Not found}"
  echo "uv: $(uv --version 2>/dev/null || echo "Not found")"
  echo "Direnv: $(direnv version 2>/dev/null || echo "Not found")"

  if [[ -n "$VIRTUAL_ENV" ]]; then
    echo ""
    echo "Active Environment:"
    echo "   Name: ${VIRTUAL_ENV:t}"
    echo "   Python: $("$VIRTUAL_ENV/bin/python" --version)"
    # freeze format: the default table's two header lines were counted as packages.
    echo "   Packages: $(uv pip list --format freeze --python "$VIRTUAL_ENV/bin/python" 2>/dev/null | wc -l)"
    echo "   Location: $VIRTUAL_ENV"
  else
    echo ""
    echo "⚪ No active virtual environment"
  fi
  echo ""
}

# Help. A function, not an alias with a quoted heredoc, so paths, defaults and
# package lists come from the variables instead of being duplicated here.
vh() {
  cat <<EOF
🐍 Direnv + uv Virtual Environment Manager
==========================================

CREATE:
  vc [name] [template] [version]   - Any order; anything omitted is prompted
                                     for or defaulted. "local" or "." means
                                     ./.venv instead of a central env.
  e.g. vc | vc myproject | vc myproject ds 3.12 | vc ds | vc 3.14 | vc local ds

OTHER COMMANDS:
  va [name]    - Activate: writes an .envrc (bare va picks with fzf)
  va local     - Activate ./.venv for this session only
  vp           - Auto-setup project environment
  vd           - Deactivate
  vl           - List centralized environments
  vr <name>    - Delete environment (shows size, asks first)
  vs           - Sync to requirements.txt (removes anything unlisted)
  vf           - Remove .envrc
  check-envrc  - Health check .envrc files
  python-info  - Show Python/uv/direnv info

TEMPLATES (each also installs ${_VENV_LINT_PACKAGES[*]}):
$(for t in "${(ok)_VENV_TEMPLATE_PACKAGES[@]}"; do
    printf '  %-5s - %s\n' "$t" "${_VENV_TEMPLATE_PACKAGES[$t]}"
  done)
  none  - Empty (installs from requirements.txt if present)

PYTHON VERSIONS:
  Any major.minor[.patch], e.g. 3.9 - 3.14. Default: $_VENV_DEFAULT_PYTHON

LOCATIONS:
  Centralized: $CENTRAL_VENVS   Local: ./.venv
  direnv auto-activates whichever the project's .envrc names.
EOF
}

# =============================================================================
# ALIASES
# =============================================================================

alias check-envrc='check_envrc_health'
alias python-info='show_python_info'
