#!/usr/bin/env bash
# start-tor-flare.sh — Start Tor + FlareSolverr for Cloudflare bypass
set -euo pipefail

TOR_BIN="/nix/store/wnfpm8rjbgq5nhqj4dr85jnky86xvxcx-tor-0.4.8.16/bin/tor"
FS_IMAGE="ghcr.io/flaresolverr/flaresolverr:latest"
FS_CONTAINER="flaresolverr"
TOR_PORT=9050
TOR_CTRL_PORT=9051
FS_PORT=8191

echo "========================================"
echo " Starting Tor + FlareSolverr"
echo "========================================"

# ═══════════════════════════════════════════
# Step 1: Start Tor
# ═══════════════════════════════════════════
if pgrep -x tor &>/dev/null; then
  echo "✓ Tor already running (PID $(pgrep -x tor))"
else
  echo "→ Starting Tor ..."
  
  # Create temp torrc if none exists
  TORRC=$(mktemp /tmp/torrc.XXXXXX)
  cat > "$TORRC" << EOF
SocksPort $TOR_PORT
ControlPort $TOR_CTRL_PORT
DataDirectory /tmp/tor-data
Log notice stderr
EOF
  mkdir -p /tmp/tor-data

  # Start Tor in background
  $TOR_BIN -f "$TORRC" &>/tmp/tor.log &
  TOR_PID=$!
  
  # Wait for bootstrap
  echo "  Waiting for bootstrap ..."
  for i in $(seq 1 120); do
    if grep -q "Bootstrapped 100%" /tmp/tor.log 2>/dev/null; then
      echo "✓ Tor bootstrapped (PID $TOR_PID)"
      break
    fi
    if ! kill -0 $TOR_PID 2>/dev/null; then
      echo "✗ Tor died during bootstrap"
      cat /tmp/tor.log
      exit 1
    fi
    sleep 2
  done
  
  # Final check
  if ! grep -q "Bootstrapped 100%" /tmp/tor.log 2>/dev/null; then
    echo "⚠ Tor not fully bootstrapped after 240s, proceeding anyway"
  fi
fi

# Verify Tor SOCKS5
TOR_CHECK=$(curl -s --socks5-hostname 127.0.0.1:$TOR_PORT https://check.torproject.org/api/ip 2>/dev/null || echo "failed")
if echo "$TOR_CHECK" | grep -q '"IsTor":true'; then
  TOR_IP=$(echo "$TOR_CHECK" | python3 -c "import sys,json;print(json.load(sys.stdin)['IP'])" 2>/dev/null || echo "?")
  echo "✓ Tor exit IP: $TOR_IP"
else
  echo "⚠ Tor SOCKS5 not responding on port $TOR_PORT"
fi

# ═══════════════════════════════════════════
# Step 2: Start FlareSolverr (Docker)
# ═══════════════════════════════════════════
FS_RUNNING=$(docker inspect -f '{{.State.Running}}' $FS_CONTAINER 2>/dev/null || echo "false")

if [ "$FS_RUNNING" = "true" ]; then
  echo "✓ FlareSolverr already running (container $FS_CONTAINER)"
else
  # Remove stale container if exists
  docker rm -f $FS_CONTAINER &>/dev/null || true
  
  echo "→ Starting FlareSolverr ..."
  docker run -d \
    --name $FS_CONTAINER \
    --network host \
    --restart unless-stopped \
    -e PROXY_URL=socks5://127.0.0.1:$TOR_PORT \
    -e LOG_LEVEL=info \
    $FS_IMAGE
  
  # Wait for FlareSolverr to be ready
  echo "  Waiting for FlareSolverr ..."
  for i in $(seq 1 30); do
    if curl -s -m 2 http://127.0.0.1:$FS_PORT/v1 &>/dev/null; then
      echo "✓ FlareSolverr ready on port $FS_PORT"
      break
    fi
    sleep 2
  done
  
  # Final check
  if ! curl -s -m 2 http://127.0.0.1:$FS_PORT/v1 &>/dev/null; then
    echo "✗ FlareSolverr not responding on port $FS_PORT"
    docker logs $FS_CONTAINER --tail 20
    exit 1
  fi
fi

# ═══════════════════════════════════════════
# Summary
# ═══════════════════════════════════════════
echo ""
echo "========================================"
echo " Ready!"
echo "========================================"
echo "  Tor SOCKS5:  127.0.0.1:$TOR_PORT"
echo "  Tor Control: 127.0.0.1:$TOR_CTRL_PORT"
echo "  FlareSolverr: http://127.0.0.1:$FS_PORT/v1"
echo ""
echo "  Usage:"
echo "    curl --socks5-hostname 127.0.0.1:$TOR_PORT https://example.com"
echo "    curl -X POST http://127.0.0.1:$FS_PORT/v1 -H 'Content-Type: application/json' -d '{\"cmd\":\"request.get\",\"url\":\"https://example.com\",\"maxTimeout\":120000}'"
