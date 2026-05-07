#!/usr/bin/env zsh
# ============================================================================
# Minimal ZSH Configuration - Orchestrator
# Arch Linux + foot + niri
# ============================================================================

# ============================================================================
# PERFORMANCE: Early Exit for Non-Interactive
# ============================================================================
[[ $- != *i* ]] && return

# ============================================================================
# ZSH OPTIONS
# ============================================================================

# History
HISTFILE=~/.zsh_history
HISTSIZE=50000
SAVEHIST=50000
setopt SHARE_HISTORY HIST_EXPIRE_DUPS_FIRST HIST_IGNORE_DUPS
setopt HIST_IGNORE_ALL_DUPS HIST_FIND_NO_DUPS HIST_IGNORE_SPACE
setopt HIST_SAVE_NO_DUPS HIST_REDUCE_BLANKS

# Directory Navigation
setopt AUTO_PUSHD PUSHD_IGNORE_DUPS PUSHD_SILENT

# Completion
setopt COMPLETE_IN_WORD ALWAYS_TO_END AUTO_MENU AUTO_LIST

# Globbing
setopt EXTENDED_GLOB NO_CASE_GLOB NUMERIC_GLOB_SORT

# Other
setopt CORRECT INTERACTIVE_COMMENTS NO_BEEP

# ============================================================================
# COMPLETION SYSTEM
# ============================================================================

# Custom completions directory
fpath=(~/.config/zsh/completions $fpath)
# -------------
autoload -Uz compinit

# Smart compinit - only dump once per day for speed
if [[ -n ~/.zcompdump(#qN.mh+24) ]]; then
  compinit -d ~/.zcompdump
else
  compinit -C -d ~/.zcompdump
fi


command -v dircolors >/dev/null && eval "$(dircolors -b)"

# Completion styling
zstyle ':completion:*' menu select
zstyle ':completion:*' group-name ''
zstyle ':completion:*' verbose yes
zstyle ':completion:*' special-dirs true
zstyle ':completion:*' squeeze-slashes true
zstyle ':completion:*:descriptions' format '%B%F{green}%d%f%b'
zstyle ':completion:*:messages' format '%F{yellow}%d%f'
zstyle ':completion:*:warnings' format '%F{red}No matches found%f'
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}


# ============================================================================
# KEY BINDINGS (VI MODE)
# ============================================================================
bindkey -v
export KEYTIMEOUT=1

# Cursor shape for different modes
function zle-keymap-select {
  case $KEYMAP in
    vicmd)      print -n '\e[1 q';;  # block
    viins|main) print -n '\e[6 q';;  # beam
  esac
}
zle -N zle-keymap-select

function zle-line-init {
  print -n '\e[6 q'  # beam on startup
}
zle -N zle-line-init

# Essential key bindings
bindkey '^?' backward-delete-char
bindkey '^h' backward-delete-char
bindkey '^w' backward-kill-word
bindkey '^r' history-incremental-search-backward
bindkey '^a' beginning-of-line
bindkey '^e' end-of-line

# ============================================================================
# PLUGINS
# ============================================================================

# 1. Autosuggestions
if [[ -f ~/.config/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh ]]; then
  source ~/.config/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
  ZSH_AUTOSUGGEST_STRATEGY=(history completion)
  ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=30
  ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=#5c6370,underline"
  bindkey '^ ' autosuggest-accept  # Ctrl+Space
fi

# 2. Fast Syntax Highlighting
if [[ -f ~/.config/zsh/plugins/fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh ]]; then
  source ~/.config/zsh/plugins/fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh
fi

# 3. History Substring Search
if [[ -f ~/.config/zsh/plugins/zsh-history-substring-search/zsh-history-substring-search.zsh ]]; then
  source ~/.config/zsh/plugins/zsh-history-substring-search/zsh-history-substring-search.zsh
  bindkey '^[[A' history-substring-search-up
  bindkey '^[[B' history-substring-search-down
  bindkey -M vicmd 'k' history-substring-search-up
  bindkey -M vicmd 'j' history-substring-search-down
fi

# 4. Forgit
export FORGIT_NO_ALIASES=1
if [[ -f ~/.config/zsh/plugins/forgit/forgit.plugin.zsh ]]; then
  source ~/.config/zsh/plugins/forgit/forgit.plugin.zsh
fi

# ============================================================================
# EXTERNAL TOOLS
# ============================================================================

# Starship prompt
command -v starship >/dev/null 2>&1 && eval "$(starship init zsh)"

# Zoxide (better cd)
command -v zoxide >/dev/null 2>&1 && eval "$(zoxide init zsh)"

# Direnv
command -v direnv >/dev/null 2>&1 && eval "$(direnv hook zsh)"

# FZF integration
command -v fzf >/dev/null 2>&1 && source <(fzf --zsh) 2>/dev/null

# FNM (Fast Node Manager) - auto-switch node versions on cd
command -v fnm >/dev/null 2>&1 && eval "$(fnm env --use-on-cd)"

# ============================================================================
# FOOT TERMINAL INTEGRATION (OSC 133 shell integration)
# ============================================================================
autoload -Uz add-zsh-hook

function foot_cmd_start() {
  printf '\e]133;C\e\\'                    # OSC 133 C: command output starts (foot outside tmux)
  echo "$1" > ~/.zsh_last_command          # persist command for foot Ctrl+Alt+C and tmux M-c binding
}

function foot_cmd_end() {
  local exit_code=$?
  printf '\e]133;D;%d\e\\' "$exit_code"   # OSC 133 D: command output ends (with exit code)
  printf '\e]133;A\e\\'                   # OSC 133 A: prompt starts rendering
}

# OSC 133 B: prompt fully drawn, awaiting user input (ZLE hook)
# add-zle-hook-widget appends to the hook list — doesn't replace existing widgets
autoload -Uz add-zle-hook-widget
function _foot_osc133b() { printf '\e]133;B\e\\'; }
add-zle-hook-widget -Uz zle-line-init _foot_osc133b

add-zsh-hook preexec foot_cmd_start
add-zsh-hook precmd foot_cmd_end

# ============================================================================
# LOAD MODULAR COMPONENTS
# ============================================================================
# Load core helpers first
[[ -f ~/.config/zsh/helpers.zsh ]] && source ~/.config/zsh/helpers.zsh
# Load aliases
[[ -f ~/.config/zsh/aliases ]] && source ~/.config/zsh/aliases

# Load function modules (if any exist)
for func in ~/.config/zsh/functions/*.zsh(N); do
  safe_source "$func" "$(basename "$func")"
done
