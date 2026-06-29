#!/usr/bin/env bash
# Cloudflare AI custom endpoint setup with credential pool
# Picks a random account from N credential pairs
# Usage: bash scripts/setup_cloudflare.sh
set -euo pipefail

ACCOUNT_IDS=(
  "your_account_id_1"
  "your_account_id_2"
  "your_account_id_3"
  "your_account_id_4"
  "your_account_id_5"
)
API_KEYS=(
  "your_api_key_1"
  "your_api_key_2"
  "your_api_key_3"
  "your_api_key_4"
  "your_api_key_5"
)

IDX=$(( RANDOM % ${#ACCOUNT_IDS[@]} ))
ACCOUNT_ID="${ACCOUNT_IDS[$IDX]}"
API_KEY="${API_KEYS[$IDX]}"
BASE_URL="https://api.cloudflare.com/client/v4/accounts/${ACCOUNT_ID}/ai/v1"

echo "[$IDX] Using account: ${ACCOUNT_ID:0:8}..."

hermes config set model.provider custom
hermes config set model.base_url "${BASE_URL}"
hermes config set model.api_key "${API_KEY}"
hermes config set model.api_compat openai
hermes config set model.default "@cf/moonshotai/kimi-k2.7-code"
hermes config set model.display_name "cloudflare"

echo "Done. Hermes configured:"
echo "  Provider:     custom"
echo "  Base URL:     ${BASE_URL}"
echo "  API mode:     openai (Chat Completions)"
echo "  Model:        @cf/moonshotai/kimi-k2.7-code"
echo "  Display name: cloudflare"
