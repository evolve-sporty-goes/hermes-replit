#!/usr/bin/env bash
# torbox-proxy-rotate.sh — TorBox signup with free proxy rotation
# Fetches SOCKS5/HTTP proxies from ProxyScrape, tries each with Camoufox+geoip
set -eo pipefail

ANON_KEY=$(cat /home/runner/workspace/credentials/.supabase_anon_key)
CRED="/home/runner/workspace/credentials/torbox_credentials.txt"
EMAIL_PREFIX="${1:-bavmin}"
PASSWORD_DEFAULT='Satyana@1234'
PASSWORD="${2:-$PASSWORD_DEFAULT}"
RAND=$(shuf -i 10000-99999 -n 1)
EMAIL="${EMAIL_PREFIX}+${RAND}@proton.me"
MAX_ATTEMPTS=20

echo "========================================"
echo " TorBox Signup with Proxy Rotation"
echo "========================================"
echo "Email: $EMAIL"

# ═══════════════════════════════════════════
# Step 1: Fetch free proxies
# ═══════════════════════════════════════════
echo ""
echo "→ Fetching free SOCKS5 proxies from ProxyScrape ..."

PROXY_LIST=$(curl -s "https://api.proxyscrape.com/v2/?request=displayproxies&protocol=socks5&timeout=10000&country=all" 2>/dev/null)
PROXY_COUNT=$(echo "$PROXY_LIST" | grep -c '.' 2>/dev/null || echo 0)

if [ "$PROXY_COUNT" -lt 1 ]; then
  echo "✗ No proxies fetched, trying HTTP ..."
  PROXY_LIST=$(curl -s "https://api.proxyscrape.com/v2/?request=displayproxies&protocol=http&timeout=10000&country=all" 2>/dev/null)
  PROXY_COUNT=$(echo "$PROXY_LIST" | grep -c '.' 2>/dev/null || echo 0)
fi

if [ "$PROXY_COUNT" -lt 1 ]; then
  echo "✗ No proxies available"
  exit 1
fi

echo "✓ Got $PROXY_COUNT proxies"

# TorBox signup — direct with browser User-Agent (CF blocks Python UA)
# No Tor, no proxy, no FlareSolverr needed. Just set a browser UA header.
cat > /tmp/tb_proxy_signup.py << 'PYEOF'
import urllib.request, json, sys

email = sys.argv[1]
password = sys.argv[2]
anon_key = sys.argv[3]

url = "https://db.torbox.app/auth/v1/signup"
data = json.dumps({"email": email, "password": password}).encode()
req = urllib.request.Request(url, data=data, method="POST")
req.add_header("Content-Type", "application/json")
req.add_header("apikey", anon_key)
# Cloudflare blocks Python-urllib UA but allows browser UAs from clean IPs
req.add_header("User-Agent", "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/138.0.0.0 Safari/537.36")

try:
    resp = urllib.request.urlopen(req, timeout=20)
    body = resp.read().decode()
    d = json.loads(body)
    print(f"SUCCESS|{d.get('id', '?')}")
except urllib.error.HTTPError as e:
    body = e.read().decode()
    if "1010" in body:
        print("BLOCKED|CF 1010 Access Denied")
    elif "Just a moment" in body:
        print("CLOUDFLARE|JS Challenge")
    else:
        print(f"ERROR|HTTP {e.code}: {body[:100]}")
except Exception as e:
    print(f"FAIL|{str(e)[:100]}")
PYEOF

# ═══════════════════════════════════════════
# Step 3: Try signup (direct with browser UA)
# ═══════════════════════════════════════════
echo ""
RESULT=$(python3 /tmp/tb_proxy_signup.py "$EMAIL" "$PASSWORD" "$ANON_KEY" 2>/dev/null)
STATUS=$(echo "$RESULT" | cut -d'|' -f1)
DETAIL=$(echo "$RESULT" | cut -d'|' -f2-)

case "$STATUS" in
  SUCCESS)
    echo "✓ Signed up directly (browser UA)"
    {
      echo "email=$EMAIL"
      echo "password=$PASSWORD"
      echo "user_id=$DETAIL"
      echo "verified=false"
      echo ""
    } >> "$CRED"
    echo "✓ Appended to $CRED"
    rm -f /tmp/tb_proxy_signup.py
    exit 0
    ;;
  CLOUDFLARE|BLOCKED)
    echo "✗ $DETAIL — server IP blocked by Cloudflare"
    echo "  Fallback: try with free proxy from ProxyScrape ..."
    # Fallback to proxy rotation if direct fails
    PROXY_LIST=$(curl -s "https://api.proxyscrape.com/v2/?request=displayproxies&protocol=http&timeout=5000&country=all&ssl=all" 2>/dev/null)
    PROXY_COUNT=$(echo "$PROXY_LIST" | grep -c '.' 2>/dev/null || echo 0)
    if [ "$PROXY_COUNT" -gt 0 ]; then
      echo "  Got $PROXY_COUNT HTTP proxies, trying up to $MAX_ATTEMPTS ..."
      echo "$PROXY_LIST" | head -"$MAX_ATTEMPTS" | while read -r PROXY; do
        [ -z "$PROXY" ] && continue
        HOST=$(echo "$PROXY" | cut -d: -f1)
        PORT=$(echo "$PROXY" | cut -d: -f2)
        export http_proxy="http://$HOST:$PORT"
        export https_proxy="http://$HOST:$PORT"
        RESULT=$(python3 /tmp/tb_proxy_signup.py "$EMAIL" "$PASSWORD" "$ANON_KEY" 2>/dev/null)
        STATUS=$(echo "$RESULT" | cut -d'|' -f1)
        DETAIL=$(echo "$RESULT" | cut -d'|' -f2-)
        unset http_proxy https_proxy
        if [ "$STATUS" = "SUCCESS" ]; then
          echo "✓ Signed up via proxy $HOST:$PORT"
          {
            echo "email=$EMAIL"
            echo "password=$PASSWORD"
            echo "user_id=$DETAIL"
            echo "proxy=$HOST:$PORT"
            echo "verified=false"
            echo ""
          } >> "$CRED"
          echo "✓ Appended to $CRED"
          rm -f /tmp/tb_proxy_signup.py
          exit 0
        fi
        echo "  ✗ $HOST:$PORT — $STATUS"
      done
    fi
    echo "✗ All proxies failed too"
    ;;
  *)
    echo "✗ $STATUS: $DETAIL"
    ;;
esac

rm -f /tmp/tb_proxy_signup.py
exit 1
