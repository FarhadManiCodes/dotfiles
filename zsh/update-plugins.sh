#!/usr/bin/env zsh
PLUGIN_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/zsh/plugins"
for plugin in "$PLUGIN_DIR"/*/; do
  echo "Updating $(basename "$plugin")..."
  git -C "$plugin" pull --ff-only || echo "  ⚠ Failed: $(basename "$plugin")"
done
