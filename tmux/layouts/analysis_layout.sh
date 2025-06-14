#!/bin/bash
# Data Analysis Layout - Perfect for exploratory data analysis

SESSION_NAME="analysis-$(basename "$PWD")"
cd "$PWD"

tmux new-session -d -s "$SESSION_NAME" -c "$PWD"

# Window 1: Interactive Analysis
tmux rename-window "interactive"
tmux split-window -h -p 30 -c "$PWD"  # Right sidebar 30%
tmux split-window -v -p 70 -c "$PWD"  # Split right side

# Main pane: Jupyter Lab
tmux select-pane -t 0
tmux send-keys "# Starting Jupyter Lab for interactive analysis" Enter
tmux send-keys "jupyter lab --no-browser --ip=0.0.0.0 --port=8888" Enter

# Top-right: Quick Python analysis
tmux select-pane -t 1
tmux send-keys "# Quick data profiling and stats" Enter
tmux send-keys "ipython" Enter
tmux send-keys "import pandas as pd, numpy as np, seaborn as sns, matplotlib.pyplot as plt" Enter
tmux send-keys "import ydata_profiling as pp  # for data profiling" Enter
tmux send-keys "plt.style.use('seaborn-v0_8')" Enter

# Bottom-right: File browser and utils
tmux select-pane -t 2
tmux send-keys "# File operations and quick previews" Enter
tmux send-keys "ls -la *.csv *.json *.parquet 2>/dev/null || echo 'No data files found'" Enter

# Window 2: Data Preview & Stats
tmux new-window -n "preview" -c "$PWD"
tmux split-window -v -p 50 -c "$PWD"

# Top: Data file previews
tmux select-pane -t 0
tmux send-keys "# Data file previews - use commands like:" Enter
tmux send-keys "# head -n 20 data.csv | column -t -s," Enter
tmux send-keys "# python -c \"import pandas as pd; print(pd.read_csv('data.csv').info())\"" Enter

# Bottom: Statistical analysis
tmux select-pane -t 1
tmux send-keys "# Statistical analysis and data quality checks" Enter
tmux send-keys "python" Enter
tmux send-keys "import pandas as pd, numpy as np" Enter

# Window 3: Visualization
tmux new-window -n "viz" -c "$PWD"
tmux split-window -h -p 50 -c "$PWD"

# Left: Python plotting
tmux select-pane -t 0
tmux send-keys "# Python visualization" Enter
tmux send-keys "python" Enter
tmux send-keys "import matplotlib.pyplot as plt, seaborn as sns, plotly.express as px" Enter

# Right: R for advanced stats (if available)
tmux select-pane -t 1
tmux send-keys "# R for statistical analysis (optional)" Enter
tmux send-keys "# R --no-save  # Uncomment if R is installed" Enter

# Window 4: Data Quality
tmux new-window -n "quality" -c "$PWD"
tmux split-window -v -p 50 -c "$PWD"

# Top: Data profiling
tmux select-pane -t 0
tmux send-keys "# Data quality and profiling" Enter
tmux send-keys "python" Enter
tmux send-keys "# Example: df.isnull().sum(), df.describe(), df.dtypes" Enter

# Bottom: Schema validation
tmux select-pane -t 1
tmux send-keys "# Schema validation and data contracts" Enter
tmux send-keys "# great_expectations, pandera, or custom validation scripts" Enter

tmux select-window -t 1
tmux select-pane -t 0
tmux attach-session -t "$SESSION_NAME"
