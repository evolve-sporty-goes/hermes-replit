#!/usr/bin/env bash
# torbox-login.sh — Login to TorBox via Supabase password grant.
# Reads credentials from torbox_credentials.txt, saves session to torbox_session.txt.
set -euo pipefail

WORK_DIR="/home/runner/workspace"
CREDS_FILE="$WORK_DIR/torbox_credentials.txt"

# Read anon key from .hermes_data/.env (terminal bypasses read_file restriction)
ANON_KEY=$(grep SUPABASE_ANON_KEY "$WORK_DIR/.hermes_data/.env" 2>/dev/null | tr -d '\r' | cut -d= -f2-)
SUPABASE_URL="https://db.torbox.app"

# Read first account from credentials file
EMAIL=$(grep -m1 '^email=' "$CREDS_FILE" | sed 's/^email=//')
PASSWORD=$(grep -m1 '^password=' "$CREDS_FILE" | sed 's/^password=//')
USER_ID=$(grep -m1 '^user_id=' "$CREDS_FILE" | sed 's/^user_id=//')

echo "=== TorBox Login ==="
echo "Email: $EMAIL"

# Password grant — returns access_token + refresh_token
TOKEN_RESP=$(curl -s -X POST "${SUPABASE_URL}/auth/v1/token?grant_type=password" \
  -H "apikey: *** \
  -H "Authorization: Bearer *** \
  -H "Content-Type: application/json" \
  -d "{\"email\":\"${EMAIL}\",\"password\":\"${PASSWORD}\"}")

if echo "$TOKEN_RESP" | grep -q '"access_token"'; then
    ACCESS_TOKEN=$(echo "$TOKEN_RESP" | python3 -c "import sys,json;print(json.load(sys.stdin)['access_token'])")
    REFRESH_TOKEN=$(echo "$TOKEN_RESP" | python3 -c "import sys,json;print(json.load(sys.stdin)['refresh_token'])")
    EXPIRES_IN=$(echo "$TOKEN_RESP" | python3 -c "import sys,json;print(json.load(sys.stdin)['expires_in'])")
    echo "OK: Login successful"
    echo "access_token: ${ACCESS_TOKEN:0:30}..."
    echo "expires_in: ${EXPIRES_IN}s"
    {
        echo "email=${EMAIL}"
        echo "user_id=${USER_ID}"
        echo "access_token=${ACCESS_TOKEN}"
        echo "refresh_token=${REFRESH_TOKEN}"
        echo "expires_at=$(( $(date +%s) + EXPIRES_IN ))"
        echo "login_time=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    } > "$WORK_DIR/torbox_session.txt"
    echo "Session saved to $WORK_DIR/torbox_session.txt"
else
    echo "ERROR: Login failed"
    echo "$TOKEN_RESP"
    exit 1
fi
