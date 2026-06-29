#!/usr/bin/env bash
# Non-interactive: configure Hermes custom endpoint (Cloudflare AI)
# Usage: ./setup_cloudflare.sh <account_id> <api_key> [display_name]

set -euo pipefail

ACCOUNT_ID="${1:?Usage: $0 <cloudflare_account_id> <api_key> [display_name]}"
API_KEY="${2:?Usage: $0 <cloudflare_account_id> <api_key> [display_name]}"

DISPLAY_NAME="${3:-cloudflare}"

BASE_URL="https://api.cloudflare.com/client/v4/accounts/${ACCOUNT_ID}/ai/v1"

# Select custom endpoint provider
hermes config set model.provider custom

# Set the custom endpoint URL
hermes config set model.base_url "${BASE_URL}"

# Set the API key
hermes config set model.api_key "${API_KEY}"

# Select "Chat Completions" API compatibility mode (OpenAI-compatible)
hermes config set model.api_compat openai

# Set the model name
hermes config set model.default "@cf/moonshotai/kimi-k2.7-code"

# Set display name
hermes config set model.display_name "${DISPLAY_NAME}"

echo "Done. Hermes configured:"
echo "  Provider:     custom"
echo "  Base URL:     ${BASE_URL}"
echo "  API mode:     openai (Chat Completions)"
echo "  Model:        @cf/moonshotai/kimi-k2.7-code"
echo "  Display name: ${DISPLAY_NAME}"
