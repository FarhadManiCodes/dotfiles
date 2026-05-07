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
- **Editor**: Vim with modular configuration in `vim/config/` (see Vim Configuration section below)
- **Python REPL**: ptpython with custom configuration
- **Git**: Enhanced with forgit integration and data science workflows
- **Database**: DuckDB with project-aware data discovery and loading

### Vim Configuration Architecture (Simplified)
**Purpose**: Lightweight editing for markdown, config files, bash, and simple tasks. Use Neovim for complex development.

- **Main orchestrator**: `vim/vimrc` - Sources config modules in dependency order, auto-reloads on save
- **Plugin manager**: vim-plug with **12 lightweight plugins** (down from 24)
- **Modular structure**: `vim/config/` directory with focused, single-purpose configuration files
- **Fallback system**: `vim/config/minimal.vim` automatically loaded for vi/view programs
- **Loading order**:
  1. `basic.vim` - Core settings, theme system, terminal setup
  2. `plugins.vim` - Plugin declarations (12 plugins)
  3. `plugins_config.vim` - Lightweight plugin configurations
  4. `autocmds.vim` - Filetype detection and autocommands
  5. `mappings.vim` - Essential keybindings
  6. Language configs: `python.vim`, `yaml.vim`, `json.vim`

**Plugins** (12 total):
- **Editing**: auto-pairs, vim-surround, tcomment, vim-repeat, vim-unimpaired
- **UI**: lightline, onedark theme, PaperColor theme
- **Writing**: vim-markdown, Goyo, Limelight
- **Integration**: vim-tmux-navigator, rainbow_csv, vim-envx

**Key features**:
- Multi-theme toggle system (onedark ↔ PaperColor light ↔ PaperColor dark)
- Virtual environment detection in statusline (virtualenv, conda, pipenv)
- Writing mode (Goyo + Limelight) for distraction-free markdown editing
- CSV column highlighting with rainbow_csv
- Emacs-style insert mode bindings (Ctrl-A/E/F/B/D for navigation)

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

### Vim Commands and Keybindings
**Leader key**: `\` (backslash)

**Editing & Utilities**:
- `<leader>sr` - Search/replace word under cursor
- `<leader>=` - Auto-format entire file
- `<leader>vr` - Reload vimrc
- `<leader>tt` - Toggle theme (cycles through onedark → PaperColor light → PaperColor dark)
- `<leader><space>` - Clear search highlighting
- `Ctrl-Left/Right/Up/Down` - Resize windows by 5 units

**Writing Mode** (Markdown):
- `<leader>gy` - Toggle Goyo (distraction-free writing)
- `<leader>ll` - Toggle Limelight (paragraph focus)

**Terminal**:
- `<leader>t` - Open terminal in split (1/3 window height)

**Emacs-style Insert Mode**:
- `Ctrl-A` - Move to line start
- `Ctrl-E` - Move to line end
- `Ctrl-F` - Move forward one character
- `Ctrl-B` - Move backward one character
- `Ctrl-D` - Delete forward

**Plugin-provided shortcuts**:
- `cs"'` - Change surrounding quotes (vim-surround)
- `ds"` - Delete surrounding quotes (vim-surround)
- `ysiw"` - Add quotes around word (vim-surround)
- `gcc` - Toggle comment line (tcomment)
- `[b` / `]b` - Previous/next buffer (vim-unimpaired)
- `[q` / `]q` - Previous/next quickfix (vim-unimpaired)

**Note**: Arrow keys are disabled in all modes to enforce hjkl navigation.

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

## Vim Configuration Details

### Modifying Vim Configuration
When editing Vim configs, changes auto-reload on save. To modify specific functionality:

**Add plugins**: Edit `vim/config/plugins.vim`, then run `:PlugInstall` in Vim
**Change keybindings**: Edit `vim/config/mappings.vim`
**Add language support**: Create new `vim/config/LANGUAGE.vim` and source it in `vim/vimrc`
**Modify theme/appearance**: Edit `vim/config/basic.vim` (contains `ToggleTheme()` function)
**Add filetype detection**: Edit `vim/config/autocmds.vim`
**Configure plugins**: Edit `vim/config/plugins_config.vim`

### Plugin Configuration
Located in `vim/config/plugins_config.vim`:

**Lightline** (statusline):
- Shows virtual environment (virtualenv, conda, pipenv)
- Displays mode, filename, line info
- Syncs colorscheme with theme toggle

**Markdown** (vim-markdown):
- Folding enabled
- Math syntax support
- Auto-fit table of contents
- 2-space list item indentation

**Writing Mode** (Goyo + Limelight):
- Goyo: 88-character width, no line numbers
- Limelight: 0.7 coefficient, 1 paragraph span
- Auto-synced: Limelight activates when Goyo starts

**Auto-pairs**:
- Uses default plugin settings (simple bracket/quote pairing)
- Works across all file types without custom rules

### Plugin Categories (12 total)
**Editing** (5): auto-pairs, vim-surround, tcomment, vim-repeat, vim-unimpaired
**UI** (3): lightline, papercolor-theme, onedark.vim
**Writing** (3): vim-markdown, goyo, limelight
**Integration** (3): vim-tmux-navigator, rainbow_csv, vim-envx

## Troubleshooting

### Shell Issues
- Run `status` to check which modules loaded successfully
- Check `$DOTFILES` environment variable is set correctly
- Verify file permissions on productivity scripts

### Tmux Issues
- Check layout scripts are executable: `chmod +x tmux/layouts/*.sh`
- Verify tmux plugins are installed: `Prefix + I`
- Use `tmux-debug-integration` for detailed diagnostics

### Vim Issues
- **Plugins not working**: Run `vim +PlugInstall +qall` to install plugins
- **Config not loading**: Verify `$DOTFILES` environment variable is set (used in `vim/vimrc`)
- **Minimal config loading**: Check if running as `vi` or `view` (automatically uses `minimal.vim`)
- **Auto-reload not working**: Ensure config files are in `$DOTFILES/vim/config/` directory
- **Theme issues**: Use `<leader>tt` to cycle themes, check lightline and theme plugins are installed
- **onedark not found**: Run `:PlugInstall` to install joshdick/onedark.vim
- **Writing mode not working**: Ensure Goyo and Limelight plugins are installed

### Database Issues
- Run `duck config` to check DuckDB configuration status
- Use `duck setup --force` to regenerate data loading scripts
- Check `./data/` directory exists and contains supported file formats

## Architecture Philosophy

This configuration prioritizes:
- **Modularity**: Each config file has a single, focused purpose
- **Simplicity**: Vim for lightweight editing (markdown, configs, bash), Neovim for complex development
- **Productivity**: Essential editing tools without heavyweight development plugins
- **Data Science**: Python, CSV, YAML/JSON config file support in shell/tmux workflows
- **Automation**: Auto-reload, project detection, virtual environment awareness
- **Consistency**: XDG compliance, unified theme system, dotfiles-centric design
- **Extensibility**: Easy to add languages, plugins, or workflows without touching existing code
- **Performance**: Fast startup, minimal plugins, optimized for simple editing tasks