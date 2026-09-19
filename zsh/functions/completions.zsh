# =============================================================================
# Completion overrides for third-party tools
# Location: ~/.config/zsh/functions/completions.zsh
# =============================================================================
# compdef only exists once compinit has run (.zshrc does that before sourcing
# these functions), and this file is also sourced by non-interactive shells.
(( $+functions[compdef] )) || return 0

# -----------------------------------------------------------------------------
# handlr (the `o` alias is `handlr open`)
# -----------------------------------------------------------------------------
# /usr/share/zsh/site-functions/_handlr asks the binary for candidates and hands
# the whole list — paths and flags together — to a single _describe. zsh groups
# described matches ahead of bare ones, so `o <TAB>` offers --quiet before it
# offers a file. Split the list instead: paths go through _files, so they come
# first and directories descend as usual, and the flags follow.
_handlr() {
  local -a candidates flags
  candidates=("${(@f)$(
    _CLAP_IFS=$'\n' _CLAP_COMPLETE_INDEX=$(( CURRENT - 1 )) COMPLETE=zsh \
      handlr -- "${(@)words}" 2>/dev/null
  )}")
  candidates=(${candidates:#})

  # clap escapes a colon inside a value, so an unescaped one marks a described
  # candidate: a flag or a subcommand. Everything else is a path.
  flags=(${(M)candidates:#*[^\\]:*})

  (( $#flags < $#candidates )) && _files
  (( $#flags )) && _describe -t values values flags
}
compdef _handlr handlr
