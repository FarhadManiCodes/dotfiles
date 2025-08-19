#!/bin/zsh

# =============================================================================
# CONFIGURATION
# =============================================================================

export LLAMACPP_MODELS_DIR="${LLAMACPP_MODELS_DIR:-$HOME/.local/share/models}"

# Simple preset variables
LLAMACPP_DEV_THREADS="6"
LLAMACPP_DEV_OPENBLAS="4"
LLAMACPP_DEV_CONTEXT="2048"
LLAMACPP_DEV_BATCH="256"

LLAMACPP_BALANCED_THREADS="8"
LLAMACPP_BALANCED_OPENBLAS="6"
LLAMACPP_BALANCED_CONTEXT="4096"
LLAMACPP_BALANCED_BATCH="512"

LLAMACPP_PERFORMANCE_THREADS="16"
LLAMACPP_PERFORMANCE_OPENBLAS="8"
LLAMACPP_PERFORMANCE_CONTEXT="4096"
LLAMACPP_PERFORMANCE_BATCH="512"

LLAMACPP_INTERACTIVE_THREADS="8"
LLAMACPP_INTERACTIVE_OPENBLAS="6"
LLAMACPP_INTERACTIVE_CONTEXT="4096"
LLAMACPP_INTERACTIVE_BATCH="256"

LLAMACPP_PRESET="${LLAMACPP_PRESET:-balanced}"

typeset -a MODEL_SIZES=(1b 3b 7b 13b 30b)

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

_llama_info() { print -P "%F{blue}[INFO]%f $*" }
_llama_success() { print -P "%F{green}[SUCCESS]%f $*" }
_llama_warning() { print -P "%F{yellow}[WARNING]%f $*" }
_llama_error() { print -P "%F{red}[ERROR]%f $*" }

# Find llama.cpp binary
_find_llamacpp() {
    if (( $+commands[llama-cli] )); then
        print "llama-cli"
    elif [[ -x "$HOME/.local/bin/llama-cli" ]]; then
        print "$HOME/.local/bin/llama-cli"
    elif [[ -x "$HOME/install/llamacpp/llama.cpp/build/bin/llama-cli" ]]; then
        print "$HOME/install/llamacpp/llama.cpp/build/bin/llama-cli"
    else
        return 1
    fi
}

# Get preset values
_get_preset_value() {
    local param="$1"
    
    case "$LLAMACPP_PRESET" in
        "dev")
            case "$param" in
                "threads") print "$LLAMACPP_DEV_THREADS" ;;
                "openblas") print "$LLAMACPP_DEV_OPENBLAS" ;;
                "context") print "$LLAMACPP_DEV_CONTEXT" ;;
                "batch") print "$LLAMACPP_DEV_BATCH" ;;
                *) return 1 ;;
            esac ;;
        "balanced")
            case "$param" in
                "threads") print "$LLAMACPP_BALANCED_THREADS" ;;
                "openblas") print "$LLAMACPP_BALANCED_OPENBLAS" ;;
                "context") print "$LLAMACPP_BALANCED_CONTEXT" ;;
                "batch") print "$LLAMACPP_BALANCED_BATCH" ;;
                *) return 1 ;;
            esac ;;
        "performance")
            case "$param" in
                "threads") print "$LLAMACPP_PERFORMANCE_THREADS" ;;
                "openblas") print "$LLAMACPP_PERFORMANCE_OPENBLAS" ;;
                "context") print "$LLAMACPP_PERFORMANCE_CONTEXT" ;;
                "batch") print "$LLAMACPP_PERFORMANCE_BATCH" ;;
                *) return 1 ;;
            esac ;;
        "interactive")
            case "$param" in
                "threads") print "$LLAMACPP_INTERACTIVE_THREADS" ;;
                "openblas") print "$LLAMACPP_INTERACTIVE_OPENBLAS" ;;
                "context") print "$LLAMACPP_INTERACTIVE_CONTEXT" ;;
                "batch") print "$LLAMACPP_INTERACTIVE_BATCH" ;;
                *) return 1 ;;
            esac ;;
        *) return 1 ;;
    esac
}

# Find model file
_find_model_file() {
    local search_term="$1"
    
    [[ -f "$search_term" ]] && { print "$search_term"; return 0 }
    [[ -f "$LLAMACPP_MODELS_DIR/$search_term" ]] && { print "$LLAMACPP_MODELS_DIR/$search_term"; return 0 }
    
    local -a candidates=("$LLAMACPP_MODELS_DIR"/**/*${search_term}*.gguf(N))
    [[ ${#candidates} -gt 0 ]] && { print "$candidates[1]"; return 0 }
    
    candidates=("$LLAMACPP_MODELS_DIR"/**/${search_term}.gguf(N))
    [[ ${#candidates} -gt 0 ]] && { print "$candidates[1]"; return 0 }
    
    return 1
}

# =============================================================================
# CORE FUNCTIONS
# =============================================================================

llama_init() {
    _llama_info "Initializing llama.cpp models directory..."
    mkdir -p "$LLAMACPP_MODELS_DIR"/{${(j:,:)MODEL_SIZES}}
    
    cat > "$LLAMACPP_MODELS_DIR/README.md" << 'EOF'
# llama.cpp Models Directory

Place your GGUF models in the appropriate size directory:
- `1b/`  - Small models (1-2B parameters)
- `3b/`  - Medium models (3-4B parameters) 
- `7b/`  - Large models (7-10B parameters)
- `13b/` - Extra large models (13-15B parameters)
- `30b/` - Huge models (30B+ parameters)

Usage: llama_run model_name
EOF
    
    _llama_success "Directory structure created at $LLAMACPP_MODELS_DIR"
}

llama_models() {
    print "=== llama.cpp Models ==="
    print "Location: $LLAMACPP_MODELS_DIR"
    print "Current preset: $LLAMACPP_PRESET"
    print
    
    if [[ ! -d "$LLAMACPP_MODELS_DIR" ]]; then
        _llama_warning "Models directory doesn't exist. Run 'llama_init' first."
        return 1
    fi
    
    local total_models=0
    
    for size in $MODEL_SIZES; do
        local size_dir="$LLAMACPP_MODELS_DIR/$size"
        if [[ -d "$size_dir" ]]; then
            local -a models=("$size_dir"/*.gguf(N))
            if [[ ${#models} -gt 0 && -f "${models[1]}" ]]; then
                print "${(U)size} Models (${#models}):"
                for model in $models; do
                    local model_name="${model:t}"
                    local model_size=$(du -h "$model" 2>/dev/null | cut -f1 || print "?")
                    print "  $model_name ($model_size)"
                    ((total_models++))
                done
                print
            fi
        fi
    done
    
    # Check root directory
    local -a root_models=("$LLAMACPP_MODELS_DIR"/*.gguf(N))
    if [[ ${#root_models} -gt 0 && -f "${root_models[1]}" ]]; then
        print "Root Directory Models (${#root_models}):"
        for model in $root_models; do
            local model_name="${model:t}"
            local model_size=$(du -h "$model" 2>/dev/null | cut -f1 || print "?")
            print "  $model_name ($model_size)"
            ((total_models++))
        done
        print
    fi
    
    if (( total_models == 0 )); then
        print "No models found."
        print "Download models to: $LLAMACPP_MODELS_DIR/"
    else
        print "Total models: $total_models"
    fi
    
    print
    print "Usage: llama_run <model> | llama_chat <model> | llama_preset <preset>"
}

llama_run() {
    local model_name="$1"
    shift
    
    local llamacpp_binary=$(_find_llamacpp)
    if [[ -z "$llamacpp_binary" ]]; then
        _llama_error "llama-cli not found. Please install llama.cpp."
        return 1
    fi
    
    if [[ -z "$model_name" ]]; then
        print "Usage: llama_run <model_name> [options]"
        llama_models
        return 1
    fi
    
    local model_file=$(_find_model_file "$model_name")
    if [[ -z "$model_file" ]]; then
        _llama_error "Model not found: $model_name"
        llama_models
        return 1
    fi
    
    local threads=$(_get_preset_value "threads")
    local context=$(_get_preset_value "context")
    local batch=$(_get_preset_value "batch")
    local openblas_threads=$(_get_preset_value "openblas")
    
    if [[ -z "$threads" || -z "$context" || -z "$batch" || -z "$openblas_threads" ]]; then
        _llama_error "Invalid preset: $LLAMACPP_PRESET"
        return 1
    fi
    
    export OPENBLAS_NUM_THREADS="$openblas_threads"
    
    print "Running: ${model_file:t}"
    print "Preset: $LLAMACPP_PRESET (${threads}t/${context}ctx/${openblas_threads}omp/${batch}batch)"
    print "=================================="
    
    "$llamacpp_binary" -m "$model_file" -t "$threads" -c "$context" -b "$batch" "$@"
}

llama_chat() {
    local model_name="$1"
    shift
    
    if [[ -z "$model_name" ]]; then
        print "Usage: llama_chat <model_name>"
        llama_models
        return 1
    fi
    
    local old_preset="$LLAMACPP_PRESET"
    LLAMACPP_PRESET="interactive"
    
    print "Starting interactive chat with $model_name"
    print "=============================================================="
    
    llama_run "$model_name" -i --color --multiline-input "$@"
    LLAMACPP_PRESET="$old_preset"
}

llama_preset() {
    local new_preset="$1"
    local -a valid_presets=(dev balanced performance interactive)
    
    if [[ -z "$new_preset" ]]; then
        print "Current preset: $LLAMACPP_PRESET"
        print "\nAvailable presets:"
        print "  dev         - Conservative (6t/4omp/2048ctx)"
        print "  balanced    - Default (8t/6omp/4096ctx)"
        print "  performance - Maximum (16t/8omp/4096ctx)"
        print "  interactive - Chat optimized (8t/6omp/4096ctx)"
        return 0
    fi
    
    if [[ ${valid_presets[(i)$new_preset]} -le ${#valid_presets} ]]; then
        LLAMACPP_PRESET="$new_preset"
        _llama_success "Preset changed to: $LLAMACPP_PRESET"
        
        local threads=$(_get_preset_value "threads")
        local openblas=$(_get_preset_value "openblas")
        local context=$(_get_preset_value "context")
        local batch=$(_get_preset_value "batch")
        
        print "Config: ${threads}t/${openblas}omp/${context}ctx/${batch}batch"
    else
        _llama_error "Invalid preset: $new_preset"
        llama_preset
        return 1
    fi
}

llama_check() {
    print "=== llama.cpp Integration Check ==="
    
    local binary=$(_find_llamacpp)
    if [[ -n "$binary" ]] && "$binary" --help &>/dev/null; then
        _llama_success "llama.cpp: $binary"
    else
        _llama_error "llama.cpp not found or not working"
    fi
    
    if [[ -d "$LLAMACPP_MODELS_DIR" ]]; then
        local count=$(print -l "$LLAMACPP_MODELS_DIR"/**/*.gguf(N) | wc -l)
        _llama_success "Models directory: $LLAMACPP_MODELS_DIR ($count models)"
    else
        _llama_warning "Models directory missing. Run 'llama_init'"
    fi
    
    print "Current preset: $LLAMACPP_PRESET"
    local threads=$(_get_preset_value "threads")
    local context=$(_get_preset_value "context") 
    local batch=$(_get_preset_value "batch")
    local openblas=$(_get_preset_value "openblas")
    
    if [[ -n "$threads" && -n "$context" && -n "$batch" && -n "$openblas" ]]; then
        _llama_success "Preset config: ${threads}t/${context}ctx/${openblas}omp/${batch}batch"
    else
        _llama_error "Invalid preset configuration"
    fi
    
    print "\nCommands: llama_init | llama_models | llama_run | llama_chat | llama_preset"
}

# =============================================================================
# WORKING ZSH COMPLETION
# =============================================================================

# Enable completion system
autoload -U compinit
compinit

# Get model names for completion
_get_model_names() {
    if [[ -d "$LLAMACPP_MODELS_DIR" ]]; then
        find "$LLAMACPP_MODELS_DIR" -name "*.gguf" -exec basename {} .gguf \; 2>/dev/null
    fi
}

# Completion for our functions
_llama_models_completion() {
    local models=(${(f)"$(_get_model_names)"})
    _describe 'models' models
}

_llama_presets_completion() {
    local presets=(dev balanced performance interactive)
    _describe 'presets' presets
}

# Simple llama-cli completion that actually works
_llama_cli_completion() {
    local context state line
    local -a options
    
    # Basic options that work
    options=(
        '-m:model file'
        '--model:model file'
        '-t:threads'
        '--threads:threads'
        '-c:context size'
        '--ctx-size:context size'
        '-b:batch size'
        '--batch-size:batch size'
        '-p:prompt'
        '--prompt:prompt'
        '-f:input file'
        '--file:input file'
        '-i:interactive mode'
        '--interactive:interactive mode'
        '--color:colored output'
        '--help:show help'
        '--version:show version'
        '-n:number of tokens'
        '--predict:number of tokens'
        '--temp:temperature'
        '--top-k:top-k sampling'
        '--top-p:top-p sampling'
        '--repeat-penalty:repeat penalty'
        '-s:seed'
        '--seed:seed'
        '--grammar-file:grammar file'
        '--chat-template:chat template'
        '-cnv:conversation mode'
        '--conversation:conversation mode'
        '--no-cnv:no conversation mode'
        '--no-conversation:no conversation mode'
        '--multiline-input:multiline input'
        '--reverse-prompt:reverse prompt'
        '--system-prompt:system prompt'
    )
    
    # Handle completion based on previous word
    case "$words[CURRENT-1]" in
        -m|--model)
            _files -g "*.gguf"
            return
            ;;
        --grammar-file)
            _files -g "*.gbnf"
            return
            ;;
        --file|-f)
            _files
            return
            ;;
        -t|--threads|-c|--ctx-size|-b|--batch-size|-n|--predict|-s|--seed)
            # Numeric arguments - just return without completion
            return
            ;;
        --temp|--top-k|--top-p|--repeat-penalty)
            # Numeric arguments - just return without completion
            return
            ;;
        *)
            # Show available options
            local opts
            for opt in $options; do
                opts+=(${opt%%:*})
            done
            compadd -a opts
            ;;
    esac
}

# Even simpler approach - just handle key cases
_llama_simple_completion() {
    case "$words[CURRENT-1]" in
        -m|--model)
            _files -g "*.gguf"
            ;;
        --grammar-file)
            _files -g "*.gbnf"
            ;;
        -f|--file)
            _files
            ;;
        *)
            local -a opts
            opts=(-m --model -t --threads -c --ctx-size -b --batch-size -p --prompt -f --file -i --interactive --color --help --version -n --predict --temp --top-k --top-p --repeat-penalty -s --seed --grammar-file --chat-template -cnv --conversation --no-cnv --multiline-input --system-prompt)
            compadd -a opts
            ;;
    esac
}

# Register completions
compdef _llama_models_completion llama_run
compdef _llama_models_completion llama_chat
compdef _llama_models_completion llama
compdef _llama_presets_completion llama_preset

# Official llama.cpp tools - use the simple completion
compdef _llama_simple_completion llama-cli
compdef _llama_simple_completion llama-server
compdef _llama_simple_completion llama-simple
compdef _llama_simple_completion llama-perplexity
compdef _llama_simple_completion llama-embedding

# For tools that mainly take model files
compdef '_files -g "*.gguf"' llama-bench
compdef '_files -g "*.gguf"' llama-quantize

# =============================================================================
# ALIASES
# =============================================================================

alias llama="llama_run"
alias llama-models="llama_models"
alias llama-chat="llama_chat"
alias llama-preset="llama_preset"
