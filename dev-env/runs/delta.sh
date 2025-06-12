#!/bin/bash

# Script to install delta with cargo optimization
# Requires: rust and cargo already installed

set -e  # Exit on any error

echo "🚀 Installing delta with cargo optimization..."

# Create the install directory if it doesn't exist
INSTALL_DIR="$HOME/install"
mkdir -p "$INSTALL_DIR"

# Set CARGO_TARGET_DIR to use our custom install directory for build artifacts
export CARGO_TARGET_DIR="$INSTALL_DIR/target"

# Advanced cargo optimization settings
export RUSTFLAGS="-C target-cpu=native -C opt-level=3 -C codegen-units=1 -C panic=abort"
export CARGO_PROFILE_RELEASE_LTO=true
export CARGO_PROFILE_RELEASE_CODEGEN_UNITS=1
export CARGO_PROFILE_RELEASE_PANIC="abort"

# Install delta with optimizations
# --locked: Use exact versions from Cargo.lock
# --release: Build with optimizations
# --jobs: Use all available CPU cores for parallel compilation
CARGO_INSTALL_FLAGS="--locked --jobs $(nproc)"

echo "📦 Installing git-delta with advanced optimizations:"
echo "   🎯 Target CPU: native (optimized for your specific CPU)"
echo "   🔗 LTO: fat (Link Time Optimization across all crates)"
echo "   📦 Codegen units: 1 (better optimization, slower compile)"
echo "   🚫 Panic strategy: abort (smaller binary, faster execution)"
echo "   ⚡ Optimization level: 3 (maximum)"
echo "🏗️  Build artifacts will be stored in: $CARGO_TARGET_DIR"

cargo install git-delta $CARGO_INSTALL_FLAGS

echo "✅ Delta installation completed!"
echo "📍 Executable installed to: $(which delta 2>/dev/null || echo 'Not found in PATH - check ~/.cargo/bin')"
echo "🧹 You can clean up build artifacts with: rm -rf $CARGO_TARGET_DIR"

# Verify installation
if command -v delta >/dev/null 2>&1; then
    echo "🎉 Delta is ready to use!"
    echo "📋 Version: $(delta --version)"
else
    echo "⚠️  Delta not found in PATH. Make sure ~/.cargo/bin is in your PATH:"
    echo "    export PATH=\"\$HOME/.cargo/bin:\$PATH\""
fi
