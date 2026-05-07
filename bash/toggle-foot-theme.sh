#!/bin/bash
STATE_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/foot_theme_state"
mkdir -p "$(dirname "$STATE_FILE")"

# No state file means we assume dark (initial state), so toggle to light
if [ ! -f "$STATE_FILE" ] || [ "$(< "$STATE_FILE")" = "dark" ]; then
    killall -SIGUSR2 foot footclient 2>/dev/null
    echo "light" > "$STATE_FILE"
else
    killall -SIGUSR1 foot footclient 2>/dev/null
    echo "dark" > "$STATE_FILE"
fi
