#!/bin/bash
# direnv-installer.sh - Installs and configures direnv for centralized virtual environments

# Install direnv
sudo apt update
sudo apt install -y direnv

# Configure zsh hook
echo -e '\n# direnv hook' >> ~/.zshrc
echo 'eval "$(direnv hook zsh)"' >> ~/.zshrc

# Create centralized venv directory
mkdir -p ~/.central_venvs

# Create helper function
cat >> ~/.zshrc << 'EOF'

# Centralized venv helper
use_venv() {
  local venv_name=${1:-$(basename $PWD)}
  local venv_path="$HOME/.central_venvs/$venv_name"
  
  if [ ! -d "$venv_path" ]; then
    echo "Creating new venv: $venv_name"
    python -m venv "$venv_path"
  fi
  
  echo "source $venv_path/bin/activate" > .envrc
  direnv allow
}
EOF

# Instructions
echo -e "\n\033[1;32mInstallation complete!\033[0m"
echo "To set up a new project:"
echo "  1. cd your/project/directory"
echo "  2. Run: use_venv custom-name"
echo "  3. Your virtual env will auto-activate when entering the directory"
