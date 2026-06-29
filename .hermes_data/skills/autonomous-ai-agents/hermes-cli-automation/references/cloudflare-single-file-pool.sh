#!/usr/bin/env bash
# Non-interactive: configure Hermes custom endpoint (Cloudflare AI)
# Picks random credential pair from credentials/cloudflare.txt
#
# credentials/cloudflare.txt format (alternating lines, no blank lines between pairs):
#   ACCOUNT_ID=<id>
#   API_KEY=***
#   ACCOUNT_ID=<id2>
#   API_KEY=***   ...
#
# Usage: ./setup_cloudflare.sh
set -euo pipefail

CRED="${WORKSPACE:-$HOME/workspace}/credentials/cloudflare.txt"
[[ -f "$CRED" ]] || { echo "No $CRED"; exit 1; }

# Parse pairs: line 1+2, line 3+4, etc.
mapfile -t LINES < <(grep -v '^[[:space:]]*$' "$CRED")
PAIRS=()
for ((i=0; i<${#LINES[@]}; i+=2)); do
  A=$(echo "${LINES[$i]}" | cut -d= -f2)
  K=$(echo "${LINES[$((i+1))]}" | cut -d= -f2)
  PAIRS+=("$A:$K")
done

# Pick random pair
SEL="${PAIRS[$((RANDOM % ${#PAIRS[@]}))]}"
ACCOUNT_ID="${SEL%%:*}"
API_KEY="${SEL##*:}"
BASE_URL="https://api.cloudflare.com/client/v4/accounts/${ACCOUNT_ID}/ai/v1"

echo "Using: ${ACCOUNT_ID:0:8}..."

hermes config set model.provider custom
hermes config set model.base_url "${BASE_URL}"
hermes config set model.api_key "${API_KEY}"
hermes config set model.api_compat openai          # "Chat Completions" mode
hermes config set model.default "@cf/moonshotai/kimi-k2.7-code"
hermes config set model.display_name "cloudflare"

echo "Done. Verify with: hermes config show | grep -A6 '^model'"
