playaudio() {
    local queue=/tmp/fzf_audio_queue.txt
    > "$queue"

    find ~/Audio -type f -iregex ".*\.\(mp3\|m4a\|wav\|ogg\|flac\|opus\)$" \
        | fzf \
            --preview "cat $queue 2>/dev/null || echo '(queue empty)'" \
            --preview-window="right:40%:border-left" \
            --bind "tab:execute-silent(echo {} >> $queue)+down" \
            --header "TAB: queue  ENTER: play (headless)" \
        > /dev/null

    [[ -s "$queue" ]] && mpv --no-video --playlist="$queue" > /dev/null 2>&1 &
}
