#!/bin/bash

focus_active_player() {
    local player app_id win_id p track_title

    while IFS= read -r p; do
        [[ "$(playerctl -p "$p" status 2>/dev/null)" == "Playing" ]] && player="$p" && break
    done < <(playerctl -l 2>/dev/null)
    [[ -z "$player" ]] && player=$(playerctl -f '{{playerName}}' metadata 2>/dev/null)
    [[ -z "$player" ]] && return

    case "$player" in
        spotify_player)
            win_id=$(niri msg windows | grep -B2 'App ID: "spotify-player"' | grep "^Window ID" | head -1 | awk '{print $3}' | tr -d ':')
            ;;
        firefox*)
            track_title=$(playerctl -p "$player" metadata xesam:title 2>/dev/null)
            if [[ -n "$track_title" ]]; then
                win_id=$(niri msg windows | awk -v t="$track_title" '
                    /^Window ID/ { wid = $3; gsub(/:$/, "", wid) }
                    /Title:/ && index($0, t) { print wid; exit }
                ')
            fi
            [[ -z "$win_id" ]] && win_id=$(niri msg windows | grep -B2 'App ID: "firefox"' | grep "^Window ID" | head -1 | awk '{print $3}' | tr -d ':')
            ;;
        mpv*)
            win_id=$(niri msg windows | grep -B2 'App ID: "mpv"' | grep "^Window ID" | head -1 | awk '{print $3}' | tr -d ':')
            ;;
        *)
            notify-send -t 2000 "Media" "No focusable window for $player"
            return
            ;;
    esac

    if [[ -n "$win_id" ]]; then
        niri msg action focus-window --id "$win_id"
    else
        notify-send -t 2000 "Media" "No window found for $player"
    fi
}

if pgrep -x pw-record > /dev/null; then
    RECORD_LABEL="🔴  Stop Recording"
else
    RECORD_LABEL="⏺  Start Recording"
fi

OPTIONS="▶/⏸  Play/Pause\n⏭  Next\n⏮  Prev\n🎯  Focus Player\n${RECORD_LABEL}"

CHOICE=$(printf "$OPTIONS" | fuzzel --dmenu --prompt "Media > " --lines 5)

case "$CHOICE" in
    "▶/⏸  Play/Pause")                         playerctl play-pause ;;
    "⏭  Next")                                  playerctl next ;;
    "⏮  Prev")                                  playerctl previous ;;
    "🎯  Focus Player")                          focus_active_player ;;
    "🔴  Stop Recording"|"⏺  Start Recording")  "$HOME/.local/bin/toggle-record.sh" ;;
esac
