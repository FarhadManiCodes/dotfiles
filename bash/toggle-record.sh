#!/bin/bash
# Record what is playing (the default output) to ~/Audio/Recordings, or stop the
# recording this script started. `toggle-record.sh status` exits 0 while one runs.
pidfile=$XDG_RUNTIME_DIR/toggle-record.pid

# Our pw-record only: a bare pgrep/pkill would also match anyone else's.
recording() { pid=$(cat "$pidfile" 2>/dev/null) && [[ $(cat "/proc/$pid/comm" 2>/dev/null) == pw-record ]]; }

[[ ${1:-} == status ]] && { recording; exit; }

if recording; then
    kill "$pid"; rm -f "$pidfile"
    notify-send -t 3000 "Audio Recording" "Saved to ~/Audio/Recordings/"
    exit 0
fi

mkdir -p "$HOME/Audio/Recordings"
file=$HOME/Audio/Recordings/rec_$(date +%Y%m%d_%H%M%S).flac
# The output itself, captured as a sink: given "<sink>.monitor" (a PulseAudio
# name) pw-record fell back to the default microphone.
pw-record -P stream.capture.sink=true --target "$(pactl get-default-sink)" "$file" &
echo $! > "$pidfile"
sleep 0.3   # a pw-record that can't connect exits at once
if recording; then
    notify-send -t 3000 "Audio Recording" "Recording started..."
else
    rm -f "$pidfile"; notify-send -u critical "Audio Recording" "Could not start pw-record"
fi
