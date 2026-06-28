#!/usr/bin/env bash
# TorBox signup via Tor + FlareSolverr (bypasses Cloudflare)
set -euo pipefail

ANON_KEY=$(cat /home/runner/workspace/.supabase_anon_key)
EMAIL_PREFIX="${1:-bavmin}"
PASSWORD="${2:-Satyana@1234}"
EMAIL="${EMAIL_PREFIX}+${RANDOM}@proton.me"

echo "→ Solving Cloudflare via FlareSolverr + Tor ..."

# Step 1: FlareSolverr — get cf_clearance cookie
cat > /tmp/fs_get.json << JSONEOF
{
  "cmd": "request.get",
  "url": "https://db.torbox.app/auth/v1/signup",
  "maxTimeout": 120000,
  "proxy": {"url": "socks5://127.0.0.1:9050"}
}
JSONEOF

FS_RESP=$(curl -s -X POST http://127.0.0.1:8191/v1 \
  -H 'Content-Type: application/json' \
  -d @/tmp/fs_get.json)

# Extract cookies and user-agent
COOKIE_STR=$(echo "$FS_RESP" | python3 -c "
import sys,json
r=json.load(sys.stdin)
cs=r.get('solution',{}).get('cookies',[])
print('; '.join(f\"{c['name']}={c['value']}\" for c in cs))
")
USER_AGENT=$(echo "$FS_RESP" | python3 -c "
import sys,json
r=json.load(sys.stdin)
print(r.get('solution',{}).get('userAgent',''))
")

if [ -z "$COOKIE_STR" ]; then
  echo "✗ FlareSolverr returned no cookies"
  exit 1
fi

echo "✓ Got cf_clearance cookie"

# Step 2: Save values to files (avoids shell quoting hell)
echo -n "$ANON_KEY"  > /tmp/tb_anon_key.txt
echo -n "$EMAIL"     > /tmp/tb_email.txt
echo -n "$PASSWORD"  > /tmp/tb_password.txt
echo -n "$COOKIE_STR" > /tmp/tb_cf_cookies.txt
echo -n "$USER_AGENT" > /tmp/tb_cf_ua.txt

# Step 3: Signup via Python + PySocks through Tor
cat > /tmp/tb_tor_signup.py << 'PYEOF'
import urllib.request, json, socks, socket

socks.set_default_proxy(socks.SOCKS5, '127.0.0.1', 9050)
socket.socket = socks.socksocket

with open('/tmp/tb_anon_key.txt') as f:   anon_key   = f.read().strip()
with open('/tmp/tb_email.txt') as f:      email      = f.read().strip()
with open('/tmp/tb_password.txt') as f:   password   = f.read().strip()
with open('/tmp/tb_cf_cookies.txt') as f: cookie_str = f.read().strip()
with open('/tmp/tb_cf_ua.txt') as f:      user_agent = f.read().strip()

url = 'https://db.torbox.app/auth/v1/signup'
data = json.dumps({"email": email, "password": password}).encode()
req = urllib.request.Request(url, data=data, method='POST')
req.add_header('Content-Type', 'application/json')
req.add_header('apikey', anon_key)
req.add_header('Cookie', cookie_str)
req.add_header('User-Agent', user_agent)

try:
    resp = urllib.request.urlopen(req, timeout=30)
    print(resp.read().decode())
except urllib.error.HTTPError as e:
    print(e.read().decode())
PYEOF

RESP=$(python3 /tmp/tb_tor_signup.py)

# Step 4: Parse and output
ID=$(echo "$RESP" | python3 -c "
import sys,json
r=json.load(sys.stdin)
print(r.get('id','?'))
" 2>/dev/null || echo "?")

CONF=$(echo "$RESP" | python3 -c "
import sys,json
r=json.load(sys.stdin)
print(r.get('confirmation_sent_at','N/A'))
" 2>/dev/null || echo "N/A")

echo "✓ Signed up via Tor"
echo "  Email:    $EMAIL"
echo "  Password: $PASSWORD"
echo "  User ID:  $ID"
echo "  Confirm:  $CONF"

# Step 5: Append credentials
CRED="/home/runner/workspace/torbox_credentials.txt"
echo "email=$EMAIL"       >> "$CRED"
echo "password=$PASSWORD" >> "$CRED"
echo "user_id=$ID"        >> "$CRED"
echo "magic_link=NOT_VERIFIED" >> "$CRED"
echo "" >> "$CRED"

echo "✓ Appended to $CRED"

# Cleanup
rm -f /tmp/fs_get.json /tmp/tb_anon_key.txt /tmp/tb_email.txt \
      /tmp/tb_password.txt /tmp/tb_cf_cookies.txt /tmp/tb_cf_ua.txt \
      /tmp/tb_tor_signup.py
