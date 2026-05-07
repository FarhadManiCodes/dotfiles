# man page with better theme
export MANPAGER="sh -c 'col -bx | bat -l man -p --theme=\$BAT_THEME'"
export MANROFFOPT="-c"

# Keep commands completely separate - don't override existing help
# Check what help does first:
# help                  # Shows shell built-in help (bash/zsh)
# tldr                  # Quick examples for commands

# Optional: convenient tldr aliases (choose what you prefer)
alias examples='tldr'           # examples docker
alias quick='tldr'              # quick docker  
alias cheat='tldr'              # cheat docker

alias man-plain='MANPAGER= man' # fallback to plain man if needed

# Convenient man section shortcuts
alias man-config='man 5'       # Configuration files
alias man-admin='man 8'        # System administration  
alias man-dev='man 3'          # Library functions
alias man-syscall='man 2'      # System calls
alias man-cmd='man 1'          # Commands (default)

# Quick man page testing
alias man-test='man-info'

# Function to test your man page coloring
man-info() {
    echo "🔧 Man Page Configuration:"
    echo "  MANPAGER: ${MANPAGER}"
    echo "  MANROFFOPT: ${MANROFFOPT}" 
    echo "  BAT_THEME: ${BAT_THEME:-default}"
    echo ""
    echo "📖 Available commands:"
    echo "  man <cmd>          # Full documentation (colorized)"
    echo "  tldr <cmd>         # Quick practical examples"
    echo "  help <builtin>     # Shell built-in help (cd, if, for, etc.)"
    echo "  examples <cmd>     # Same as tldr (alias)"
    echo "  man-config <file>  # Section 5 (config files)"
    echo "  man-admin <cmd>    # Section 8 (admin commands)"
    echo ""
    echo "🧪 Test examples:"
    echo "  man docker         # Complete docker documentation"
    echo "  tldr docker        # Quick docker examples"
    echo "  examples kubectl   # Quick kubectl examples"  
    echo "  help cd            # Built-in 'cd' command help"
    echo "  man 5 foot.ini     # foot.ini config file format"
}

# Optional: If bat isn't working, fallback to less with colors
if ! command -v bat >/dev/null 2>&1; then
    echo "⚠️  bat not found, using less with colors"
    export MANPAGER="less -R"
    export LESS_TERMCAP_mb=$'\e[1;32m'     # begin bold
    export LESS_TERMCAP_md=$'\e[1;32m'     # begin blink
    export LESS_TERMCAP_me=$'\e[0m'        # reset bold/blink
    export LESS_TERMCAP_se=$'\e[0m'        # reset reverse video
    export LESS_TERMCAP_so=$'\e[01;33m'    # begin reverse video
    export LESS_TERMCAP_ue=$'\e[0m'        # reset underline
    export LESS_TERMCAP_us=$'\e[1;4;31m'   # begin underline
fi
