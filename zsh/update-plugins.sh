#!/usr/bin/env zsh
# Install or update the zsh plugins .zshrc expects.
#
# This is the ONLY record of which plugins the shell needs -- the clones
# themselves are untracked, and .zshrc sources each behind `[[ -f ... ]]`, so a
# missing one degrades the shell silently rather than erroring. Before this list
# existed the script only pulled directories that were already there, so a fresh
# install produced no plugins at all while install.sh reported success.
#
# Keep in sync with the `source` lines in zsh/.zshrc.

PLUGIN_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/zsh/plugins"

plugins=(
  "https://github.com/zsh-users/zsh-autosuggestions"
  "https://github.com/zdharma-continuum/fast-syntax-highlighting"
  "https://github.com/zsh-users/zsh-history-substring-search"
)

mkdir -p "$PLUGIN_DIR"
failed=0

for url in "${plugins[@]}"; do
  name="${url:t}"
  dir="$PLUGIN_DIR/$name"
  if [[ -d "$dir/.git" ]]; then
    echo "Updating $name..."
    git -C "$dir" pull --ff-only --quiet || { echo "  ⚠ update failed: $name"; failed=1 }
  else
    echo "Installing $name..."
    git clone --depth 1 --quiet "$url" "$dir" || { echo "  ⚠ clone failed: $name"; failed=1 }
  fi
done

# Anything present but no longer listed is left alone deliberately -- removing a
# plugin someone cloned by hand is not this script's call.
for dir in "$PLUGIN_DIR"/*(/N); do
  name="${dir:t}"
  (( ${plugins[(I)*/$name]} )) || echo "  note: $name is installed but not in this list"
done

exit $failed
