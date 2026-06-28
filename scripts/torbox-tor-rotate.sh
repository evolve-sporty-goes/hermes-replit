#!/usr/bin/env bash
# torbox-tor-rotate.sh — TorBox signup with Tor circuit rotation
# Rotates Tor exit IPs by requesting new circuits until Cloudflare lets us through
set -euo pipefail

ANON_KEY=$(cat /home/runner/workspace/credentials/.supabase_anon_key)
CRED="/home/runner/workspace/credentials/torbox_credentials.txt"
EMAIL_PREFIX="${1:-bavmin}"
PASSWORD_DEFAULT='Satyana@1234'
PASSWORD="${2:-$PASSWORD_DEFAULT}"
RAND=$(shuf -i 10000-99999 -n 1)
EMAIL="${EMAIL_PREFIX}+${RAND}@proton.me"
MAX_ATTEMPTS=10
TOR_CTRL=9051

echo "========================================"
echo " TorBox Signup with Tor IP Rotation"
echo "========================================"
echo "Email: $EMAIL"
echo "Max attempts: $MAX_ATTEMPTS"

# ═══════════════════════════════════════════
# Helpers
# ═══════════════════════════════════════════
get_tor_ip() {
  curl -s --socks5-hostname 127.0.0.1:9050 https://check.torproject.org/api/ip 2>/dev/null \
    | python3 -c "import sys,json;print(json.load(sys.stdin).get('IP','?'))" 2>/dev/null || echo "?"
}

new_circuit() {
  # Request new Tor circuit via control port (Python, no nc needed)
  python3 -c "
import socket, time
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.connect(('127.0.0.1', $TOR_CTRL))
s.send(b'AUTHENTICATE \"\"\n')
time.sleep(0.3); s.recv(4096)
s.send(b'SIGNAL NEWNYM\n')
time.sleep(0.3); s.recv(4096)
s.send(b'QUIT\n'); s.close()
" 2>/dev/null
  # Wait for new circuit to establish
  sleep 8
}

# ═══════════════════════════════════════════
# Write Python signup script (avoids quoting hell)
# ═══════════════════════════════════════════
cat > /tmp/tb_rotate_signup.py << 'PYEOF'
import urllib.request, json, socks, socket, sys

socks.set_default_proxy(socks.SOCKS5, '127.0.0.1', 9050)
socket.socket = socks.socksocket

email = sys.argv[1]
password = sys.argv[2]
anon_key = sys.argv[3]

url = 'https://db.torbox.app/auth/v1/signup'
data = json.dumps({"email": email, "password": password}).encode()
req = urllib.request.Request(url, data=data, method='POST')
req.add_header('Content-Type', 'application/json')
req.add_header('apikey', anon_key)

try:
    resp = urllib.request.urlopen(req, timeout=30)
    print("SUCCESS", resp.read().decode(), sep="|")
except urllib.error.HTTPError as e:
    body = e.read().decode()
    if "Just a moment" in body or "cloudflare" in body.lower():
        print("CLOUDFLARE", f"HTTP {e.code}", sep="|")
    else:
        print("ERROR", f"HTTP {e.code}: {body[:200]}", sep="|")
except Exception as e:
    print("ERROR", str(e), sep="|")
PYEOF

# ═══════════════════════════════════════════
# Main rotation loop
# ═══════════════════════════════════════════
for i in $(seq 1 $MAX_ATTEMPTS); do
  IP=$(get_tor_ip)
  echo ""
  echo "→ Attempt $i/$MAX_ATTEMPTS — exit IP: $IP"

  # Try signup
  RESULT=$(python3 /tmp/tb_rotate_signup.py "$EMAIL" "$PASSWORD" "$ANON_KEY" 2>/dev/null)
  STATUS=$(echo "$RESULT" | cut -d'|' -f1)
  BODY=$(echo "$RESULT" | cut -d'|' -f2-)

  case "$STATUS" in
    SUCCESS)
      USER_ID=$(echo "$BODY" | python3 -c "import sys,json;print(json.load(sys.stdin).get('id','?'))" 2>/dev/null || echo "?")
      echo "✓ Signed up via Tor exit $IP"
      echo "  User ID: $USER_ID"
      {
        echo "email=$EMAIL"
        echo "password=$PASSWORD"
        echo "user_id=$USER_ID"
        echo "tor_exit_ip=$IP"
        echo "verified=false"
        echo ""
      } >> "$CRED"
      echo "✓ Appended to $CRED"
      rm -f /tmp/tb_rotate_signup.py
      exit 0
      ;;
    CLOUDFLARE)
      echo "  ✗ Cloudflare blocked this exit IP"
      ;;
    *)
      echo "  ✗ $BODY"
      ;;
  esac

  # Rotate to new circuit
  echo "  Rotating Tor circuit ..."
  new_circuit
  
  # Verify new IP
  NEW_IP=$(get_tor_ip)
  echo "  New exit IP: $NEW_IP"
  
  # Skip if same IP
  if [ "$NEW_IP" = "$IP" ]; then
    echo "  Same IP, waiting longer ..."
    sleep 10
    new_circuit
  fi
done

echo ""
echo "✗ All $MAX_ATTEMPTS Tor exits blocked by Cloudflare"
echo "→ Falling back to FlareSolverr (solves CF JS challenge) ..."

# ═══════════════════════════════════════════
# Fallback: FlareSolverr persistent session
# ═══════════════════════════════════════════
FS_URL="http://127.0.0.1:8191/v1"
SESSION_ID="torbox-rotate-$(date +%s)"

# Check FlareSolverr is running
if ! curl -s -m 3 "$FS_URL" &>/dev/null; then
  echo "✗ FlareSolverr not running. Run: bash scripts/start-tor-flare.sh"
  rm -f /tmp/tb_rotate_signup.py
  exit 1
fi

# Solve CF via FlareSolverr
FS_RESP=$(python3 -c "
import json, subprocess
payload = json.dumps({
    'cmd': 'request.get',
    'url': 'https://db.torbox.app/auth/v1/signup',
    'maxTimeout': 120000,
    'proxy': {'url': 'socks5://127.0.0.1:9050'},
    'session': '$SESSION_ID'
})
r = subprocess.run(['curl','-s','-X','POST','$FS_URL','-H','Content-Type: application/json','-d',payload],
    capture_output=True, text=True, timeout=130)
d = json.loads(r.stdout)
cs = d.get('solution',{}).get('cookies',[])
ua = d.get('solution',{}).get('userAgent','')
print('; '.join(f\"{c['name']}={c['value']}\" for c in cs) + '|||' + ua)
" 2>/dev/null)

COOKIE_STR=$(echo "$FS_RESP" | cut -d'|' -f1)
USER_AGENT=$(echo "$FS_RESP" | cut -d'|' -f4-)

if [ -z "$COOKIE_STR" ]; then
  echo "✗ FlareSolverr failed to solve Cloudflare"
  rm -f /tmp/tb_rotate_signup.py
  exit 1
fi

echo "✓ FlareSolverr solved Cloudflare"

# Signup via PySocks + CF cookies
cat > /tmp/tb_fs_signup.py << PYEOF
import urllib.request, json, socks, socket, sys
socks.set_default_proxy(socks.SOCKS5, '127.0.0.1', 9050)
socket.socket = socks.socksocket
email, password, anon_key = sys.argv[1], sys.argv[2], sys.argv[3]
cookie_str, user_agent = sys.argv[4], sys.argv[5]
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

SIGNUP_RESP=$(python3 /tmp/tb_fs_signup.py "$EMAIL" "$PASSWORD" "$ANON_KEY" "$COOKIE_STR" "$USER_AGENT" 2>/dev/null)
USER_ID=$(echo "$SIGNUP_RESP" | python3 -c "import sys,json;print(json.load(sys.stdin).get('id','?'))" 2>/dev/null || echo "?")

# Destroy FS session
python3 -c "
import json, subprocess
payload = json.dumps({'cmd': 'session.destroy', 'session': '$SESSION_ID'})
subprocess.run(['curl','-s','-X','POST','$FS_URL','-H','Content-Type: application/json','-d',payload], timeout=10)
" 2>/dev/null || true

echo "✓ Signed up via Tor + FlareSolverr"
echo "  User ID: $USER_ID"
{
  echo "email=$EMAIL"
  echo "password=$PASSWORD"
  echo "user_id=$USER_ID"
  echo "verified=false"
  echo ""
} >> "$CRED"
echo "✓ Appended to $CRED"

rm -f /tmp/tb_rotate_signup.py /tmp/tb_fs_signup.py
exit 0
