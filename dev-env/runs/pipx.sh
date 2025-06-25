#!/bin/bash

# Script to install delta with cargo optimization
# Requires: rust and cargo already installed

set -e  # Exit on any error

echo "Installing pipx"
sudo apt update
sudo apt install pipx
pipx ensurepath
sudo pipx ensurepath --global
