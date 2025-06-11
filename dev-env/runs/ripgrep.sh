#!/bin/bash
# ripgrep installation script with version control
RG_VERSION=${1:-"14.1.1"}  # Use argument or default to 14.1.1

echo "Installing ripgrep version $RG_VERSION"
echo "--------------------------------------"

# Create installation directory
INSTALL_DIR="$HOME/install"
mkdir -p "$INSTALL_DIR"

# Clone repository and checkout version
cd "$INSTALL_DIR"
if [ -d "ripgrep" ]; then
    echo "Updating existing ripgrep repository..."
    cd ripgrep
    git fetch --all
else
    echo "Cloning ripgrep repository..."
    git clone https://github.com/BurntSushi/ripgrep.git
    cd ripgrep
fi

# Checkout specific version
git checkout "$RG_VERSION" 2>/dev/null || {
    echo "Error: Version $RG_VERSION not found. Available versions:"
    git tag -l | sort -V | tail -n 10
    exit 1
}

# Build and install
echo "Building ripgrep $RG_VERSION (this may take several minutes)..."
cargo build --release

# Install to cargo bin
echo "Installing binary..."
mkdir -p "$HOME/.cargo/bin"
cp -f "target/release/rg" "$HOME/.cargo/bin/"

# Verify installation
if rg --version | grep -q "$RG_VERSION"; then
    echo "ripgrep $RG_VERSION installed successfully"
else
    echo "Installation verification failed!"
    echo "Try manually: source ~/.zshrc && rg --version"
    exit 1
fi
