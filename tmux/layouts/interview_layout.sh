#!/bin/bash

# Interview Layout for Tmux
# Specialized 4-window session for technical interviews in data engineering/science

set -e

# Configuration
SESSION_NAME="interview-$(basename "$PWD")"
WORK_DIR="$PWD"
INTERVIEW_DATA_DIR="$WORK_DIR/interview_data"
QUARANTINE_DIR="$WORK_DIR/interview_downloads_quarantine"

# Color definitions for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check for existing session
if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    log_info "Session '$SESSION_NAME' already exists. Attaching..."
    tmux attach-session -t "$SESSION_NAME"
    exit 0
fi

# Create interview data directories
mkdir -p "$INTERVIEW_DATA_DIR"
mkdir -p "$QUARANTINE_DIR"
log_info "Created interview directories"

# Create new session
log_info "Creating new session: $SESSION_NAME"
tmux new-session -d -s "$SESSION_NAME" -c "$WORK_DIR"

# Set environment variables for the session
tmux set-environment -t "$SESSION_NAME" TMUX_SMART_START 1
tmux set-environment -t "$SESSION_NAME" INTERVIEW_DATA_DIR "$INTERVIEW_DATA_DIR"
tmux set-environment -t "$SESSION_NAME" QUARANTINE_DIR "$QUARANTINE_DIR"

# ============================================================================
# WINDOW 1: "workspace" - Primary Coding Environment
# ============================================================================

log_info "Setting up Window 1: workspace"
tmux rename-window -t "$SESSION_NAME":1 "workspace"

# Create panes - starting with single pane, then splitting

# Split horizontally first - create top (75%) and bottom (25%)
tmux split-window -t "$SESSION_NAME":1 -v -p 20

# Split the top pane vertically - create main editor (70%) and Python REPL (30%)
tmux split-window -t "$SESSION_NAME":1.0 -h -p 30

# Split the bottom pane vertically - create test output (70%) and notes (30%)
tmux split-window -t "$SESSION_NAME":1.2 -h -p 30


# === Pane 0: Main Editor ===
tmux send-keys -t "$SESSION_NAME":1.0 "cd '$WORK_DIR'" Enter

# Find the most recently edited file recursively (excluding quick_notes.md and hidden files)
LATEST_FILE=$(find "$WORK_DIR" -type f \( -name "*.py" -o -name "*.js" -o -name "*.ts" -o -name "*.java" -o -name "*.cpp" -o -name "*.c" -o -name "*.sh" -o -name "*.sql" -o -name "*.md" -o -name "*.txt" -o -name "*.json" -o -name "*.csv" -o -name "*.yml" -o -name "*.yaml" \) ! -name "quick_notes.md" ! -path "*/.*" -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -1 | cut -d' ' -f2-)

if [ -n "$LATEST_FILE" ] && [ -f "$LATEST_FILE" ]; then
    log_info "Opening latest file: $(basename "$LATEST_FILE")"
    tmux send-keys -t "$SESSION_NAME":1.0 "vim -c 'let g:limelight_default_coefficient = 0.8' -c 'let g:limelight_paragraph_span = 0' '$LATEST_FILE'" Enter
else
    log_info "No recent files found, starting vim with clean slate"
    tmux send-keys -t "$SESSION_NAME":1.0 "vim -c 'let g:limelight_default_coefficient = 0.8' -c 'let g:limelight_paragraph_span = 0'" Enter
fi

# === Pane 1: Python REPL ===
tmux send-keys -t "$SESSION_NAME":1.1 "cd '$WORK_DIR'" Enter
tmux send-keys -t "$SESSION_NAME":1.1 "clear" Enter
tmux send-keys -t "$SESSION_NAME":1.1 "ptpython" Enter
# Send the imports to ptpython
tmux send-keys -t "$SESSION_NAME":1.1 "import sys, os, math, heapq, bisect" Enter
tmux send-keys -t "$SESSION_NAME":1.1 "from collections import defaultdict, deque, Counter" Enter
tmux send-keys -t "$SESSION_NAME":1.1 "from typing import List, Dict, Optional, Tuple, Set" Enter
tmux send-keys -t "$SESSION_NAME":1.1 "import pandas as pd, numpy as np" Enter
tmux send-keys -t "$SESSION_NAME":1.1 "print('🐍 Interview environment ready!')" Enter

# === Pane 2: Test Output ===
tmux send-keys -t "$SESSION_NAME":1.2 "cd '$WORK_DIR'" Enter
tmux send-keys -t "$SESSION_NAME":1.2 "clear" Enter

# === Pane 3: Quick Notes ===
tmux send-keys -t "$SESSION_NAME":1.3 "cd '$WORK_DIR'" Enter
# Create a notes template
cat > "$WORK_DIR/quick_notes.md" << 'EOF'
# Quick Notes

## Problem
- 

## Approach
- 

## Time Complexity
- 

## Space Complexity
- 

## Edge Cases
- 

## Implementation Notes
- 

EOF

tmux send-keys -t "$SESSION_NAME":1.3 "vim -c 'set nonumber norelativenumber' -c 'set background=dark' -c 'colorscheme PaperColor' -c 'let g:lightline.colorscheme=\"PaperColor_dark\"' -c 'call lightline#init()' -c 'call lightline#colorscheme()' -c 'let g:limelight_default_coefficient = 0.8' -c 'let g:limelight_paragraph_span = 0' -c 'Goyo' quick_notes.md" Enter

# ============================================================================
# PLACEHOLDER WINDOWS (will be implemented in subsequent steps)
# ============================================================================

# ============================================================================
# WINDOW 2: "data" - Data Engineering Playground (adapted from analysis_layout.sh)
# ============================================================================

log_info "Setting up Window 2: data"
tmux new-window -t "$SESSION_NAME" -n "data" -c "$WORK_DIR"

# Split into left (60%) and right (40%)
tmux split-window -t "$SESSION_NAME":2 -h -p 40 -c "$WORK_DIR"

# Split the right side vertically for DuckDB (top) and Python (bottom)
tmux select-pane -t "$SESSION_NAME":2.1
tmux split-window -v -p 50 -c "$WORK_DIR"

# Split the left side horizontally for fdata-preview (top 95%) and shell (bottom 5%)
tmux select-pane -t "$SESSION_NAME":2.0
tmux split-window -v -p 5 -c "$WORK_DIR"

# === Pane 0: Enhanced data browser ===
tmux select-pane -t "$SESSION_NAME":2.0
tmux send-keys "clear" Enter
# Source the specialized fzf data script
tmux send-keys "source '$DOTFILES/zsh/specials/fzf_data.sh'" Enter
tmux send-keys "clear" Enter
tmux send-keys "fdata-preview" Enter

# === Pane 1: Tiny shell for quick commands ===
tmux select-pane -t "$SESSION_NAME":2.1
tmux send-keys "clear" Enter

# === Pane 2: DuckDB environment with data setup ===
tmux select-pane -t "$SESSION_NAME":2.2
tmux send-keys "clear" Enter
tmux send-keys "echo '🦆 Setting up DuckDB environment...'" Enter

# Check if the load script exists and is executable
if [[ -f "$DOTFILES/zsh/specials/load_data_duckdb.sh" ]]; then
  tmux send-keys -t "$SESSION_NAME":2.2 "bash '$DOTFILES/zsh/specials/load_data_duckdb.sh'" Enter
  tmux send-keys -t "$SESSION_NAME":2.2 "duck-watch stop" Enter
  tmux send-keys -t "$SESSION_NAME":2.2 "duck-watch start" Enter
  tmux send-keys -t "$SESSION_NAME":2.2 "duck" Enter
  tmux send-keys -t "$SESSION_NAME":2.2 ".output /tmp/duck_result.csv" Enter
  tmux send-keys -t "$SESSION_NAME":2.2 ".mode csv" Enter
  tmux send-keys -t "$SESSION_NAME":2.2 ".header on" Enter
else
  tmux send-keys -t "$SESSION_NAME":2.2 "echo '❌ DuckDB setup script not found'" Enter
  tmux send-keys -t "$SESSION_NAME":2.2 "echo '💡 Expected: \$DOTFILES/zsh/specials/load_data_duckdb.sh'" Enter
  tmux send-keys -t "$SESSION_NAME":2.2 "echo ''" Enter
  tmux send-keys -t "$SESSION_NAME":2.2 "echo '📋 Manual DuckDB available: duckdb'" Enter
fi

# === Pane 3: Clean Python environment ===
tmux select-pane -t "$SESSION_NAME":2.3
tmux send-keys "clear" Enter
tmux send-keys "ptipython" Enter
tmux send-keys "import pandas as pd, numpy as np" Enter
tmux send-keys "from pathlib import Path" Enter
tmux send-keys "import json" Enter
tmux send-keys "data_dir = Path('$INTERVIEW_DATA_DIR')" Enter

# Return to main data browser
tmux select-pane -t "$SESSION_NAME":2.0

# ============================================================================
# WINDOW 3: "analysis" - Feature Engineering & Statistics
# ============================================================================

log_info "Setting up Window 3: analysis"
tmux new-window -t "$SESSION_NAME" -n "analysis" -c "$WORK_DIR"

# Split horizontally - create top (50%) and bottom (50%)
tmux split-window -t "$SESSION_NAME":3 -v -p 50 -c "$WORK_DIR"

# === Pane 0: Feature Engineering ===
tmux select-pane -t "$SESSION_NAME":3.0
tmux send-keys "cd '$WORK_DIR'" Enter
tmux send-keys "clear" Enter
tmux send-keys "ptpython" Enter
# Pre-loaded imports for feature engineering
tmux send-keys "import pandas as pd" Enter
tmux send-keys "import numpy as np" Enter
tmux send-keys "from sklearn.preprocessing import StandardScaler, LabelEncoder, OneHotEncoder" Enter
tmux send-keys "from sklearn.feature_selection import SelectKBest, chi2, f_classif" Enter
tmux send-keys "from pathlib import Path" Enter
tmux send-keys "data_dir = Path('$INTERVIEW_DATA_DIR')" Enter
tmux send-keys "" Enter

# Helper functions for feature engineering
tmux send-keys "def create_datetime_features(df, date_col):" Enter
tmux send-keys "    \"\"\"Extract year, month, day, dayofweek from datetime column\"\"\"" Enter
tmux send-keys "    df[f'{date_col}_year'] = df[date_col].dt.year" Enter
tmux send-keys "    df[f'{date_col}_month'] = df[date_col].dt.month" Enter
tmux send-keys "    df[f'{date_col}_day'] = df[date_col].dt.day" Enter
tmux send-keys "    df[f'{date_col}_dayofweek'] = df[date_col].dt.dayofweek" Enter
tmux send-keys "    return df" Enter
tmux send-keys "" Enter

tmux send-keys "def create_interaction_features(df, col1, col2):" Enter
tmux send-keys "    \"\"\"Create interaction feature between two columns\"\"\"" Enter
tmux send-keys "    df[f'{col1}_{col2}_interaction'] = df[col1] * df[col2]" Enter
tmux send-keys "    return df" Enter
tmux send-keys "" Enter

tmux send-keys "def quick_binning(df, col, bins=5):" Enter
tmux send-keys "    \"\"\"Create binned version of continuous variable\"\"\"" Enter
tmux send-keys "    df[f'{col}_binned'] = pd.cut(df[col], bins=bins, labels=False)" Enter
tmux send-keys "    return df" Enter
tmux send-keys "" Enter

tmux send-keys "print('🔧 Feature Engineering Environment Ready!')" Enter
tmux send-keys "print('📊 Helper functions: create_datetime_features, create_interaction_features, quick_binning')" Enter

# === Pane 1: Stats Analysis ===
tmux select-pane -t "$SESSION_NAME":3.1
tmux send-keys "cd '$WORK_DIR'" Enter
tmux send-keys "clear" Enter
tmux send-keys "ptpython" Enter
# Pre-loaded imports for statistical analysis
tmux send-keys "from scipy import stats" Enter
tmux send-keys "import statsmodels.api as sm" Enter
tmux send-keys "import numpy as np" Enter
tmux send-keys "import pandas as pd" Enter
tmux send-keys "from pathlib import Path" Enter
tmux send-keys "data_dir = Path('$INTERVIEW_DATA_DIR')" Enter
tmux send-keys "" Enter

# Helper functions for statistical analysis
tmux send-keys "def quick_ttest(group1, group2):" Enter
tmux send-keys "    \"\"\"Perform independent t-test between two groups\"\"\"" Enter
tmux send-keys "    statistic, p_value = stats.ttest_ind(group1, group2)" Enter
tmux send-keys "    print(f'T-test: statistic={statistic:.3f}, p-value={p_value:.3f}')" Enter
tmux send-keys "    return statistic, p_value" Enter
tmux send-keys "" Enter

tmux send-keys "def quick_correlation(df, col1, col2):" Enter
tmux send-keys "    \"\"\"Calculate Pearson correlation between two columns\"\"\"" Enter
tmux send-keys "    corr, p_value = stats.pearsonr(df[col1], df[col2])" Enter
tmux send-keys "    print(f'Correlation: {corr:.3f}, p-value={p_value:.3f}')" Enter
tmux send-keys "    return corr, p_value" Enter
tmux send-keys "" Enter

tmux send-keys "def quick_anova(df, category_col, numeric_col):" Enter
tmux send-keys "    \"\"\"Perform one-way ANOVA\"\"\"" Enter
tmux send-keys "    groups = [group[numeric_col].values for name, group in df.groupby(category_col)]" Enter
tmux send-keys "    f_stat, p_value = stats.f_oneway(*groups)" Enter
tmux send-keys "    print(f'ANOVA: F={f_stat:.3f}, p-value={p_value:.3f}')" Enter
tmux send-keys "    return f_stat, p_value" Enter
tmux send-keys "" Enter

tmux send-keys "print('📈 Statistical Analysis Environment Ready!')" Enter
tmux send-keys "print('🧪 Helper functions: quick_ttest, quick_correlation, quick_anova')" Enter

# ============================================================================
# WINDOW 4: "comm" - Communication Hub
# ============================================================================

log_info "Setting up Window 4: comm"
tmux new-window -t "$SESSION_NAME" -n "comm" -c "$WORK_DIR"

# Create 4 panes: email, file download, file monitor, quick share
# Split horizontally first - create top (50%) and bottom (50%)
tmux split-window -t "$SESSION_NAME":4 -v -p 50 -c "$WORK_DIR"

# Split the top pane vertically - create email (50%) and file download (50%)
tmux split-window -t "$SESSION_NAME":4.0 -h -p 50 -c "$WORK_DIR"

# Split the bottom pane vertically - create file monitor (50%) and quick share (50%)
tmux split-window -t "$SESSION_NAME":4.2 -h -p 50 -c "$WORK_DIR"

# Now we have 4 panes:
# 0: Email (top-left, 50%x50%)
# 1: File Download (top-right, 50%x50%)
# 2: File Monitor (bottom-left, 50%x50%)
# 3: Quick Share (bottom-right, 50%x50%)

# === Pane 0: Email (Gmail API with Python) ===
tmux select-pane -t "$SESSION_NAME":4.0
tmux send-keys "cd '$WORK_DIR'" Enter
tmux send-keys "clear" Enter
tmux send-keys "echo '📧 Email - Gmail API with Python'" Enter
tmux send-keys "echo 'Placeholder: To be implemented'" Enter

# === Pane 1: File Download ===
tmux select-pane -t "$SESSION_NAME":4.1
tmux send-keys "cd '$WORK_DIR'" Enter
tmux send-keys "clear" Enter
tmux send-keys "echo '⬇️ File Download - Smart Download'" Enter
tmux send-keys "echo 'Placeholder: To be implemented'" Enter

# === Pane 2: File Monitor ===
tmux select-pane -t "$SESSION_NAME":4.2
tmux send-keys "cd '$WORK_DIR'" Enter
tmux send-keys "clear" Enter
tmux send-keys "echo '👁️ File Monitor - Chat Platforms'" Enter
tmux send-keys "echo 'Placeholder: To be implemented'" Enter

# === Pane 3: Quick Share ===
tmux select-pane -t "$SESSION_NAME":4.3
tmux send-keys "cd '$WORK_DIR'" Enter
tmux send-keys "clear" Enter
tmux send-keys "echo '📤 Quick Share - Copy + Zip'" Enter
tmux send-keys "echo 'Placeholder: To be implemented'" Enter

# ============================================================================
# SESSION FINALIZATION
# ============================================================================

# Select the main editor pane in workspace window
tmux select-window -t "$SESSION_NAME":1
tmux select-pane -t "$SESSION_NAME":1.0

log_success "Interview layout created successfully!"
log_info "Windows created:"
log_info "  1. workspace - Primary coding environment"
log_info "  2. data - Data engineering playground (placeholder)"
log_info "  3. analysis - Feature engineering & statistics (placeholder)"
log_info "  4. comm - Communication hub (placeholder)"
log_info ""
log_info "Data directories:"
log_info "  - Interview data: $INTERVIEW_DATA_DIR"
log_info "  - Quarantine: $QUARANTINE_DIR"
log_info ""
log_info "Starting on Window 1 (workspace) - Main Editor"

# Attach to the session
tmux attach-session -t "$SESSION_NAME"
