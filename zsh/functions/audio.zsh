playaudio() {
    local queue=$(mktemp "$XDG_RUNTIME_DIR/playaudio.XXXXXX")

    find ~/Audio -type f -iregex ".*\.\(mp3\|m4a\|wav\|ogg\|flac\|opus\)$" \
        | fzf \
            --preview "cat $queue 2>/dev/null || echo '(queue empty)'" \
            --preview-window="right:40%:border-left" \
            --bind "tab:execute-silent(echo {} >> $queue)+down" \
            --header "TAB: queue  ENTER: play (headless)" \
        > /dev/null

    # mpv is the last reader, so the queue outlives this function, not the fzf call.
    if [[ -s "$queue" ]]; then
        ( mpv --no-video --playlist="$queue" > /dev/null 2>&1; rm -f "$queue" ) &
    else
        rm -f "$queue"
    fi
}
