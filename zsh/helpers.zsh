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

  [[ ! -f "$file" ]] && return 1
  [[ ! -r "$file" ]] && return 1

  # Only fork zsh -n when the file is newer than the last successful check
  if [[ ! -f "$cache_file" || "$file" -nt "$cache_file" ]]; then
    if ! zsh -n "$file" 2>/dev/null; then
      echo "⚠️  Syntax error in $description" >&2
      return 1
    fi
    mkdir -p "$cache_dir"
    touch "$cache_file"
  fi

  if source "$file" 2>/dev/null; then
    return 0
  else
    echo "❌ Failed to load: $description" >&2
    return 1
  fi
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

    # --- 2. Smart Sensor Scan ---
    local cpu_temp="N/A"
    local gpu_temp="N/A"
    local nvme_temp="N/A"

    # Iterate over all hwmon directories to find the right ones by name
    for hwmon in /sys/class/hwmon/hwmon*; do
        [ -e "$hwmon/name" ] || continue
        local name=$(cat "$hwmon/name")

        # Find CPU (k10temp) - Tctl is usually temp1
        if [[ "$name" == "k10temp" ]]; then
            if [ -f "$hwmon/temp1_input" ]; then
                cpu_temp=$(($(cat "$hwmon/temp1_input") / 1000))"°C"
            fi
        fi

        # Find GPU (amdgpu) - edge is usually temp1
        if [[ "$name" == "amdgpu" ]]; then
            if [ -f "$hwmon/temp1_input" ]; then
                gpu_temp=$(($(cat "$hwmon/temp1_input") / 1000))"°C"
            fi
        fi

        # Find NVMe - Composite is usually temp1
        if [[ "$name" == "nvme" ]]; then
            if [ -f "$hwmon/temp1_input" ]; then
                nvme_temp=$(($(cat "$hwmon/temp1_input") / 1000))"°C"
            fi
        fi
    done

    # --- 3. Visuals & Colors ---
    local color=""
    local icon=""
    local time_str=""

    if [[ "$bat_status" == "Discharging" ]]; then
        color="\e[31m" # Red
        icon="▼"
        local energy_now=$(cat /sys/class/power_supply/BAT0/energy_now)
        local time_min=$(awk -v e=$energy_now -v p=$power_mw 'BEGIN {printf "%d", (e/p)*60}')
        local hours=$((time_min / 60))
        local mins=$((time_min % 60))
        time_str="${hours}h ${mins}m remaining"
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
    if [[ "$bat_status" == "Discharging" ]]; then
        echo -e "-----------------"
        echo -e "Time:     ${time_str}"
    fi
}
# Show comprehensive loading status
loading_status() {
  echo ""
  echo "📊 ZSH Configuration Status"
  echo "============================"

  # Core Tools
  echo ""
  echo "🔧 Core Tools:"
  command -v starship >/dev/null 2>&1 && echo "  ✅ starship" || echo "  ❌ starship"
  command -v zoxide >/dev/null 2>&1 && echo "  ✅ zoxide" || echo "  ❌ zoxide"
  command -v direnv >/dev/null 2>&1 && echo "  ✅ direnv" || echo "  ❌ direnv"
  command -v eza >/dev/null 2>&1 && echo "  ✅ eza" || echo "  ❌ eza"
  command -v fzf >/dev/null 2>&1 && echo "  ✅ fzf" || echo "  ❌ fzf"
  command -v bat >/dev/null 2>&1 && echo "  ✅ bat" || echo "  ❌ bat"
  command -v fd >/dev/null 2>&1 && echo "  ✅ fd" || echo "  ❌ fd"
  command -v rg >/dev/null 2>&1 && echo "  ✅ ripgrep" || echo "  ❌ ripgrep"

  # C++ Toolchain
  echo ""
  echo "⚙️  C++ Toolchain:"
  command -v cmake >/dev/null 2>&1 && echo "  ✅ cmake" || echo "  ❌ cmake"
  command -v ninja >/dev/null 2>&1 && echo "  ✅ ninja" || echo "  ❌ ninja"
  command -v ccache >/dev/null 2>&1 && echo "  ✅ ccache" || echo "  ❌ ccache"
  command -v clangd >/dev/null 2>&1 && echo "  ✅ clangd" || echo "  ❌ clangd"
  command -v clang-format >/dev/null 2>&1 && echo "  ✅ clang-format" || echo "  ❌ clang-format"
  command -v gdb >/dev/null 2>&1 && echo "  ✅ gdb" || echo "  ❌ gdb"
  command -v valgrind >/dev/null 2>&1 && echo "  ✅ valgrind" || echo "  ❌ valgrind"
  command -v hyperfine >/dev/null 2>&1 && echo "  ✅ hyperfine" || echo "  ❌ hyperfine"

  # Development Tools
  echo ""
  echo "🛠️  Development:"
  command -v uv >/dev/null 2>&1 && echo "  ✅ uv (Python)" || echo "  ❌ uv"
  command -v poetry >/dev/null 2>&1 && echo "  ✅ poetry" || echo "  ❌ poetry"
  command -v docker >/dev/null 2>&1 && echo "  ✅ docker" || echo "  ❌ docker"
  command -v kubectl >/dev/null 2>&1 && echo "  ✅ kubectl" || echo "  ❌ kubectl"
  command -v gh >/dev/null 2>&1 && echo "  ✅ gh (GitHub CLI)" || echo "  ❌ gh"
  command -v lazygit >/dev/null 2>&1 && echo "  ✅ lazygit" || echo "  ❌ lazygit"
  command -v fnm >/dev/null 2>&1 && echo "  ✅ fnm (Node)" || echo "  ❌ fnm"

  # Plugins
  echo ""
  echo "🔌 Plugins:"
  [[ -n "${ZSH_AUTOSUGGEST_STRATEGY}" ]] && echo "  ✅ zsh-autosuggestions" || echo "  ❌ zsh-autosuggestions"
  [[ -n "${FAST_HIGHLIGHT_VERSION}" || -n "${FAST_HIGHLIGHT}" ]] && echo "  ✅ fast-syntax-highlighting" || echo "  ❌ fast-syntax-highlighting"
  [[ $(whence -w history-substring-search-up) == *"function"* ]] && echo "  ✅ zsh-history-substring-search" || echo "  ❌ zsh-history-substring-search"

  # Loaded Files
  echo ""
  echo "📁 Loaded Configuration:"
  [[ -f ~/.config/zsh/aliases ]] && echo "  ✅ aliases" || echo "  ❌ aliases"
  [[ -f ~/.config/zsh/helpers.zsh ]] && echo "  ✅ helpers" || echo "  ❌ helpers"

  # Function modules
  local func_count=$(ls ~/.config/zsh/functions/*.zsh 2>/dev/null | wc -l)
  if [[ $func_count -gt 0 ]]; then
    echo "  ✅ function modules: $func_count loaded"
    for func_file in ~/.config/zsh/functions/*.zsh(N); do
      echo "     • $(basename "$func_file")"
    done
  else
    echo "  📦 function modules: 0 (none created yet)"
  fi

  # Environment
  echo ""
  echo "🌍 Current Environment:"
  echo "  📂 PWD: $(basename "$PWD")"

  # Python environment (if any)
  if [[ -n "$VIRTUAL_ENV" ]]; then
    echo "  🐍 Active venv: $(basename "$VIRTUAL_ENV")"
  fi

  # Direnv
  if [[ -n "$DIRENV_DIR" ]]; then
    echo "  📁 Direnv active: $(basename "$DIRENV_DIR")"
  fi

  # Git repository
  if git rev-parse --git-dir >/dev/null 2>&1; then
    local repo=$(basename "$(git rev-parse --show-toplevel)" 2>/dev/null)
    local branch=$(git branch --show-current 2>/dev/null)
    echo "  🔀 Git repo: $repo ($branch)"
  fi

  # Stats
  echo ""
  echo "📊 Statistics:"
  echo "  Aliases: $(print -l ${(ok)aliases} | wc -l)"
  echo "  Functions: $(print -l ${(ok)functions} | wc -l)"
  local completion_count=$(ls ~/.config/zsh/completions/ 2>/dev/null | wc -l)
  echo "  Completions: $completion_count"

  # Shell info
  echo ""
  echo "🐚 Shell Info:"
  echo "  ZSH version: $ZSH_VERSION"
  echo "  Terminal: $TERM"
  echo "  Locale: $LANG"

  echo ""
}

# Quick reload with feedback
reload() {
  echo "🔄 Reloading ZSH configuration..."
  source ~/.zshrc
  echo "✅ Configuration reloaded"
  echo "💡 Run 'status' to verify everything loaded correctly"
}

# Safety environment loader
safety_load() {
  if [[ -f "$HOME/.safety/.safety_profile" ]]; then
    source "$HOME/.safety/.safety_profile"
    echo "✅ Safety environment loaded"
  else
    echo "⚠️  Safety profile not found at ~/.safety/.safety_profile"
  fi
}

# ============================================================================
# ALIASES FOR HELPERS
# ============================================================================

alias status='loading_status'

# ============================================================================
# END
# ============================================================================
