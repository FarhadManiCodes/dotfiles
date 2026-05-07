bat() {
  local state="${XDG_STATE_HOME:-$HOME/.local/state}/foot_theme_state"
  if [[ -f "$state" && "$(< "$state")" == "light" ]]; then
    BAT_THEME="GitHub" command bat "$@"
  else
    BAT_THEME="OneHalfDark" command bat "$@"
  fi
}
