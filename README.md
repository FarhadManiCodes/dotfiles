# Farhad's Dotfiles

Welcome to my personal dotfiles repository! This collection of configuration files and scripts helps set up my development environment on Linux, ensuring a consistent and efficient workflow across different machines.

## Features

This repository configures and enhances the following tools and environments:

- **Vim**: Highly customized Vim setup with plugins for various programming languages (Python, SQL, JSON, YAML) and enhanced editing features like autopairs and basic configurations.
- **Zsh**: A powerful shell environment with custom aliases, completions, and productivity enhancements. It's set up to be XDG-compliant.
- **Tmux**: A terminal multiplexer configuration for efficient session management, including custom layouts for different workflows (analysis, Docker, ETL, Git).
- **ptpython**: Configuration for the interactive Python shell.
- **Foot Terminal**: Configuration for the fast, lightweight Wayland terminal emulator.
- **Git**: Global Git configurations for a streamlined version control experience.
- **Lazygit**: Configuration for the popular terminal UI for Git.
- **DuckDB**: Configuration for the in-process SQL OLAP database.
- **Fonts**: Installation of Nerd Fonts for a visually rich terminal experience.
- **Bash Helper Scripts**: A collection of utility scripts to enhance daily command-line tasks.
- **Development Environment Setup (`dev-env`)**: Scripts to install and configure various development tools, including:
    - `bat` (cat clone with syntax highlighting)
    - `delta` (diff viewer)
    - `direnv` (per-directory environment variables)
    - `docker` (containerization)
    - `etza` (better ls)
    - `fd-find` (fast find alternative)
    - `foot` (terminal emulator)
    - `fzf` (fuzzy finder)
    - `git` (version control)
    - `go` (Go programming language)
    - `lazydocker` (Docker TUI)
    - `lua` (Lua programming language)
    - `pipx` (install and run Python applications in isolated environments)
    - `qsv` (CSV toolkit)
    - `redis` (in-memory data structure store)
    - `ripgrep` (fast grep alternative)
    - `rust` (Rust programming language)
    - `tmux` (terminal multiplexer)
    - `vim` (text editor)
    - `xkbcommon` (keyboard configuration library)
    - `yq` (YAML processor)
    - `zoxide` (fast cd command)

## Installation

To set up these dotfiles on your system, simply run the `install.sh` script:

```bash
bash install.sh
```

The script will create symbolic links for the configuration files in their respective locations and install the necessary fonts and helper scripts.

### Post-Installation Steps

After running `install.sh`, you may need to perform a few additional steps:

1.  **Zsh Themes/Plugins**: The `install.sh` script sets up the Zsh configuration but does not automatically install themes or plugins. You will need to manually install them, for example:
    -   **Powerlevel10k**: `git clone --depth=1 https://github.com/romkatv/powerlevel10k.git ~/.config/zsh/themes/powerlevel10k`
    -   **Fast syntax highlighting**: `git clone https://github.com/zdharma-continuum/fast-syntax-highlighting.git ~/.config/zsh/plugins/fast-syntax-highlighting`

2.  **Restart Terminal**: Restart your terminal or run `source ~/.zshrc` to apply the new Zsh configurations.

3.  **Vim Plugins**: Open Vim and run `:PlugInstall` to install all configured Vim plugins.

4.  **Tmux Plugins**: If you are using `tpm` (Tmux Plugin Manager), press `Prefix + I` (usually `Ctrl+b I`) within a Tmux session to install plugins.

## Usage

Once installed, your environment will be configured with the settings defined in these dotfiles. You can explore the individual configuration files in their respective directories (`vim/`, `zsh/`, `tmux/`, etc.) to understand and further customize your setup.

### Development Environment Scripts

The `dev-env/runs/` directory contains individual scripts for installing and configuring various development tools. You can run these scripts independently to set up specific tools as needed. For example, to install `fzf`:

```bash
bash dev-env/runs/fzf.sh
```

## Structure

```
.dotfiles/
├── .gitignore
├── install.sh
├── README.md
├── bash/               # Helper bash scripts
├── dev-env/            # Development environment setup scripts
│   └── runs/           # Individual tool installation scripts
├── duckdb/             # DuckDB configuration
├── fonts/              # Nerd Fonts
├── foot/               # Foot terminal configuration
├── git/                # Git configuration
├── lazygit/            # Lazygit configuration
├── ptpython/           # ptpython configuration
├── tmux/               # Tmux configuration and layouts
└── vim/                # Vim configuration and plugins
└── zsh/                # Zsh configuration, aliases, and scripts
```

## Contributing

Feel free to fork this repository and adapt it to your needs. If you have suggestions or improvements, please open an issue or submit a pull request.

## License

This project is open-sourced under the MIT License. See the `LICENSE` file for details. (Note: A `LICENSE` file is not included in this repository, consider adding one.)
