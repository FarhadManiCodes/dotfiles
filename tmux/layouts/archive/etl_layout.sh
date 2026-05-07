#!/bin/bash
# ETL Development Layout - Clean Version (No Echo Duplication)

SESSION_NAME="etl-$(basename "$PWD")"
cd "$PWD" | exit

echo "🚀 Creating ETL Development workspace: $SESSION_NAME"
echo "📁 Working directory: $PWD"
echo "⏳ Setting up 6 windows..."

# Create new session
tmux new-session -d -s "$SESSION_NAME" -c "$PWD"

# Helper function to create info panels without echo duplication
create_info_panel() {
  local info_text="$1"
  printf '%s\n' "$info_text"
}

# ============================================================================
# Window 1: Main Development (dev)
# ============================================================================
echo "📝 Setting up Window 1: Main Development"
tmux rename-window "dev"
tmux split-window -h -p 40 -c "$PWD"
tmux split-window -v -p 50 -c "$PWD"

# Pane 0: Code editor
tmux select-pane -t 0
tmux send-keys "clear" Enter
tmux send-keys "vim ." Enter

# Pane 1: ptpython REPL
tmux select-pane -t 1
tmux send-keys "clear" Enter
if command -v ptpython &>/dev/null; then
  tmux send-keys "ptpython" Enter
  tmux send-keys "import pandas as pd, numpy as np, sqlite3, json, csv" Enter
  tmux send-keys "from pathlib import Path" Enter
  tmux send-keys "print('🐍 ETL libraries loaded')" Enter
else
  tmux send-keys "python" Enter
  tmux send-keys "import pandas as pd, numpy as np" Enter
  tmux send-keys "print('🐍 Python ready for ETL')" Enter
fi

# Pane 2: File operations
tmux select-pane -t 2
tmux send-keys "clear" Enter
tmux send-keys "ls -la" Enter
tmux send-keys "git status 2>/dev/null || printf '\\n📁 Files ready\\n'" Enter

# ============================================================================
# Window 2: Git Management (git)
# ============================================================================
echo "🌳 Setting up Window 2: Git Management"
tmux new-window -n "git" -c "$PWD"
tmux send-keys "clear" Enter
if command -v lazygit &>/dev/null; then
  tmux send-keys "lazygit" Enter
else
  tmux send-keys "printf '❌ lazygit not found\\nInstall: https://github.com/jesseduffield/lazygit\\n\\n'" Enter
  tmux send-keys "git log --oneline -10 2>/dev/null || printf 'Not a git repository\\n'" Enter
fi

# ============================================================================
# Window 3: Data Exploration (explore)
# ============================================================================
echo "🔍 Setting up Window 3: Data Exploration"
tmux new-window -n "explore" -c "$PWD"
tmux split-window -h -p 50 -c "$PWD"  # Horizontal split: 50% left, 50% right

# Split the left pane vertically: 70% top (DuckDB), 30% bottom (Jupyter)
tmux select-pane -t 0
tmux split-window -v -p 30 -c "$PWD"  # Split left side: 70% top, 30% bottom

# Top-left pane (70% of left): DuckDB
tmux select-pane -t 0
tmux send-keys "clear" Enter
if command -v duckdb &> /dev/null; then
    tmux send-keys "duckdb" Enter
    tmux send-keys "-- 🦆 DuckDB ready for analytics" Enter
    tmux send-keys "-- Quick commands:" Enter
    tmux send-keys "-- .help        # Show help" Enter
    tmux send-keys "-- .tables      # List tables" Enter
    tmux send-keys "-- .schema      # Show schema" Enter
    tmux send-keys "-- SELECT * FROM read_csv_auto('file.csv');" Enter
else
    tmux send-keys "printf '❌ DuckDB not found\\nInstall: pip install duckdb\\n\\nUsing SQLite instead:\\n'" Enter
    tmux send-keys "sqlite3" Enter
fi

# Bottom-left pane (30% of left): Jupyter Lab with log monitoring
tmux select-pane -t 1
tmux send-keys "clear" Enter
tmux send-keys "printf '🚀 Starting Jupyter Lab for data exploration...\\n'" Enter
tmux send-keys "printf 'Port: 8889 (to avoid conflicts with main dev)\\n'" Enter
tmux send-keys "printf 'Starting in background and monitoring logs...\\n\\n'" Enter

# Start Jupyter Lab in background on port 8889 (to avoid conflicts)
tmux send-keys "jupyter-smart 8889 > /dev/null 2>&1 &" Enter
tmux send-keys "sleep 3" Enter

# Start log monitoring with connection info
tmux send-keys "printf '📊 Jupyter Lab Logs (Live monitoring)\\n'" Enter
tmux send-keys "printf 'Press Ctrl+C in this pane for Jupyter options\\n'" Enter
tmux send-keys "printf 'Port: 8889 | Use jupyter-smart 8889 url for quick access\\n'" Enter
tmux send-keys "printf '----------------------------------------\\n\\n'" Enter
tmux send-keys "jupyter-log-monitor 8889" Enter

# Right pane (50% of window): ptpython for data analysis
tmux select-pane -t 2
tmux send-keys "clear" Enter
if command -v ptpython &> /dev/null; then
    tmux send-keys "ptipython" Enter
    tmux send-keys "import pandas as pd, numpy as np, matplotlib.pyplot as plt, seaborn as sns" Enter
    tmux send-keys "pd.set_option('display.max_columns', None)" Enter
    tmux send-keys "print('🔬 Data exploration ready')" Enter
else
    tmux send-keys "python" Enter
    tmux send-keys "import pandas as pd, numpy as np" Enter
    tmux send-keys "print('🔬 Basic data tools loaded')" Enter
fi
# ============================================================================
# Window 4: Database Connections (db)
# ============================================================================
echo "🗄️ Setting up Window 4: Database Connections"
tmux new-window -n "db" -c "$PWD"
tmux split-window -h -p 50 -c "$PWD"

# PostgreSQL pane
tmux select-pane -t 0
tmux send-keys "clear" Enter
tmux send-keys "cat << 'EOF'" Enter
tmux send-keys "🐘 PostgreSQL Connection" Enter
tmux send-keys "" Enter
tmux send-keys "Commands:" Enter
tmux send-keys "  psql -U postgres              # Local" Enter
tmux send-keys "  psql -U postgres -d dbname    # Specific DB" Enter
tmux send-keys "  psql -h host -U user -d db    # Remote" Enter
tmux send-keys "" Enter
tmux send-keys "Quick commands:" Enter
tmux send-keys "  \\l     # List databases" Enter
tmux send-keys "  \\dt    # List tables" Enter
tmux send-keys "  \\d     # Describe table" Enter
tmux send-keys "" Enter
tmux send-keys "EOF" Enter

if command -v psql &>/dev/null; then
  tmux send-keys "printf '✅ psql available\\n'" Enter
  tmux send-keys "pg_isready 2>/dev/null && printf '✅ PostgreSQL server ready\\n' || printf '❌ Server not responding\\n'" Enter
else
  tmux send-keys "printf '❌ Install: sudo apt install postgresql-client\\n'" Enter
fi

# Redis pane
tmux select-pane -t 1
tmux send-keys "clear" Enter
tmux send-keys "cat << 'EOF'" Enter
tmux send-keys "🔴 Redis Connection" Enter
tmux send-keys "" Enter
tmux send-keys "Commands:" Enter
tmux send-keys "  redis-cli                     # Local" Enter
tmux send-keys "  redis-cli -h host -p 6379    # Remote" Enter
tmux send-keys "  redis-cli -a password        # With auth" Enter
tmux send-keys "" Enter
tmux send-keys "Quick commands:" Enter
tmux send-keys "  PING       # Test connection" Enter
tmux send-keys "  INFO       # Server info" Enter
tmux send-keys "  DBSIZE     # Key count" Enter
tmux send-keys "" Enter
tmux send-keys "EOF" Enter

if command -v redis-cli &>/dev/null; then
  tmux send-keys "printf '✅ redis-cli available\\n'" Enter
  tmux send-keys "redis-cli ping 2>/dev/null && printf '✅ Redis responding\\n' || printf '❌ Server not responding\\n'" Enter
else
  tmux send-keys "printf '❌ Install: sudo apt install redis-tools\\n'" Enter
fi

# ============================================================================
# Window 5: Monitoring (monitor)
# ============================================================================
echo "📊 Setting up Window 5: Monitoring"
tmux new-window -n "monitor" -c "$PWD"
tmux split-window -h -p 50 -c "$PWD"
tmux split-window -v -p 50 -c "$PWD"
tmux select-pane -t 0
tmux split-window -v -p 50 -c "$PWD"

# Pane 0: htop
tmux select-pane -t 0
tmux send-keys "htop" Enter

# Pane 1: Docker stats
tmux select-pane -t 1
tmux send-keys "clear" Enter
if command -v docker &>/dev/null; then
  tmux send-keys "docker stats 2>/dev/null || printf 'No running containers\\nTry: docker ps -a\\n'" Enter
else
  tmux send-keys "printf 'Docker not available\\n'" Enter
fi

# Pane 2: Disk monitoring
tmux select-pane -t 2
tmux send-keys "watch -n 10 'printf \"=== Disk Usage ===\\n\" && df -h | head -5 && printf \"\\n=== Data Directories ===\\n\" && du -sh data/ datasets/ *.csv *.parquet *.json logs/ 2>/dev/null | head -8'" Enter

# Pane 3: Process monitoring
tmux select-pane -t 3
tmux send-keys "watch -n 5 'printf \"=== Python Processes ===\\n\" && ps aux | grep -E \"(python|jupyter)\" | grep -v grep | head -4 && printf \"\\n=== Memory ===\\n\" && free -h && printf \"\\n=== Load ===\\n\" && uptime'" Enter

# ============================================================================
# Window 6: Testing (test)
# ============================================================================
echo "🧪 Setting up Window 6: Testing"
tmux new-window -n "test" -c "$PWD"
tmux split-window -h -p 50 -c "$PWD"
tmux split-window -v -p 50 -c "$PWD"

# Pane 0: Test writing
tmux select-pane -t 0
tmux send-keys "clear" Enter
tmux send-keys "cat << 'EOF'" Enter
tmux send-keys "✍️ Test Writing & Exploration" Enter
tmux send-keys "" Enter
tmux send-keys "Commands:" Enter
tmux send-keys "  vim test_*.py" Enter
tmux send-keys "  find . -name 'test_*.py'" Enter
tmux send-keys "" Enter
tmux send-keys "EOF" Enter
tmux send-keys "ls test_*.py tests/ 2>/dev/null || printf 'No test files found\\n'" Enter

# Pane 1: Test runner
tmux select-pane -t 1
tmux send-keys "clear" Enter
tmux send-keys "cat << 'EOF'" Enter
tmux send-keys "🚀 Pytest Commands" Enter
tmux send-keys "" Enter
tmux send-keys "  pytest -v              # Verbose" Enter
tmux send-keys "  pytest -x              # Stop on fail" Enter
tmux send-keys "  pytest test_file.py    # Specific file" Enter
tmux send-keys "  pytest --lf            # Last failed" Enter
tmux send-keys "" Enter
tmux send-keys "EOF" Enter
if command -v pytest &>/dev/null; then
  tmux send-keys "printf '✅ pytest available\\n'" Enter
else
  tmux send-keys "printf '❌ Install: pip install pytest\\n'" Enter
fi

# Pane 2: Coverage
tmux select-pane -t 2
tmux send-keys "clear" Enter
tmux send-keys "cat << 'EOF'" Enter
tmux send-keys "📊 Coverage & Watch" Enter
tmux send-keys "" Enter
tmux send-keys "  pytest --cov=." Enter
tmux send-keys "  pytest --cov-report=html" Enter
tmux send-keys "  ptw                    # Watch mode" Enter
tmux send-keys "" Enter
tmux send-keys "EOF" Enter
if command -v ptw &>/dev/null; then
  tmux send-keys "printf '✅ pytest-watch available\\n'" Enter
else
  tmux send-keys "printf 'Install: pip install pytest-watch\\n'" Enter
fi

# ============================================================================
# Final setup
# ============================================================================
tmux select-window -t 1
tmux select-pane -t 0

# Get the actual tmux prefix key
TMUX_PREFIX=$(tmux show-options -g prefix | cut -d' ' -f2 | sed 's/C-/Ctrl+/')

echo "✅ ETL Development workspace created successfully!"
echo ""
echo "🪟 Windows created:"
echo "  1. dev     - Main development (vim + ptpython + files)"
echo "  2. git     - Git management with lazygit"
echo "  3. explore - Data exploration (ptpython + DuckDB)"
echo "  4. db      - Database connections (PostgreSQL + Redis)"
echo "  5. monitor - System monitoring and logs"
echo "  6. test    - Pytest testing environment"
echo ""
echo "🎯 Attaching to session: $SESSION_NAME"
echo "📋 Use $TMUX_PREFIX then 1-6 to switch between windows"
echo "📋 Use $TMUX_PREFIX then arrow keys to switch between panes"

# Attach to session (handle nested tmux sessions)
if [ -n "$TMUX" ]; then
  echo "🔄 Switching to session: $SESSION_NAME"
  tmux switch-client -t "$SESSION_NAME"
else
  echo "🔗 Attaching to session: $SESSION_NAME"
  tmux attach-session -t "$SESSION_NAME"
fi
