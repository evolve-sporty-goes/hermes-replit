#!/bin/bash
# Install xpra on Replit/NixOS
# Run this script to set up xpra with HTML5 client

set -euo pipefail

echo "Installing xpra via nix..."
nix-env -iA nixpkgs.xpra

# Find the installed binary
XPRA_PATH=$(find /nix/store -maxdepth 3 -name "xpra" -type f 2>/dev/null | head -1)
if [[ -z "$XPRA_PATH" ]]; then
    echo "ERROR: xpra binary not found in nix store"
    exit 1
fi

XPRA_BIN_DIR=$(dirname "$XPRA_PATH")
echo "Found xpra at: $XPRA_BIN_DIR"

# Add to PATH
export PATH="$XPRA_BIN_DIR:$PATH"
echo "export PATH=\"$XPRA_BIN_DIR:\$PATH\"" >> ~/.bashrc

# Verify
xpra --version

echo ""
echo "Setup complete. Add to PATH:"
echo "  export PATH=\"$XPRA_BIN_DIR:\$PATH\""