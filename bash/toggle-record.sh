#!/bin/bash
if pgrep -x pw-record > /dev/null; then
    pkill -x pw-record
    notify-send -t 3000 "Audio Recording" "Saved to ~/Audio/Recordings/"
else
    mkdir -p "$HOME/Audio/Recordings"
    FILE="$HOME/Audio/Recordings/rec_$(date +%Y%m%d_%H%M%S).flac"
    MONITOR="$(pactl get-default-sink).monitor"
    pw-record --target "$MONITOR" "$FILE" &
    notify-send -t 3000 "Audio Recording" "Recording started..."
fi
