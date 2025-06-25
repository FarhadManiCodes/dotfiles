#!/bin/bash
# Modified tmux layout with 1-indexed windows/panes

SESSION_NAME="analysis-$(basename "$PWD")"
cd "$PWD"

# Start new session with window 1
tmux new-session -d -s "$SESSION_NAME" -c "$PWD"

# Window 1: Interactive Analysis
tmux rename-window "interactive"
tmux split-window -h -p 30 -c "$PWD" # Right sidebar 30%
tmux split-window -v -p 70 -c "$PWD" # Split right side

# Main pane (pane 1): Jupyter Lab
tmux select-pane -t 1
tmux send-keys "# Starting Jupyter Lab for interactive analysis" Enter
tmux send-keys "jupyter lab --no-browser --ip=0.0.0.0 --port=8888" Enter

# Top-right (pane 2): Quick Python analysis
tmux select-pane -t 2
tmux send-keys "# Quick data profiling and stats" Enter
tmux send-keys "ptipython" Enter
tmux send-keys "import pandas as pd, numpy as np, seaborn as sns, matplotlib.pyplot as plt" Enter
tmux send-keys "import ydata_profiling as pp  # for data profiling" Enter
tmux send-keys "plt.style.use('seaborn-v0_8')" Enter

# Bottom-right (pane 3): File browser and utils
tmux select-pane -t 3
tmux send-keys "# File operations and quick previews" Enter
tmux send-keys "ls -la *.csv *.json *.parquet 2>/dev/null || echo 'No data files found'" Enter

# Window 2: Data Preview & Discovery
tmux new-window -n "preview" -c "$PWD"

# Split into left (60%) and right (40%)
tmux split-window -h -p 40 -c "$PWD"

# Split the right side vertically for DuckDB (top) and Python (bottom)
tmux select-pane -t 1
tmux split-window -v -p 50 -c "$PWD"

# Split the left side horizontally for fdata-preview (top 95%) and shell (bottom 5%)
tmux select-pane -t 0
tmux split-window -v -p 5 -c "$PWD"

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
  tmux send-keys "duck" Enter
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

# Return to main data browser
tmux select-pane -t 0
# Window 3: Visualization
tmux new-window -n "viz" -c "$PWD"
tmux split-window -h -p 50 -c "$PWD"

# Left (pane 1): Python plotting
tmux select-pane -t 1
tmux send-keys "# Python visualization" Enter
tmux send-keys "ptpython" Enter
tmux send-keys "import matplotlib.pyplot as plt, seaborn as sns, plotly.express as px" Enter

# Right (pane 2): R for advanced stats
tmux select-pane -t 2
tmux send-keys "# R for statistical analysis (optional)" Enter
tmux send-keys "# R --no-save  # Uncomment if R is installed" Enter

# Window 4: Data Quality
tmux new-window -n "quality" -c "$PWD"
tmux split-window -v -p 50 -c "$PWD"

# Top (pane 1): Data profiling
tmux select-pane -t 1
tmux send-keys "# Data quality and profiling" Enter
tmux send-keys "python" Enter
tmux send-keys "# Example: df.isnull().sum(), df.describe(), df.dtypes" Enter

# Bottom (pane 2): Schema validation
tmux select-pane -t 2
tmux send-keys "# Schema validation and data contracts" Enter
tmux send-keys "# great_expectations, pandera, or custom validation scripts" Enter

# Return to Window 1, Pane 1
tmux select-window -t "$SESSION_NAME":1
tmux select-pane -t 1

# Attach to session
tmux attach-session -t "$SESSION_NAME"
