#!/bin/bash

# Returns the Playing player name; falls back to first Paused one.
get_active_player() {
    local p
    while IFS= read -r p; do
        [[ "$(playerctl -p "$p" status 2>/dev/null)" == "Playing" ]] && printf '%s' "$p" && return
    done < <(playerctl -l 2>/dev/null)
    while IFS= read -r p; do
        [[ "$(playerctl -p "$p" status 2>/dev/null)" == "Paused" ]] && printf '%s' "$p" && return
    done < <(playerctl -l 2>/dev/null)
}

# Run a playerctl command targeting the active player; falls back to bare playerctl.
playerctl_cmd() {
    local player
    player=$(get_active_player)
    if [[ -n "$player" ]]; then
        playerctl -p "$player" "$@"
    else
        playerctl "$@"
    fi
}

focus_active_player() {
    local player win_id track_title

    player=$(get_active_player)
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

if [[ "$1" == "focus" ]]; then
    focus_active_player
    exit 0
fi

if [[ "$1" == "call" ]]; then
    mic_is_muted() { wpctl get-volume @DEFAULT_AUDIO_SOURCE@ 2>/dev/null | grep -q MUTED; }
    if playerctl_cmd status 2>/dev/null | grep -q "Playing"; then
        playerctl_cmd pause
        mic_is_muted && wob-control mic-mute
    else
        playerctl_cmd play
        mic_is_muted || wob-control mic-mute
    fi
    exit 0
fi

if pgrep -x pw-record > /dev/null; then
    RECORD_LABEL="🔴  Stop Recording"
else
    RECORD_LABEL="⏺  Start Recording"
fi

OPTIONS="▶/⏸  Play/Pause\n⏭  Next\n⏮  Prev\n🎯  Focus Player\n${RECORD_LABEL}"

CHOICE=$(printf "$OPTIONS" | fuzzel --dmenu --prompt "Media > " --lines 5)

case "$CHOICE" in
    "▶/⏸  Play/Pause")                         playerctl_cmd play-pause ;;
    "⏭  Next")                                  playerctl_cmd next ;;
    "⏮  Prev")                                  playerctl_cmd previous ;;
    "🎯  Focus Player")                          focus_active_player ;;
    "🔴  Stop Recording"|"⏺  Start Recording")  "$HOME/.local/bin/toggle-record.sh" ;;
esac
