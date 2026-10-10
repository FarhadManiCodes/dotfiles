#!/bin/bash
# Media controls (niri Mod+M): play/pause, next, previous, focus the player's
# window, stop (quit) a chosen player, start/stop a recording.
# `media-menu.sh call` (the headset's play key) pauses and unmutes the mic, or
# plays and mutes it.

# The Playing player, else a Paused one: one playerctl call for all players.
active_player() {
    playerctl -a status -f '{{status}}	{{playerInstance}}' 2>/dev/null | awk -F'\t' '
        $1 == "Playing" { print $2; found = 1; exit }
        $1 == "Paused" && paused == "" { paused = $2 }
        END { if (!found && paused != "") print paused }'
}

# playerctl on the active player, or playerctl's own choice if there is none.
pc() {
    local player args=()
    player=$(active_player)
    [[ -n $player ]] && args=(-p "$player")
    playerctl "${args[@]}" "$@"
}

# A percentage of track duration, using the same player as the seek action.
show_progress() {
    local player=${1:-} position length percent pipe=$XDG_RUNTIME_DIR/wob-playback.pipe
    if [[ -z $player ]]; then
        player=$(active_player)
        [[ -n $player ]] || player=$(playerctl -f '{{playerInstance}}' metadata 2>/dev/null)
    fi
    [[ -n $player ]] || { notify-send -t 2000 "Media" "No player available"; return 1; }
    position=$(playerctl -p "$player" position 2>/dev/null)
    length=$(playerctl -p "$player" metadata mpris:length 2>/dev/null)
    if [[ ! $position =~ ^[0-9]+([.][0-9]+)?$ || ! $length =~ ^[0-9]+$ || $length =~ ^0+$ ]]; then
        notify-send -t 2000 "Media" "Playback position or duration unavailable"
        return 1
    fi
    percent=$(awk -v p="$position" -v l="$length" 'BEGIN {
        n = p * 1000000 / l * 100; if (n > 100) n = 100;
        printf "%.0f", n
    }')
    [[ -p $pipe ]] || { notify-send -t 2000 "Media" "Playback bar unavailable"; return 1; }
    # Bound the write if wob's reader is unavailable; never create a regular file.
    printf '%s\n' "$percent" | timeout 1s tee "$pipe" >/dev/null
}

seek_track() {
    local player
    player=$(active_player)
    [[ -n $player ]] || player=$(playerctl -f '{{playerInstance}}' metadata 2>/dev/null)
    [[ -n $player ]] || return 1
    playerctl -p "$player" position "$1" || return
    show_progress "$player"
}

toggle_playback() {
    local player
    player=$(active_player)
    [[ -n $player ]] || player=$(playerctl -f '{{playerInstance}}' metadata 2>/dev/null)
    [[ -n $player ]] || return 1
    playerctl -p "$player" play-pause || return
    show_progress "$player"
}

# Restart after three seconds; near the start, go back if the player can.
# Resolve once so the position and action always refer to the same player.
previous_track() {
    local player position can_previous args=()
    player=$(active_player)
    [[ -n $player ]] || player=$(playerctl -f '{{playerInstance}}' metadata 2>/dev/null)
    [[ -n $player ]] && args=(-p "$player")
    position=$(playerctl "${args[@]}" position 2>/dev/null)
    if [[ $position =~ ^[0-9]+([.][0-9]+)?$ ]] &&
        awk -v p="$position" 'BEGIN { exit !(p > 3) }'; then
        playerctl "${args[@]}" position 0
        return
    fi
    if [[ -n $player ]]; then
        can_previous=$(busctl --user get-property "org.mpris.MediaPlayer2.$player" \
            /org/mpris/MediaPlayer2 org.mpris.MediaPlayer2.Player CanGoPrevious 2>/dev/null)
    fi
    if [[ $can_previous == 'b false' ]]; then
        playerctl "${args[@]}" position 0
    else
        playerctl "${args[@]}" previous
    fi
}

focus_player() {
    local player app title id
    player=$(active_player)
    [[ -n $player ]] || player=$(playerctl -f '{{playerInstance}}' metadata 2>/dev/null)
    [[ -n $player ]] || return
    case $player in
        spotify_player*) app=spotify-player ;;
        firefox*)        app=firefox ;;
        mpv*)            app=mpv ;;
        *) notify-send -t 2000 "Media" "No focusable window for $player"; return ;;
    esac
    # The window whose title has the track in it (a Firefox tab), else the first.
    title=$(playerctl -p "$player" metadata xesam:title 2>/dev/null)
    id=$(niri msg -j windows | jq -r --arg a "$app" --arg t "$title" '
        [.[] | select(.app_id == $a)]
        | (map(select($t != "" and ((.title // "") | contains($t)))) + .)[0].id // empty')
    if [[ -n $id ]]; then
        niri msg action focus-window --id "$id"
    else
        notify-send -t 2000 "Media" "No window found for $player"
    fi
}

# Quits the player chosen from a list of the running ones, each named by what
# it plays: the active-player guess can pick a paused one left behind. Never
# Firefox, whose tabs are more than the media in them.
stop_player() {
    local lines choice player
    lines=$(playerctl -a metadata -f '{{playerInstance}}	{{status}} · {{trunc(default(title, "untitled"), 60)}}' 2>/dev/null |
        awk -F'\t' '$1 !~ /^firefox/ && $1 != "" { print $1 " · " $2 }')
    if [[ -z $lines ]]; then
        notify-send -t 2000 "Media" "No player to stop"
        return
    fi
    choice=$(printf '%s\n' "$lines" | fuzzel --dmenu --prompt "Stop > " --lines 5) || return 0 # Esc
    player=${choice%% · *}
    [[ -n $player && $player != firefox* ]] || return 0
    # Quit, not stop: an idle mpv still holds its memory. playerctl has no
    # quit, so MPRIS's own; a player that can't quit at least stops.
    busctl --user call "org.mpris.MediaPlayer2.$player" /org/mpris/MediaPlayer2 \
        org.mpris.MediaPlayer2 Quit 2>/dev/null || playerctl -p "$player" stop
}

# Keep the existing runtime names so an already-running recording can be stopped.
pidfile=$XDG_RUNTIME_DIR/toggle-record.pid

# Our pw-record only: a bare pgrep/pkill would also match anyone else's.
recording() { pid=$(cat "$pidfile" 2>/dev/null) && [[ $(cat "/proc/$pid/comm" 2>/dev/null) == pw-record ]]; }

# A subshell contains exits and releases the lock when the toggle finishes.
# Reading status for the menu never acquires this lock.
toggle_recording() (
    exec 9>"$XDG_RUNTIME_DIR/toggle-record.lock" || exit 1
    flock -n 9 || exit 0

    if recording; then
        kill "$pid"; rm -f "$pidfile"
        notify-send -t 3000 "Audio Recording" "Saved to ~/Audio/Recordings/"
        exit 0
    fi

    mkdir -p "$HOME/Audio/Recordings"
    file=$HOME/Audio/Recordings/rec_$(date +%Y%m%d_%H%M%S).flac
    # Capture the sink itself: <sink>.monitor made pw-record use the microphone.
    # The background recorder must not retain the toggle's lock.
    pw-record -P stream.capture.sink=true --target "$(pactl get-default-sink)" "$file" 9>&- &
    echo $! > "$pidfile"
    sleep 0.3   # a pw-record that can't connect exits at once
    if recording; then
        notify-send -t 3000 "Audio Recording" "Recording started..."
    else
        rm -f "$pidfile"; notify-send -u critical "Audio Recording" "Could not start pw-record"
    fi
)

case ${1:-} in
    progress) show_progress; exit $? ;;
    play-pause) toggle_playback; exit $? ;;
    seek-backward) seek_track 15-; exit $? ;;
    seek-forward) seek_track 15+; exit $? ;;
    focus) focus_player; exit 0 ;;
    call)
        mic_muted() { wpctl get-volume @DEFAULT_AUDIO_SOURCE@ 2>/dev/null | grep -q MUTED; }
        if [[ $(pc status 2>/dev/null) == Playing ]]; then
            pc pause; mic_muted && wob-control mic-mute
        else
            pc play; mic_muted || wob-control mic-mute
        fi
        exit 0 ;;
esac

if recording; then rec="🔴  Stop Recording"; else rec="⏺  Start Recording"; fi
choice=$(printf '%s\n' "▶/⏸  Play/Pause" "⏭  Next" "⏮  Prev" "▰  Playback Position" "🎯  Focus Player" "⏹  Stop…" "$rec" | fuzzel --dmenu --prompt "Media > " --lines 7)
case $choice in
    "▶/⏸  Play/Pause") toggle_playback ;;
    "⏭  Next") pc next ;;
    "⏮  Prev") previous_track ;;
    "▰  Playback Position") show_progress ;;
    "🎯  Focus Player") focus_player ;;
    "⏹  Stop…") stop_player ;;
    "$rec") toggle_recording ;;
esac
