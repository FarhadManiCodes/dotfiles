# Run a command in a detachable shpool session; each call gets a fresh session
# named "<first-word>-HHMM" (readable in the Mod+A fuzzel picker, unlike a raw
# epoch timestamp). Only the first word of $1 is used for the name -- if $1 is
# a whole quoted "a; b; c" string (one argument, not several), the raw string
# would contain spaces/semicolons, which shpool rejects as an invalid session
# name. Two calls for the same command in the same minute reattach to the same
# session rather than colliding -- acceptable, rare in practice.
#
# Uses --cmd "zsh -i -c ..." rather than --start-cmd. shpool's --start-cmd goes
# through its own sentinel-injection mechanism (typing the command into the pty
# as fake keystrokes, before the client-facing output stream is even wired up)
# -- verified broken here: the session runs correctly server-side but nothing
# ever renders client-side (confirmed with `keep lazygit` vs `lg`'s --cmd
# lazygit: identical program, only --start-cmd is blank). `-i` makes the inner
# zsh interactive so it still sources .zshrc and functions like `sysup`
# resolve, while going through the same --cmd path lg already relies on.
# The command is written to a small temp script and sourced, rather than
# embedded inline in the --cmd string, so arbitrary content (quotes, etc.)
# never has to survive being re-escaped into a nested shell string.
# Usage: keep sysup / keep sudo pacman -Syu / keep 'echo a; echo b'
#
# Everything below is a no-op without shpool -- guard the whole file once
# rather than repeat the command -v check in every function.
if command -v shpool >/dev/null 2>&1; then
    keep() {
        local first_word="${1%% *}"
        local name="${first_word}-$(date +%H%M)"
        local script="${XDG_RUNTIME_DIR:-/tmp}/keep-${name}.zsh"
        print -r -- "$*" > "$script"
        echo "Starting '$*' in shpool session '$name'..."
        # exit must come after rm, in the outer -c string, not inside the
        # sourced script itself -- exit inside the sourced file would
        # terminate before ever reaching rm, leaking the temp script.
        shpool attach --cmd "zsh -i -c 'source ${script}; rm -f ${script}; exit'" "$name"
    }

    # lazygit in a per-repo shpool session, named after the repo's toplevel
    # dir (not a single fixed name): running `lg` again from the same repo
    # reattaches to where you left off; a different repo gets its own
    # session instead of silently reattaching to a stale one running in the
    # wrong directory. --dir sets the session's cwd since --cmd (no shell)
    # never inherits the caller's.
    if command -v lazygit >/dev/null 2>&1; then
        lg() {
            local dir name
            dir=$(git rev-parse --show-toplevel 2>/dev/null) || dir="$PWD"
            name="lazygit-$(basename "$dir")"
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
