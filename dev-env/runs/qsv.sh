#!/bin/bash

# qsv Installation Script for Ubuntu 25.04
# Optimized for runtime performance by using pre-compiled binaries

set -e # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
  echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
  echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
  echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

# Check if running on Ubuntu
check_ubuntu() {
  if [[ ! -f /etc/os-release ]] || ! grep -q "Ubuntu" /etc/os-release; then
    print_error "This script is designed for Ubuntu. Detected OS may not be compatible."
    exit 1
  fi
  print_status "Ubuntu detected. Proceeding with installation..."
}

# Detect system architecture
detect_architecture() {
  local arch=$(uname -m)
  case $arch in
    x86_64)
      ARCH="x86_64-unknown-linux-musl"
      ;;
    aarch64 | arm64)
      ARCH="aarch64-unknown-linux-musl"
      ;;
    *)
      print_error "Unsupported architecture: $arch"
      print_error "qsv supports x86_64 and aarch64 architectures"
      exit 1
      ;;
  esac
  print_status "Detected architecture: $arch (using $ARCH)"
}

# Check for required dependencies
check_dependencies() {
  local deps=("curl" "unzip")
  local missing_deps=()

  for dep in "${deps[@]}"; do
    if ! command -v "$dep" &>/dev/null; then
      missing_deps+=("$dep")
    fi
  done

  if [[ ${#missing_deps[@]} -gt 0 ]]; then
    print_status "Installing missing dependencies: ${missing_deps[*]}"
    sudo apt update
    sudo apt install -y "${missing_deps[@]}"
  fi
}

# Get the latest release version
get_latest_version() {
  print_status "Fetching latest qsv version..."

  # Try different methods to get the latest version
  LATEST_VERSION=$(curl -s https://api.github.com/repos/dathere/qsv/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' 2>/dev/null)

  # Fallback method if API call fails
  if [[ -z "$LATEST_VERSION" ]]; then
    print_warning "GitHub API call failed, trying alternative method..."
    LATEST_VERSION=$(curl -s https://github.com/dathere/qsv/releases/latest | grep -o 'tag/[^"]*' | head -1 | sed 's/tag\///' 2>/dev/null)
  fi

  # Manual fallback to known recent version
  if [[ -z "$LATEST_VERSION" ]]; then
    print_warning "Could not fetch latest version automatically, using known recent version"
    LATEST_VERSION="5.1.0"
    print_warning "You may want to check https://github.com/dathere/qsv/releases for newer versions"
  fi

  print_status "Using version: $LATEST_VERSION"
}

# Download and install qsv
install_qsv() {
  local temp_dir=$(mktemp -d)
  local download_url="https://github.com/dathere/qsv/releases/download/${LATEST_VERSION}/qsv-${LATEST_VERSION}-${ARCH}.zip"
  local zip_file="${temp_dir}/qsv.zip"

  print_status "Downloading qsv from: $download_url"

  if ! curl -L -o "$zip_file" "$download_url"; then
    print_error "Failed to download qsv"
    rm -rf "$temp_dir"
    exit 1
  fi

  print_status "Extracting qsv..."
  cd "$temp_dir"

  # Check if unzip is available
  if ! command -v unzip &>/dev/null; then
    print_status "Installing unzip..."
    sudo apt update
    sudo apt install -y unzip
  fi

  unzip -q "$zip_file"

  # Find the qsv binary
  local qsv_binary=$(find . -name "qsv" -type f -executable | head -1)

  if [[ -z "$qsv_binary" ]]; then
    print_error "qsv binary not found in the downloaded archive"
    rm -rf "$temp_dir"
    exit 1
  fi

  # Install to /usr/local/bin
  print_status "Installing qsv to /usr/local/bin..."
  sudo cp "$qsv_binary" /usr/local/bin/qsv
  sudo chmod +x /usr/local/bin/qsv

  # Cleanup
  rm -rf "$temp_dir"

  print_success "qsv installed successfully!"
}

# Verify installation
verify_installation() {
  if command -v qsv &>/dev/null; then
    local version=$(qsv --version)
    print_success "Installation verified: $version"
    print_status "qsv is ready to use!"

    # Show some basic usage info
    echo ""
    echo -e "${BLUE}Quick usage examples:${NC}"
    echo "  qsv headers data.csv          # Show column headers"
    echo "  qsv count data.csv            # Count rows"
    echo "  qsv stats data.csv            # Show statistics"
    echo "  qsv select col1,col3 data.csv # Select specific columns"
    echo ""
    echo -e "${BLUE}For more help:${NC} qsv --help"
  else
    print_error "Installation verification failed. qsv command not found."
    print_warning "You may need to restart your terminal or run: source ~/.bashrc"
    exit 1
  fi
}

# Main installation process
main() {
  echo -e "${BLUE}qsv Installation Script for Ubuntu 25.04${NC}"
  echo "=========================================="
  echo ""

  check_ubuntu
  detect_architecture
  check_dependencies
  get_latest_version
  install_qsv
  verify_installation

  echo ""
  print_success "qsv installation completed successfully!"
}

# Run the main function
main "$@"
