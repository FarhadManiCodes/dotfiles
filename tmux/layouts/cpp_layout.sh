#!/bin/bash
# Optimized C++ Study Layout for tmux

PROJECT_DIR="$(pwd)"

# ==============================================================================
# WINDOW 1: CODE + BUILD
# ==============================================================================
tmux rename-window "code"

# Split: after split-window -v, focus lands on the NEW bottom pane
tmux split-window -v -c "$PROJECT_DIR"

# Resize bottom (current focus) to 30%, top gets 70%
tmux resize-pane -y 30%

# Bottom pane: cmake auto-detect (current pane = bottom)
CMD="
if [ -f CMakeLists.txt ]; then
    if [ -f build/CMakeCache.txt ]; then
        echo '✅ Already configured. Run: cmake --build build -j\$(lscpu -p=Core,Socket | grep -v \"#\" | sort -u | wc -l)'
    else
        echo '🔧 CMake project detected.'
        mkdir -p build
        echo '⚙️  Configuring...'
        cmake -DCMAKE_BUILD_TYPE=Debug -DCMAKE_EXPORT_COMPILE_COMMANDS=ON -DCMAKE_CXX_COMPILER_LAUNCHER=ccache -DCMAKE_C_COMPILER_LAUNCHER=ccache -B build
        ln -sf build/compile_commands.json compile_commands.json
        echo '✅ Ready. Run: cmake --build build -j\$(lscpu -p=Core,Socket | grep -v \"#\" | sort -u | wc -l)'
    fi
else
    echo '⚠️  No CMakeLists.txt found.'
    echo '💡 Tip: Use Prefix C → New Project to scaffold.'
fi
"
tmux send-keys "$CMD" C-m

# Move to top pane and open nvim
tmux select-pane -U
tmux send-keys "nvim -c 'Oil'" C-m

# ==============================================================================
# WINDOW 2: GIT (Conditional)
# ==============================================================================
if [ -d "$PROJECT_DIR/.git" ]; then
    tmux new-window -n "git" -c "$PROJECT_DIR"
    tmux send-keys "lazygit" C-m
fi

# ==============================================================================
# WINDOW 3: PROFILING
# ==============================================================================
tmux new-window -n "profile" -c "$PROJECT_DIR"

# Split: focus lands on bottom pane
tmux split-window -v -c "$PROJECT_DIR"

# Bottom pane: benchmarking hints (current focus = bottom)
tmux send-keys "echo '🚀 Profiling Ready'" C-m
tmux send-keys "echo '--------------------------------'" C-m
tmux send-keys "echo '⏱️  Benchmark: hyperfine \"./build/<executable>\"'" C-m
tmux send-keys "echo '🔥 Hotspots:  perf record -g ./build/<executable> && perf report'" C-m
tmux send-keys "echo '🧠 Memory:    valgrind ./build/<executable>'" C-m
tmux send-keys "echo '--------------------------------'" C-m

# Move to top pane and open btop
tmux select-pane -U
tmux send-keys "btop-code" C-m

# ==============================================================================
# FINALIZE: focus back on code window, top (editor) pane
# ==============================================================================
tmux select-window -t "code"
tmux select-pane -U
