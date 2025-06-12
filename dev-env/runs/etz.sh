#!/bin/bash

# Script to install eza from source
set -e # Exit on any error

echo "Installing eza from source..."

# Create the install directory if it doesn't exist
INSTALL_DIR="$HOME/install"
mkdir -p "$INSTALL_DIR"

# Navigate to the install directory
cd "$INSTALL_DIR"

# Remove existing eza directory if it exists
if [ -d "eza" ]; then
  echo "Removing existing eza directory..."
  rm -rf eza
fi

# Clone the eza repository
echo "Cloning eza repository..."
git clone https://github.com/eza-community/eza.git

# Navigate to the eza directory
cd eza

# Install eza using cargo with optimizations
echo "Building and installing eza with optimizations..."
echo "This may take longer but will produce a faster binary..."

# Set optimization flags
export RUSTFLAGS="-C target-cpu=native -C strip=symbols"

cargo install --path .

# Install Dracula theme
echo "Installing Dracula theme for eza..."

# Go back to the install directory to clone themes
cd "$INSTALL_DIR"

# Remove existing eza-themes directory if it exists
if [ -d "eza-themes" ]; then
  echo "Removing existing eza-themes directory..."
  rm -rf eza-themes
fi

# Clone the eza themes repository
echo "Cloning eza-themes repository..."
git clone https://github.com/eza-community/eza-themes.git

# Create eza config directory
mkdir -p ~/.config/eza

# Create symlink to Dracula theme
echo "Setting up Dracula theme..."
ln -sf "$INSTALL_DIR/eza-themes/themes/dracula.yml" ~/.config/eza/theme.yml

echo "✅ eza has been successfully installed with Dracula theme!"
echo "The binary should now be available at: ~/.cargo/bin/eza"
echo "Theme configuration: ~/.config/eza/theme.yml -> $INSTALL_DIR/eza-themes/themes/dracula.yml"
echo ""
echo "Make sure ~/.cargo/bin is in your PATH by adding this to your ~/.bashrc or ~/.zshrc:"
echo 'export PATH="$HOME/.cargo/bin:$PATH"'
echo ""
echo "You can test the installation by running: eza --version"
echo "To see the Dracula theme in action, try: eza --icons --long"
