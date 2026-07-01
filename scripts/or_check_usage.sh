#!/usr/bin/env bash
set -euo pipefail
CREDS="/home/runner/workspace/credentials/openrouter_credentials.txt"
API_KEY=$(awk -F= '/^API_KEY=/{gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2}' "$CREDS" | grep -v NOT_FOUND | shuf -n 1)
if [[ -z "${API_KEY}" ]]; then
  echo "No usable API_KEY found"
  exit 1
fi
echo "USAGE=$(curl -sS -H "Authorization: Bearer ${API_KEY}" https://openrouter.ai/api/v1/auth/key | python3 -c 'import sys,json; print(json.load(sys.stdin)["data"]["usage"])')"
echo "curl -sS -H 'Authorization: Bearer ${API_KEY}' https://openrouter.ai/api/v1/auth/key"
