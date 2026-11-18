# ============================================================================
# ZSH HELPERS - Core Utility Functions
# ============================================================================

# ============================================================================
# SAFE SOURCING
# ============================================================================

# Safe source function - syntax-checks modules, but only when they change.
# Cache stored in XDG_CACHE_HOME so foot server terminal opens pay zero fork cost.
safe_source() {
  local file="$1"
  local description="${2:-file}"
  local cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/syntax"
  local cache_file="$cache_dir/${file//\//_}"

  [[ -f "$file" && -r "$file" ]] || return 1

  # Only fork zsh -n when the file is newer than the last successful check
  if [[ ! -f "$cache_file" || "$file" -nt "$cache_file" ]]; then
    if ! zsh -n "$file" 2>/dev/null; then
      echo "⚠️  Syntax error in $description" >&2
      return 1
    fi
    mkdir -p "$cache_dir"
    touch "$cache_file"
  fi

  (($+functions[_zcompile_stale])) && _zcompile_stale "$file"
  if source "$file" 2>/dev/null; then
    return 0
  else
    echo "❌ Failed to load: $description" >&2
    return 1
  fi
}

# ============================================================================
# FZF RESULT HELPER
# ============================================================================

# _fzf_pick <key-var> <sel-var> --expect=<keys> [fzf options...]
# Run fzf and put the pressed key (first line, empty for Enter) and the selected
# item (last line) in the caller-named variables; it needs --expect, which makes
# fzf print that key line. Fails when nothing was selected, from fzf's own exit
# status (1: no match, 130: Esc): with no match fzf prints an --expect key alone,
# which would otherwise be read as the selection.
# Callers may pipe into it: zsh runs a pipeline's last command in the current
# shell, so the variables still reach the caller.
_fzf_pick() {
  local _r
  _r=$(fzf "${@:3}") || return 1
  typeset -g "$1=${_r%%$'\n'*}" "$2=${_r##*$'\n'}"
}

# ============================================================================
# STATUS & DEBUGGING
# ============================================================================
# --- Power Monitor Alias (CPU + GPU + NVMe) ---
batt() {
  # Check if battery exists
  if [ ! -d /sys/class/power_supply/BAT0 ]; then
    echo "No battery detected."
    return
  fi

  # --- 1. Get Battery Data ---
  local bat_status=$(cat /sys/class/power_supply/BAT0/status)
  local capacity=$(cat /sys/class/power_supply/BAT0/capacity)
  local power_mw=$(cat /sys/class/power_supply/BAT0/power_now)
  local watts=$(awk -v p=$power_mw 'BEGIN {printf "%.1f", p/1000000}')

  # --- 2. One JSON sensor snapshot ---
  local readings sensor_warning=""
  local cpu_temp gpu_temp nvme_temp fan1 fan2
  if ! readings=$(hardware-readings); then
    sensor_warning="Sensor readings unavailable"
  fi
  IFS=$'\t' read -r cpu_temp gpu_temp nvme_temp fan1 fan2 <<<"${readings:-$'N/A\tN/A\tN/A\tN/A\tN/A'}"

  # --- 3. Visuals & Colors ---
  local color=""
  local icon=""
  local time_str=""

  if [[ "$bat_status" == "Discharging" ]]; then
    color="\e[31m" # Red
    icon="▼"
    # power_now can read 0 while discharging (charge-threshold transitions
    # on this ThinkPad). awk treats division by zero as fatal, so guard it.
    if ((power_mw > 0)); then
      local energy_now=$(cat /sys/class/power_supply/BAT0/energy_now)
      local time_min=$(awk -v e=$energy_now -v p=$power_mw 'BEGIN {printf "%d", (e/p)*60}')
      time_str="$((time_min / 60))h $((time_min % 60))m remaining"
    else
      time_str="calculating..."
    fi
  else
    color="\e[32m" # Green
    icon="▲"
    time_str="Charging / AC"
  fi
  local reset="\e[0m"

  # --- 4. Print Dashboard ---
  echo -e "Status:   ${color}${bat_status}${reset} ${icon}"
  echo -e "Level:    ${capacity}%"
  echo -e "Draw:     ${color}${watts} W${reset}"
  echo -e "-----------------"
  echo -e "CPU:      ${cpu_temp}"
  echo -e "GPU:      ${gpu_temp}"
  echo -e "NVMe:     ${nvme_temp}"
  echo -e "Fan 1:    ${fan1}"
  echo -e "Fan 2:    ${fan2}"
  [[ -n "$sensor_warning" ]] && echo "$sensor_warning"
  if [[ "$bat_status" == "Discharging" ]]; then
    echo -e "-----------------"
    echo -e "Time:     ${time_str}"
  fi
}

# Quick reload — exec a fresh shell rather than re-sourcing .zshrc.
# Re-sourcing would source the syntax-highlighting / autosuggestions plugins a
# second time, double-wrapping their ZLE widgets. exec zsh guarantees a clean
# load (direnv re-activates the project env automatically).
reload() {
  echo "🔄 Reloading ZSH configuration..."
  exec zsh
}

# ============================================================================
# END
# ============================================================================
