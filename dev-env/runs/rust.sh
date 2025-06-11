#!/bin/bash
# Install Rust with non-interactive mode
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

# Add cargo to PATH for current session
source "$HOME/.cargo/env"

# Configure current shell
echo 'source "$HOME/.cargo/env"' >>$DOTFILES/zsh/scripts.sh
echo 'export PATH="$HOME/.cargo/bin:$PATH"' >>~/.zshrc
source ~/.zshrc

echo "Rust installed successfully. Restart your shell or run: source ~/.zshrc"
