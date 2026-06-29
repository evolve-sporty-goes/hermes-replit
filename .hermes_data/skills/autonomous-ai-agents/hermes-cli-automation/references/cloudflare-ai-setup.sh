#!/usr/bin/env bash
# Non-interactive: configure Hermes custom endpoint (Cloudflare AI)
# Usage: ./setup_cloudflare.sh <account_id> <api_key>
# Maps each interactive `hermes model` step:
#   1. Select custom endpoint   → model.provider = custom
#   2. Enter endpoint URL       → model.base_url
#   3. Enter API key            → model.api_key
#   4. Type 2 → Chat Completions → model.api_compat = openai
#   5. Model name               → model.default
#   6. Display name             → model.display_name

set -euo pipefail

ACCOUNT_ID="${1:?Usage: $0 <cloudflare_account_id> <api_key>}"
API_KEY=*** $0 <cloudflare_account_id> <api_key>}"

hermes config set model.provider custom
hermes config set model.base_url "https://api.cloudflare.com/client/v4/accounts/${ACCOUNT_ID}/ai/v1"
hermes config set model.api_key "${API_KEY}"
hermes config set model.api_compat openai
hermes config set model.default "@cf/moonshotai/kimi-k2.7-code"
hermes config set model.display_name "cloudflare"

 Hermes configured:"
echo "  Provider:     custom"
echo "  Base URL:     https://api.cloudflare.com/client/v4/accounts/${ACCOUNT_ID}/ai/v1"
echo "  API mode:     openai (Chat Completions)"
echo "  Model:        @cf/moonshotai/kimi-k2.7-code"
echo "  Display name: cloudflare"
