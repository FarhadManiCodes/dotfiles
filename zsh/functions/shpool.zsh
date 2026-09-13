# Run a command in a detachable shpool session. Each call gets a fresh session
# named "<first-word>-HHMMSS-<unique-id>". The readable prefix is sanitized
# because shpool session names cannot contain spaces, slashes or shell syntax;
# the suffix prevents a second invocation from accidentally reattaching to the
# first and silently dropping its command.
#
# Uses --cmd "zsh -i -c ..." rather than --start-cmd. shpool's --start-cmd goes
# through its own sentinel-injection mechanism (typing the command into the pty
# as fake keystrokes, before the client-facing output stream is even wired up)
# -- verified broken here: the session runs correctly server-side but nothing
# ever renders client-side (confirmed with `keep lazygit` vs `lg`'s --cmd
# lazygit: identical program, only --start-cmd is blank). `-i` makes the inner
# zsh interactive so it still sources .zshrc and functions like `sysup`
# resolve, while going through the same --cmd path lg already relies on.
# The command is written to a private mktemp script and sourced, rather than
# embedded inline in the --cmd string. A single argument is treated as zsh
# source (for `keep 'echo a; echo b'`); multiple arguments are shell-escaped
# individually so ordinary argv boundaries survive (for `keep cmd 'a b'`).
# The EXIT trap removes the script even if the command itself calls `exit`.
# Usage: keep sysup / keep sudo pacman -Syu / keep 'echo a; echo b'
#
# Everything below is a no-op without shpool -- guard the whole file once
# rather than repeat the command -v check in every function.
if command -v shpool >/dev/null 2>&1; then
    keep() {
        if (( $# == 0 )); then
            print -u2 -- "Usage: keep <command> [args...]"
            return 2
        fi

        local label="${1%% *}"
        label="${label:t}"
        label="${label//[^A-Za-z0-9_-]/_}"
        [[ -n "$label" ]] || label="task"
        label="${label[1,32]}"

        local runtime_dir="${XDG_RUNTIME_DIR:-/tmp}"
        local script script_id name
        script=$(mktemp "${runtime_dir}/keep.XXXXXXXX.zsh") || return 1
        script_id="${${script:t}#keep.}"
        script_id="${script_id%.zsh}"
        name="${label}-$(date +%H%M%S)-${script_id}"

        {
            print -r -- "trap 'rm -f -- ${(q)script}' EXIT"
            if (( $# == 1 )); then
                print -r -- "$1"
            else
                print -r -- "${(q)@}"
            fi
        } > "$script"

        print -r -- "Starting '${(j: :)@}' in shpool session '$name'..."
        shpool attach --cmd "zsh -i -c 'source ${(q)script}'" "$name"
        local exit_status=$?
        (( exit_status == 0 )) || rm -f -- "$script"
        return "$exit_status"
    }

    # lazygit in a per-repo shpool session. The readable basename is combined
    # with a hash of the full path, so two repositories with the same basename
    # cannot silently share a session. --dir sets the session's cwd since
    # --cmd (no shell) never inherits the caller's.
    if command -v lazygit >/dev/null 2>&1; then
        lg() {
            local dir label path_hash name
            dir=$(git rev-parse --show-toplevel 2>/dev/null) || dir="$PWD"
            label="${dir:t}"
            label="${label//[^A-Za-z0-9_-]/_}"
            [[ -n "$label" ]] || label="repo"
            label="${label[1,32]}"
            path_hash=$(print -rn -- "$dir" | sha256sum)
            path_hash="${path_hash%% *}"
            name="lazygit-${label}-${path_hash[1,10]}"
            shpool attach --dir "$dir" --cmd lazygit "$name"
        }
    fi

    # Fuzzy-find a running shpool session: Enter attaches, Ctrl-D kills it
    # (staying in the picker, list refreshed) without attaching.
    attach() {
        local session
        session=$(shpool list --json 2>/dev/null | jq -r '.sessions[].name' | fzf \
            --prompt="Session (enter: attach, ctrl-d: kill) > " \
            --bind "ctrl-d:execute-silent(shpool kill {})+reload(shpool list --json 2>/dev/null | jq -r '.sessions[].name')")
        [[ -n "$session" ]] && shpool attach "$session"
    }
fi
