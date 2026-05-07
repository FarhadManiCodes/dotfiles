# Copy a file to the Wayland clipboard so it can be pasted as a file object
# (e.g. directly into a browser upload dialog)
copyfile() {
    [[ -z "$1" ]] && { echo "Usage: copyfile <file>" >&2; return 1; }
    [[ ! -f "$1" ]] && { echo "Not a file: $1" >&2; return 1; }
    wl-copy -t text/uri-list "file://$(realpath "$1")"
    echo "Copied $1 as a file object!"
}
