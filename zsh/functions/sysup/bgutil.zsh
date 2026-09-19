# Matches the installed Python plugin version, never upstream HEAD — see
# docs/architecture/zsh.md, "yt-dlp's token helper". The optional directory is
# for isolated tests; the default matches yt-dlp/config's server_home. A
# subshell keeps our cwd and cleanup traps away from sysup's inhibitor trap.
_sysup_bgutil() (
  emulate -L zsh
  trap - EXIT INT TERM
  local helper_dir=${1:-"$HOME/.local/share/bgutil-pot"}
  local tool_dir plugin_version current_version changes stage built_version

  if [[ ! -e $helper_dir && ! -L $helper_dir ]]; then
    echo "    bgutil is not installed — skipping"
    return 0
  fi
  if [[ -L $helper_dir || ! -d $helper_dir/.git ]]; then
    echo "!! bgutil: expected a regular checkout at $helper_dir; leaving it unchanged"
    return 1
  fi
  tool_dir=$(uv tool dir) || return 1
  plugin_version=$("$tool_dir/yt-dlp/bin/python" -I -B -c \
    'from importlib.metadata import version; print(version("bgutil-ytdlp-pot-provider"))') || {
    echo "!! bgutil: cannot read the plugin version from uv's yt-dlp environment"
    return 1
  }
  if [[ ! $plugin_version =~ '^[0-9]+\.[0-9]+\.[0-9]+$' ]]; then
    echo "!! bgutil: unsupported release version: $plugin_version"
    return 1
  fi
  if ! command -v node >/dev/null || ! command -v timeout >/dev/null; then
    echo "!! bgutil: node and timeout are required to check the helper"
    return 1
  fi
  current_version=$(timeout 15s node "$helper_dir/server/build/generate_once.js" --version 2>/dev/null) || current_version=""
  if [[ $current_version == $plugin_version ]]; then
    echo "    bgutil $plugin_version already matches the Python plugin"
    return 0
  fi
  changes=$(git -C "$helper_dir" status --porcelain --untracked-files=all) || return 1
  if [[ -n $changes ]]; then
    echo "!! bgutil: local changes in $helper_dir; leaving them untouched"
    return 1
  fi
  if ! command -v npm >/dev/null; then
    echo "!! bgutil: npm is required to build release $plugin_version"
    return 1
  fi

  # Stage beside the live directory so the final renames stay on one filesystem.
  # Keep previous/ as a backup after success. On a failed/interrupted rename,
  # restore it if the live path is absent; never delete the only surviving copy.
  stage=$(mktemp -d "${helper_dir}.update.XXXXXX") || return 1
  trap '
    if [[ -d $stage/previous && ! -e $helper_dir && ! -L $helper_dir ]]; then
      mv -T -- "$stage/previous" "$helper_dir" ||
        echo "!! bgutil: restore failed; previous helper is at $stage/previous"
    fi
    if [[ ! -e $stage/previous ]]; then
      rm -rf -- "$stage"
    fi
  ' EXIT
  trap 'exit 130' INT
  trap 'exit 143' TERM

  echo "    Building bgutil ${current_version:-unavailable} -> $plugin_version"
  git clone --depth 1 --branch "$plugin_version" \
    https://github.com/Brainicism/bgutil-ytdlp-pot-provider.git "$stage/repo" || {
    echo "!! bgutil: release fetch failed; current helper preserved"
    return 1
  }
  # --ignore-scripts: skips install scripts neither declared dependency needs
  # (see docs/architecture/zsh.md for why). The token gate below is what keeps
  # that claim honest for future releases, where a skipped script may matter.
  (
    cd "$stage/repo/server" &&
      npm ci --ignore-scripts --no-audit --no-fund &&
      ./node_modules/.bin/tsc
  ) || {
    echo "!! bgutil: build failed; current helper preserved"
    return 1
  }
  built_version=$(timeout 15s node "$stage/repo/server/build/generate_once.js" --version) || {
    echo "!! bgutil: built helper cannot run; current helper preserved"
    return 1
  }
  if [[ $built_version != $plugin_version ]]; then
    echo "!! bgutil: built version $built_version does not match $plugin_version"
    return 1
  fi

  # --version alone is not evidence of a working build (docs/architecture/zsh.md
  # has the incident); only a generated token is. Unreachable youtube.com is
  # NOT CHECKED, never a build failure, so a dropped connection can't strand
  # sysup on the version mismatch this step exists to fix.
  if timeout 120s node "$stage/repo/server/build/generate_once.js" >/dev/null 2>&1; then
    echo "    verified: the new helper generated a token"
  elif timeout 10s curl -sf -o /dev/null --max-time 8 \
      https://www.youtube.com/generate_204 2>/dev/null; then
    echo "!! bgutil: the new helper cannot generate a token; current helper preserved"
    return 1
  else
    echo "    !! token generation NOT CHECKED — could not reach youtube.com"
    echo "       installing on the version check alone; verify when back online:"
    echo "       node $helper_dir/server/build/generate_once.js"
  fi

  # Do not discard edits made while the release was building.
  changes=$(git -C "$helper_dir" status --porcelain --untracked-files=all) || return 1
  if [[ -n $changes || -L $helper_dir ]]; then
    echo "!! bgutil: checkout changed during the build; leaving it untouched"
    return 1
  fi
  mv -T -- "$helper_dir" "$stage/previous" &&
    mv -T -- "$stage/repo" "$helper_dir" || {
    echo "!! bgutil: installation failed; restoring the previous helper"
    return 1
  }
  echo "    Installed bgutil $plugin_version; previous helper: $stage/previous"
)
