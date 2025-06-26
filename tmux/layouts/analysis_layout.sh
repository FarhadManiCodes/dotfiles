#!/bin/bash
# Modified tmux layout with 1-indexed windows/panes

SESSION_NAME="analysis-$(basename "$PWD")"
cd "$PWD"

# Start new session with window 1
tmux new-session -d -s "$SESSION_NAME" -c "$PWD"

# ================ Window 1: Interactive Analysis ========================================
tmux rename-window "interactive"
tmux split-window -h -p 45 -c "$PWD" # Right sidebar 40%

# Main pane (pane 1):
tmux select-pane -t 0
tmux send-keys "# Starting Jupyter Lab for interactive analysis" Enter
tmux send-keys "zsh '$HOME/.local/bin/tmux-jupyter-auto'" Enter
# Top-right (pane 2): Quick Python analysis
tmux select-pane -t 1
tmux send-keys "# Quick data profiling and stats" Enter
tmux send-keys "ptipython" Enter
tmux send-keys "import pandas as pd, numpy as np" Enter
tmux send-keys "from pathlib import Path" Enter
tmux send-keys "import json  # For JSON data exploration" Enter
tmux send-keys "print('📊 Data analysis ready')" Enter
# tmux send-keys "import ydata_profiling as pp  # for data profiling" Enter
# tmux send-keys "plt.style.use('seaborn-v0_8')" Enter

# ======================= Window 2: Data Preview & Discovery =======================================================
tmux new-window -n "preview" -c "$PWD"

# Split into left (60%) and right (40%)
tmux split-window -h -p 40 -c "$PWD"

# Split the right side vertically for DuckDB (top) and Python (bottom)
tmux select-pane -t 1
tmux split-window -v -p 50 -c "$PWD"

# Split the left side horizontally for fdata-preview (top 95%) and shell (bottom 5%)
tmux select-pane -t 0
tmux split-window -v -p 10 -c "$PWD"

# Pane 0: Enhanced data browser
tmux select-pane -t 0
tmux send-keys "clear" Enter

# Source the specialized fzf data script
tmux send-keys "source '$DOTFILES/zsh/specials/fzf_data.sh'" Enter
tmux send-keys "clear" Enter
tmux send-keys "fdata-preview" Enter

# Pane 1: Tiny shell for quick commands
tmux select-pane -t 1
tmux send-keys "clear" Enter

# Pane 2: DuckDB environment with data setup
tmux select-pane -t 2
tmux send-keys "clear" Enter
tmux send-keys "echo '🦆 Setting up DuckDB environment...'" Enter

# Check if the load script exists and is executable
if [[ -f "$DOTFILES/zsh/specials/load_data_duckdb.sh" ]]; then
  tmux send-keys "bash '$DOTFILES/zsh/specials/load_data_duckdb.sh'" Enter
  tmux send-keys "duck-watch stop" Enter
  tmux send-keys "duck-watch start" Enter
  tmux send-keys "duck" Enter
  tmux send-keys ".output /tmp/duck_result.csv" Enter
  tmux send-keys ".mode csv" Enter
  tmux send-keys ".header on" Enter
else
  tmux send-keys "echo '❌ DuckDB setup script not found'" Enter
  tmux send-keys "echo '💡 Expected: \$DOTFILES/zsh/specials/load_data_duckdb.sh'" Enter
  tmux send-keys "echo ''" Enter
  tmux send-keys "echo '📋 Manual DuckDB available: duckdb'" Enter
fi
# Pane 3: Clean Python environment
tmux select-pane -t 3
tmux send-keys "clear" Enter
tmux send-keys "ptipython" Enter
tmux send-keys "import pandas as pd, numpy as np" Enter

# Return to main data browser
tmux select-pane -t 0
# ================= Window 3: Data Profiling =======================
tmux new-window -n "profiling" -c "$PWD"

# Split into top (30%) and bottom (70%)
tmux split-window -v -p 70 -c "$PWD"

# Top pane (30%): Enhanced data browser
tmux select-pane -t 0
tmux send-keys "clear" Enter
tmux send-keys "echo '📊 Enhanced Data Discovery'" Enter
tmux send-keys "echo '========================'" Enter
tmux send-keys "echo 'Controls: Ctrl+P to send to profiler below'" Enter
tmux send-keys "echo ''" Enter

# Source the enhanced fzf data script

tmux send-keys "source '$DOTFILES/zsh/specials/fzf_data.sh'" Enter
tmux send-keys "fdata-preview 'right:60%'" Enter
# Bottom pane (70%): DataProfiler environment
tmux select-pane -t 1
tmux send-keys "clear" Enter
tmux send-keys "echo '🔬 DataProfiler Environment'" Enter
tmux send-keys "echo '==========================='" Enter
tmux send-keys "ptpython" Enter
tmux send-keys "import json" Enter
tmux send-keys "import pandas as pd" Enter
tmux send-keys "from dataprofiler import Data, Profiler" Enter
tmux send-keys "print('🔬 DataProfiler ready!')" Enter
tmux send-keys "print('💡 Usage:')" Enter
tmux send-keys "print('  data = Data(\"file.csv\")')" Enter
tmux send-keys "print('  profile = Profiler(data)')" Enter
tmux send-keys "print('  report = profile.report()')" Enter
tmux send-keys "print('  print(report)')" Enter
tmux send-keys "print('')" Enter
tmux send-keys "print('📁 Waiting for file from browser above (Ctrl+P)...')" Enter

# Return to data browser (top pane)
tmux select-pane -t 0
# ================= Window 4: Data Quality =======================
tmux new-window -n "quality" -c "$PWD"
tmux split-window -v -p 50 -c "$PWD"

# Top (pane 1): Data profiling
tmux select-pane -t 0
tmux send-keys "# Data quality and profiling" Enter
tmux send-keys "python" Enter
tmux send-keys "# Example: df.isnull().sum(), df.describe(), df.dtypes" Enter

# Bottom (pane 2): Schema validation
tmux select-pane -t 2
tmux send-keys "# Schema validation and data contracts" Enter
tmux send-keys "# great_expectations, pandera, or custom validation scripts" Enter

# Return to Window 2, Pane 0 the discovery windows
tmux select-window -t "$SESSION_NAME":2
tmux select-pane -t 0

# Attach to session
tmux attach-session -t "$SESSION_NAME"
