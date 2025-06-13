#!/bin/bash
set -e

echo "=== Docker Desktop Installation Script for Ubuntu ==="

# Set download path
INSTALL_DIR="$HOME/install/docker"
DEB_FILE="$INSTALL_DIR/docker-desktop-latest.deb"

# Create download directory if it doesn't exist
mkdir -p "$INSTALL_DIR"

# 1. Update APT index
echo "[1/6] Updating APT..."
sudo apt-get update

# 2. Install dependencies and gnome-terminal (required for non-GNOME environments)
echo "[2/6] Installing dependencies..."
sudo apt-get install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    apt-transport-https \
    software-properties-common \
    gnome-terminal

# 3. Add Docker's GPG key (REQUIRED for docker-ce-cli dependency)
echo "[3/6] Adding Docker's GPG key..."
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
    sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# 4. Set up Docker APT repository (REQUIRED for docker-ce-cli dependency)
echo "[4/6] Setting up Docker APT repository..."
echo \
  "deb [arch=$(dpkg --print-architecture) \
  signed-by=/etc/apt/keyrings/docker.gpg] \
  https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update

# 5. Download the latest Docker Desktop .deb
echo "[5/6] Downloading Docker Desktop .deb to $DEB_FILE..."
curl -L -o "$DEB_FILE" \
  "https://desktop.docker.com/linux/main/amd64/docker-desktop-amd64.deb"

# 6. Install Docker Desktop (now docker-ce-cli will be available)
echo "[6/6] Installing Docker Desktop..."
cd "$INSTALL_DIR"
sudo apt-get install -y ./docker-desktop-latest.deb

echo "✅ Docker Desktop installation complete!"
echo "📦 .deb saved at: $DEB_FILE"
echo ""
echo "🔧 Post-installation steps:"
echo "1. Log out and back in (or reboot) for full integration"
echo "2. Start Docker Desktop: systemctl --user start docker-desktop"
echo "3. Enable auto-start: systemctl --user enable docker-desktop"
echo "4. Launch from Applications menu or run the systemctl command above"
echo ""
echo "✅ Verify installation by running:"
echo "   docker --version"
echo "   docker compose version"
