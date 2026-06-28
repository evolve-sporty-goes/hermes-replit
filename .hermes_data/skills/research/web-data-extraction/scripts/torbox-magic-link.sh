#!/usr/bin/env bash
# torbox-magic-link.sh — Request a Supabase OTP/magic link for TorBox login.
# Bypasses Cloudflare Turnstile entirely by going straight to Supabase Auth.
# Usage: bash torbox-magic-link.sh [email]
# After running, check email for the verify URL, then pass it to this script with --verify <url>
set -euo pipefail

WORK_DIR="/home/runner/workspace"
CREDS_FILE="$WORK_DIR/torbox_credentials.txt"
ANON_KEY=$(grep SUPABASE_ANON_KEY "$WORK_DIR/.hermes_data/.env" 2>/dev/null | tr -d '\r' | cut -d= -f2-)
SUPABASE_URL="https://db.torbox.app"

if [ -z "$ANON_KEY" ]; then
    echo "ERROR: SUPABASE_ANON_KEY not found in .env" >&2
    exit 1
fi

# --verify mode: complete login by visiting the magic link URL
if [ "${1:-}" = "--verify" ]; then
    VERIFY_URL="${2:?Usage: --verify <url>}"
    echo "=== Verifying magic link ==="
    # Follow redirects; Supabase returns access_token in the redirect fragment
    RESP=$(curl -s -D - -o /dev/null "$VERIFY_URL" 2>&1)
    # Extract access_token from Location header fragment (#access_token=...&refresh_token=...)
    LOCATION=$(echo "$RESP" | grep -i '^location:' | tail -1 | sed 's/^Location: //i' | tr -d '\r')
    if echo "$LOCATION" | grep -q 'access_token='; then
        ACCESS_TOKEN=$(echo "$LOCATION" | sed 's/.*access_token=//' | sed 's/&.*//')
        REFRESH_TOKEN=$(echo "$LOCATION" | sed 's/.*refresh_token=//' | sed 's/&.*//')
        echo "OK: Magic link verified, login complete"
        echo "access_token: ${ACCESS_TOKEN:0:30}..."
        EMAIL=$(grep -m1 '^email=' "$CREDS_FILE" | sed 's/^email=//')
        USER_ID=$(grep -m1 '^user_id=' "$CREDS_FILE" | sed 's/^user_id=//')
        {
            echo "email=${EMAIL}"
            echo "user_id=${USER_ID}"
            echo "access_token=${ACCESS_TOKEN}"
            echo "refresh_token=${REFRESH_TOKEN}"
            echo "expires_at=$(( $(date +%s) + 3600 ))"
            echo "login_time=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
        } > "$WORK_DIR/torbox_session.txt"
        echo "Session saved to $WORK_DIR/torbox_session.txt"
    else
        echo "WARN: Could not extract token from redirect."
        echo "Location: $LOCATION"
        echo "Try opening the URL in a browser to complete login manually."
    fi
    exit 0
fi

# Request magic link
EMAIL="${1:-$(grep -m1 '^email=' "$CREDS_FILE" | sed 's/^email=//')}"
if [ -z "$EMAIL" ]; then
    echo "ERROR: No email provided and none found in $CREDS_FILE" >&2
    exit 1
fi

echo "=== Requesting TorBox magic link ==="
echo "Email: $EMAIL"

RESP=$(curl -s -X POST "${SUPABASE_URL}/auth/v1/otp" \
  -H "apikey: ${ANON_KEY}" \
  -H "Authorization: Bearer ${ANON_KEY}" \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"${EMAIL}\"}")

# Supabase returns {} on success for OTP
if [ "$RESP" = "{}" ] || echo "$RESP" | grep -q '"id"'; then
    echo "OK: Magic link email sent!"
    echo "Check inbox for: $EMAIL"
    echo ""
    echo "When you get the verify URL, run:"
    echo "  bash $0 --verify '<verify-url>'"
else
    echo "ERROR: Magic link request failed"
    echo "$RESP"
    exit 1
fi
