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

case ${1:-} in
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

if toggle-record.sh status; then rec="🔴  Stop Recording"; else rec="⏺  Start Recording"; fi
choice=$(printf '%s\n' "▶/⏸  Play/Pause" "⏭  Next" "⏮  Prev" "🎯  Focus Player" "⏹  Stop…" "$rec" | fuzzel --dmenu --prompt "Media > " --lines 6)
case $choice in
    "▶/⏸  Play/Pause") pc play-pause ;;
    "⏭  Next") pc next ;;
    "⏮  Prev") pc previous ;;
    "🎯  Focus Player") focus_player ;;
    "⏹  Stop…") stop_player ;;
    "$rec") toggle-record.sh ;;
esac
