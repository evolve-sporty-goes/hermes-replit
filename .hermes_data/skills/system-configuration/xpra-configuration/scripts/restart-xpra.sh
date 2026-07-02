#!/usr/bin/env bash
# Restart xpra with patched HTML5 client
# Run this after any changes to index.html or connect.html

set -euo pipefail

XPRA_BIN="/nix/store/jbi45gv4q60f4ynsqwjgda0c8m7vyimd-xpra-6.3/bin/xpra"
PATCHED_WWW="/home/runner/workspace/xpra-www"
DISPLAY_NUM=100
PORT=14500

echo "Stopping existing xpra on :$DISPLAY_NUM..."
export PATH="/nix/store/jbi45gv4q60f4ynsqwjgda0c8m7vyimd-xpra-6.3/bin:$PATH"
$XPRA_BIN stop :$DISPLAY_NUM 2>/dev/null || true
sleep 1

echo "Starting xpra with patched HTML5 client..."
$XPRA_BIN start :$DISPLAY_NUM \
    --bind-tcp=0.0.0.0:$PORT \
    --html=$PATCHED_WWW \
    --daemon=yes \
    --exit-with-children=no \
    --start-child=xterm \
    2>&1 | grep -v "Warning: XDG_RUNTIME_DIR"

sleep 2

echo "Verifying..."
$XPRA_BIN info :$DISPLAY_NUM 2>/dev/null | grep -E "html|www|xterm|child.0" | head -10

echo "Done. Web interface: http://localhost:$PORT (or Replit forwarded port $PORT)"