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

# Bottom pane: detect state and point at the bindings (current pane = bottom).
# Configuration/build go through tmux-cpp-tools (Prefix C / b / B) — no inline cmake.
CMD="
if [ -f CMakeLists.txt ]; then
    if [ -f build/CMakeCache.txt ]; then
        echo '✅ Configured — Prefix b to build · Prefix B for build/test/run · Prefix F to profile'
    else
        echo '🔧 CMake project — Prefix C to configure (Debug/Release/ASan), then Prefix b to build'
    fi
else
    echo '⚠️  No CMakeLists.txt — Prefix C → New Project to scaffold'
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

# Bottom pane: profiling hints pointing at the Prefix F / B menus (current focus = bottom)
tmux send-keys "echo '🚀 Profile & Benchmark — Prefix F'" C-m
tmux send-keys "echo '--------------------------------'" C-m
tmux send-keys "echo '⏱️  b benchmarks   h hyperfine compare'" C-m
tmux send-keys "echo '🔥 s perf stat    r perf record/report   f samply'" C-m
tmux send-keys "echo '🧠 Memory check:  Prefix B → v (valgrind)'" C-m
tmux send-keys "echo '--------------------------------'" C-m

# Move to top pane and open btop
tmux select-pane -U
tmux send-keys "btop-code" C-m

# ==============================================================================
# FINALIZE: focus back on code window, top (editor) pane
# ==============================================================================
tmux select-window -t "code"
tmux select-pane -U
