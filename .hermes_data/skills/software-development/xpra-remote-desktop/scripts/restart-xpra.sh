#!/bin/bash
# Restart xpra with custom HTML5 client directory
# Usage: ./restart-xpra.sh [display_number]

set -euo pipefail

DISPLAY_NUM="${1:-100}"
XPRA_WWW_DIR="/home/runner/workspace/xpra-www"

# Find xpra binary
XPRA_BIN=$(find /nix/store -maxdepth 3 -name "xpra" -type f 2>/dev/null | head -1)
if [[ -z "$XPRA_BIN" ]]; then
    echo "ERROR: xpra not found"
    exit 1
fi

XPRA_BIN_DIR=$(dirname "$XPRA_BIN")
export PATH="$XPRA_BIN_DIR:$PATH"

echo "Stopping xpra :$DISPLAY_NUM..."
"$XPRA_BIN" stop ":$DISPLAY_NUM" 2>/dev/null || true
sleep 1

echo "Starting xpra :$DISPLAY_NUM with HTML5 from $XPRA_WWW_DIR..."
"$XPRA_BIN" start ":$DISPLAY_NUM" \
  --bind-tcp=0.0.0.0:14500 \
  --html="$XPRA_WWW_DIR" \
  --daemon=yes \
  --exit-with-children=no \
  --start-child=xterm

echo "Waiting for server to start..."
sleep 2

# Verify
"$XPRA_BIN" info ":$DISPLAY_NUM" 2>&1 | grep -E "html|www|xterm"

echo ""
echo "xpra :$DISPLAY_NUM started"
echo "Web interface: http://localhost:14500"