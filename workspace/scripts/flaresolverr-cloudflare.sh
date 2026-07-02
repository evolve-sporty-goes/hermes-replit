#!/usr/bin/env bash
set -euo pipefail
LOG="${1:-workspace/logs/flaresolverr-cloudflare.log}"
mkdir -p "$(dirname "$LOG")"
exec > >(tee -a "$LOG") 2>&1

echo "[$(date -Iseconds)] Starting FlareSolverr..."
docker run -d \
  --name=flaresolverr \
  --restart=unless-stopped \
  -p 8191:8191 \
  -e LOG_LEVEL=info \
  -e LOG_HTML=false \
  -e CAPTCHA_SOLVER=none \
  ghcr.io/flaresolverr/flaresolverr:latest

echo "[$(date -Iseconds)] Waiting for FlareSolverr to be ready..."
for i in {1..30}; do
  if curl -s http://localhost:8191 | grep -q 'FlareSolverr'; then
    echo "[$(date -Iseconds)] FlareSolverr ready."
    exit 0
  fi
  sleep 1
done
echo "[$(date -Iseconds)] FlareSolverr failed to start."
docker logs flaresolverr
exit 1
