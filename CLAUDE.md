# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a comprehensive dotfiles repository containing shell configurations, development tools, and productivity enhancements for a Linux-based development environment. The setup focuses on data science, Python development, and terminal productivity.

## Installation and Setup

- **Main installer**: `./install.sh` - Sets up all dotfile configurations with XDG compliance
- **Post-installation**: Run `source ~/.zshrc` to activate new shell configuration
- **Vim plugins**: Install with `vim +PlugInstall +qall`
- **Tmux plugins**: Install with `Prefix + I` (if using tpm)

## Key Architecture Components

### Shell Environment (Zsh)
- **Main config**: `zsh/scripts.sh` - Loads all productivity modules with error handling
- **Aliases**: `zsh/aliases` - Enhanced aliases for eza, tmux, git, and development tools
- **Productivity modules**: `zsh/productivity/` directory contains modular enhancements:
  - `fzf-enhancements.sh` - Advanced fuzzy finding functions
  - `fzf_profile.sh` - Data profiling system with YAML config support
  - `git-enhancements.sh` - Enhanced git workflows for data science
  - `virtualenv.sh` - Python virtual environment management
  - `tmux_smart_start.sh` - Intelligent tmux session management
  - `duckdb.sh` - DuckDB database integration with project-aware data loading
  - `project-detection.sh` - Automatic project type detection and configuration

### Tmux Configuration
- **Config file**: `tmux/tmux.conf` - Comprehensive tmux setup with custom keybindings
- **Layout system**: `tmux/layouts/` - Automated workspace layouts for different project types
- **Session management**: Advanced session saving/restoring with tmux-resurrect integration
- **Key prefix**: `Ctrl-a` (not default Ctrl-b)

### Development Tools Integration
- **Terminal**: foot terminal with custom configuration
- **Editor**: Vim with modular configuration in `vim/config/`
- **Python REPL**: ptpython with custom configuration
- **Git**: Enhanced with forgit integration and data science workflows
- **Database**: DuckDB with project-aware data discovery and loading

## Common Commands and Workflows

### Shell and Navigation
- `z <directory>` - Smart directory jumping (zoxide)
- `status` or `loading_status` - Show dotfiles loading status
- `ll`, `la`, `treez` - Enhanced file listing with eza

### Tmux Session Management
- `tmux-new` - Interactive session creation with layout detection
- `tmux-smart` - Show project info and session recommendations
- `Ctrl-a S` - Session management menu (save/restore)
- `Ctrl-a W` - Workspace layout menu for different project types

### Development Workflows
- `va` - Activate virtual environment for current project
- `vp` - Activate project-specific virtual environment
- `gstds` - Git status with data science file awareness
- `duck` - Start DuckDB with project data auto-loaded
- `fdata-profile file.csv` - Interactive data profiling tool selection

### Data Science Tools
- `duck setup` - Auto-discover and load CSV/JSON files in ./data/
- `duck-peek table_name` - Preview table data with syntax highlighting
- `profile file.csv` - Select and run data profiling reports
- `jupyter-smart` - Smart Jupyter notebook management

## Project Detection System

The repository includes sophisticated project type detection that automatically:
- Detects project types (Python, Jupyter, SQL, ETL, ML, etc.)
- Suggests appropriate tmux layouts
- Configures environment variables and paths
- Caches configuration in `.projectrc` for consistency

Project types detected:
- `python` - Python projects with requirements/pyproject.toml
- `jupyter` - Projects with .ipynb files
- `data` - Projects with data files (CSV, JSON, Parquet)
- `sql` - Projects with SQL files or database configs
- `etl` - ETL/pipeline projects (Airflow, dbt, etc.)
- `ml_training` - ML projects with training scripts
- `docker` - Docker-based projects
- `git` - General git repositories

## Environment Variables

- `DOTFILES` - Path to dotfiles directory (auto-detected)
- `XDG_CONFIG_HOME` - XDG config directory (defaults to ~/.config)
- `PROFILING_DIR` - Data profiling tools directory
- `VIRTUAL_ENV` - Active Python virtual environment

## Configuration Files

### Global Configurations
- `~/.duckdbrc` - DuckDB global settings and macros
- `~/.config/profiling/config.yml` - Data profiling tool configuration
- `~/.config/zsh/` - Zsh configuration directory

### Project-Level Configurations
- `.projectrc` - Cached project configuration and layout preferences
- `.duckdb_setup.sql` - Auto-generated DuckDB data loading script
- `.envrc` - Directory-specific environment (if using direnv)

## Troubleshooting

### Shell Issues
- Run `status` to check which modules loaded successfully
- Check `$DOTFILES` environment variable is set correctly
- Verify file permissions on productivity scripts

### Tmux Issues
- Check layout scripts are executable: `chmod +x tmux/layouts/*.sh`
- Verify tmux plugins are installed: `Prefix + I`
- Use `tmux-debug-integration` for detailed diagnostics

### Database Issues
- Run `duck config` to check DuckDB configuration status
- Use `duck setup --force` to regenerate data loading scripts
- Check `./data/` directory exists and contains supported file formats

This configuration prioritizes productivity, automation, and consistency across development environments while maintaining modularity and extensibility.