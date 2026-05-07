#!/bin/bash

# Flake8 Performance Patterns - Complete Tmux Workspace Setup
# Usage: ./setup_workspace.sh [project_path] [session_name]
#
# Windows:
# 1. dev    - Main development (vim + terminal + REPL)
# 2. test   - Testing & validation (test files + output)
# 3. ai     - AI & documentation (AI CLI + README + terminal)
# 4. git    - Git operations (LazyGit only)

# Configuration
PROJECT_DIR="${1:-$(pwd)}"
SESSION_NAME="${2:-flake8-perf}"

# Check if session already exists
if tmux has-session -t $SESSION_NAME 2>/dev/null; then
  echo "Session '$SESSION_NAME' already exists. Attaching..."
  tmux attach-session -t $SESSION_NAME
  exit 0
fi

# Create session and first window
echo "Creating tmux session: $SESSION_NAME"
echo "Project directory: $PROJECT_DIR"

# Create session with first window
tmux new-session -d -s $SESSION_NAME -c "$PROJECT_DIR"

# =====================================
# Window 1: Main Development (dev)
# =====================================
tmux rename-window -t $SESSION_NAME:1 "dev"

# Layout A: Horizontal split (vim 70% top, terminal + REPL 30% bottom split)
# Split vim and bottom panes (70/30)
tmux split-window -t $SESSION_NAME:dev -v -p 30 -c "$PROJECT_DIR"

# Split bottom pane horizontally (terminal left, REPL right)
tmux split-window -t $SESSION_NAME:dev.1 -h -p 50 -c "$PROJECT_DIR"

# Pane 0: Start vim with latest edited Python file (default focus)
tmux send-keys -t $SESSION_NAME:dev.0 "vim \$(find . -name '*.py' -not -path './.*' -not -path './__pycache__/*' -type f -exec stat -c '%Y %n' {} \\; 2>/dev/null | sort -nr | head -1 | cut -d' ' -f2- || find . -name '*.py' -type f | head -1 || echo 'main.py')" Enter

# Pane 1: Clean terminal ready for commands
tmux send-keys -t $SESSION_NAME:dev.1 "# Terminal ready: fzf, pytest, flake8" Enter

# Pane 2: ptpython with AST debugging tools (fallback to python)
tmux send-keys -t $SESSION_NAME:dev.2 "clear" Enter

# Start ptpython or python3
if command -v ptpython >/dev/null 2>&1; then
  tmux send-keys -t $SESSION_NAME:dev.2 "ptpython" Enter
  sleep 1
  # Send import commands to ptpython
  tmux send-keys -t $SESSION_NAME:dev.2 "import ast, sys, os" Enter
  tmux send-keys -t $SESSION_NAME:dev.2 "from pathlib import Path" Enter
  tmux send-keys -t $SESSION_NAME:dev.2 "def show_ast(code): return ast.dump(ast.parse(code), indent=2)" Enter
  tmux send-keys -t $SESSION_NAME:dev.2 "def parse_file(filepath): return ast.parse(open(filepath).read())" Enter
  tmux send-keys -t $SESSION_NAME:dev.2 "def find_nodes(tree, node_type): return [node for node in ast.walk(tree) if isinstance(node, node_type)]" Enter
  tmux send-keys -t $SESSION_NAME:dev.2 "print('🐍 AST debugging tools loaded in ptpython!')" Enter
else
  tmux send-keys -t $SESSION_NAME:dev.2 "python3 -c '
import ast
import sys
import os
from pathlib import Path

def show_ast(code):
    return ast.dump(ast.parse(code), indent=2)

def parse_file(filepath):
    with open(filepath) as f:
        return ast.parse(f.read())

def find_nodes(tree, node_type):
    return [node for node in ast.walk(tree) if isinstance(node, node_type)]

print(\"🐍 AST debugging tools loaded!\")
print(\"Available: show_ast(), parse_file(), find_nodes()\")
import code
code.interact(local=locals())
'" Enter
fi

# =====================================
# Window 2: Testing & Validation (test)
# =====================================
tmux new-window -t $SESSION_NAME -n "test" -c "$PROJECT_DIR"

# Split top/bottom (60/40) - test files top, output bottom
tmux split-window -t $SESSION_NAME:test -v -p 40 -c "$PROJECT_DIR/tests"

# Top pane: vim in tests directory with most recent test file
tmux send-keys -t $SESSION_NAME:test.0 "cd tests && vim \$(ls -t test_*.py 2>/dev/null | head -1 || echo 'test_')" Enter

# Bottom pane: test output with helpful commands (also in tests directory)
tmux send-keys -t $SESSION_NAME:test.1 "clear" Enter
tmux send-keys -t $SESSION_NAME:test.1 "printf '🧪 Testing Commands:\n  pytest -v                    # Verbose tests\n  pytest --cov                 # With coverage report\n  pytest -x                    # Stop on first failure\n  pytest test_string.py        # Specific test file\n  flake8 ../examples/ --select=HP # Plugin testing\n\nFocus: PASS/FAIL status, error messages, coverage %%\n'" Enter

# =====================================
# Window 3: AI Research & Documentation (ai)
# =====================================
tmux new-window -t $SESSION_NAME -n "ai" -c "$PROJECT_DIR"

# Split top/bottom (50/50), then split bottom horizontally
tmux split-window -t $SESSION_NAME:ai -v -p 50 -c "$PROJECT_DIR"
tmux split-window -t $SESSION_NAME:ai.1 -h -p 50 -c "$PROJECT_DIR"

# Top pane: Clean terminal for AI CLI
tmux send-keys -t $SESSION_NAME:ai.0 "clear" Enter

# Bottom left: vim with README
tmux send-keys -t $SESSION_NAME:ai.1 "vim README.md" Enter

# Bottom right: clean terminal
tmux send-keys -t $SESSION_NAME:ai.2 "clear" Enter

# =====================================
# Window 4: Git & Project Management (git)
# =====================================
tmux new-window -t $SESSION_NAME -n "git" -c "$PROJECT_DIR"

# Single pane: Auto-start LazyGit
tmux send-keys -t $SESSION_NAME:git.0 "lazygit" Enter

# =====================================
# Enhanced Key Bindings
# =====================================

# TODO: Layout switching for Window 1 (implement later)
# tmux bind-key L run-shell 'toggle_dev_layout'

# =====================================
# Final Setup
# =====================================

# Select Window 1 (dev) and focus on vim by default
tmux select-window -t $SESSION_NAME:dev
tmux select-pane -t $SESSION_NAME:dev.0

# Attach to session
echo ""
echo "🎉 Complete workspace ready!"
echo ""
echo "Windows:"
echo "  1. dev    - Main development (vim + terminal + REPL)"
echo "  2. test   - Testing (test files + output + coverage)"
echo "  3. ai     - AI assistance (claude/gemini + docs + terminal)"
echo "  4. git    - Git operations (LazyGit only)"
echo ""
echo "Navigation: Ctrl-a [1-4] or Ctrl-a + :select-window -t [window-name]"
echo ""
echo "Attaching to session..."

tmux attach-session -t $SESSION_NAME

