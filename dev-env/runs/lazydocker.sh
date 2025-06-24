#!/bin/bash

# Lazydocker Installer - Installs to ~/.local/bin
set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Target directory
TARGET_DIR="$HOME/.local/bin"
mkdir -p "$TARGET_DIR"

# Optimized Go install
install_via_go() {
    echo -e "${YELLOW}Installing lazydocker using Go (optimized build)...${NC}"
    
    export CGO_ENABLED=0
    GOBIN="$TARGET_DIR" go install -a \
        -trimpath \
        -ldflags="-s -w -extldflags=-static" \
        -tags netgo \
        github.com/jesseduffield/lazydocker@latest
    
    if [[ $? -eq 0 ]]; then
        echo -e "${GREEN}✓ Successfully installed via Go!${NC}"
        return 0
    else
        echo -e "${RED}✗ Go installation failed. Trying manual method...${NC}"
        return 1
    fi
}

# Manual install
install_via_manual() {
    echo -e "${YELLOW}Downloading latest release...${NC}"
    
    LATEST_VERSION=$(curl -s https://api.github.com/repos/jesseduffield/lazydocker/releases/latest | grep 'tag_name' | cut -d '"' -f 4)
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    ARCH=$(uname -m)
    [[ "$ARCH" == "x86_64" ]] && ARCH="amd64"
    
    FILENAME="lazydocker_${LATEST_VERSION#v}_${OS}_${ARCH}.tar.gz"
    URL="https://github.com/jesseduffield/lazydocker/releases/download/$LATEST_VERSION/$FILENAME"
    
    echo -e "Downloading: $URL"
    curl -L -o lazydocker.tar.gz "$URL" || {
        echo -e "${RED}✗ Download failed. Check your connection.${NC}"
        exit 1
    }
    
    tar xvf lazydocker.tar.gz lazydocker
    chmod +x lazydocker
    mv lazydocker "$TARGET_DIR"
    rm lazydocker.tar.gz
    
    echo -e "${GREEN}✓ Manual installation complete!${NC}"
}

# Main installation
if command -v go &> /dev/null; then
    install_via_go || install_via_manual
else
    echo -e "${YELLOW}Go not found. Using manual installation...${NC}"
    install_via_manual
fi

# Verify installation
if [[ -f "$TARGET_DIR/lazydocker" ]]; then
    echo -e "${GREEN}✔ Installation successful!${NC}"
    echo -e "Run with: ${YELLOW}lazydocker${NC}"
else
    echo -e "${RED}❌ Installation failed. Check errors above.${NC}"
    exit 1
fi
