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

# tmux cannot ask the terminal which theme is active (inside tmux, foot's OSC 11
# reply is answered by tmux itself), so it is driven from the state file like
# vim and ptpython. No-op when no tmux server is running.
"$(dirname "$(readlink -f "$0")")/tmux-theme" "$(< "$STATE_FILE")" 2>/dev/null || true
