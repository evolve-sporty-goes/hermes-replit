#!/usr/bin/env bash
# Non-interactive: configure Hermes custom endpoint (Cloudflare AI)
# Picks random credential from credentials/ dir
# Usage: ./setup_cloudflare.sh
#
# Add new accounts: create credentials/cloudflare_NNN.txt with:
#   ACCOUNT_ID=<id>
#   API_KEY=***
# No script edits needed — glob auto-discovers new files.

set -euo pipefail

CRED_DIR="$(dirname "$0")/../credentials"
POOL=("$CRED_DIR"/cloudflare_*.txt)
((${#POOL[@]})) || { echo "No credentials found in $CRED_DIR"; exit 1; }

CRED="${POOL[$((RANDOM % ${#POOL[@]}))]}"
ACCOUNT_ID=$(awk -F= '/^ACCOUNT_ID/{print $2}' "$CRED")
API_KEY=*** '/^API_KEY/{print $2}' "$CRED")
BASE_URL="https://api.cloudflare.com/client/v4/accounts/${ACCOUNT_ID}/ai/v1"

echo "[$(basename "$CRED")] Using: ${ACCOUNT_ID:0:8}..."

hermes config set model.provider custom
hermes config set model.base_url "${BASE_URL}"
hermes config set model.api_key "${API_KEY}"
hermes config set model.api_compat openai          # Chat Completions mode
hermes config set model.default "@cf/moonshotai/kimi-k2.7-code"
hermes config set model.display_name "cloudflare"

echo "Done."
