#!/usr/bin/env bash
# flaresolverr-proxy.sh — Use FlareSolverr as a persistent CF-bypass proxy
# All requests go through FlareSolverr + Tor, Cloudflare solved automatically
set -euo pipefail

FS_URL="http://127.0.0.1:8191/v1"

if [ $# -lt 2 ]; then
  echo "Usage: $0 <get|post> <url> [json_body_file]"
  echo ""
  echo "Examples:"
  echo "  $0 get  https://db.torbox.app/auth/v1/signup"
  echo "  $0 post https://db.torbox.app/auth/v1/signup /tmp/body.json"
  echo ""
  echo "Persistent session: all requests share the same browser session,"
  echo "so CF cookies are kept across calls — no re-solving needed."
  exit 1
fi

METHOD="$1"
URL="$2"
BODY_FILE="${3:-}"

# Build FlareSolverr request
if [ "$METHOD" = "get" ]; then
  cat > /tmp/fs_req.json << JSONEOF
{
  "cmd": "request.get",
  "url": "$URL",
  "maxTimeout": 120000,
  "proxy": {"url": "socks5://127.0.0.1:9050"}
}
JSONEOF
elif [ "$METHOD" = "post" ]; then
  if [ -z "$BODY_FILE" ] || [ ! -f "$BODY_FILE" ]; then
    echo "✗ POST requires a JSON body file"
    exit 1
  fi
  BODY=$(cat "$BODY_FILE")
  # Get cookies from previous session (if any)
  COOKIES=""
  if [ -f /tmp/fs_session_cookies.json ] && [ -s /tmp/fs_session_cookies.json ]; then
    COOKIES=$(cat /tmp/fs_session_cookies.json)
  fi
  REQ=$(python3 -c "
import sys, json
body = json.loads('''$BODY''')
req = {
    'cmd': 'request.post',
    'url': '$URL',
    'maxTimeout': 120000,
    'postData': body,
    'proxy': {'url': 'socks5://127.0.0.1:9050'}
}
cookies = '''$COOKIES'''.strip()
if cookies:
    try: req['cookies'] = json.loads(cookies)
    except: pass
print(json.dumps(req))
")
  echo "$REQ" > /tmp/fs_req.json
else
  echo "✗ Method must be get or post"
  exit 1
fi

# Send request through FlareSolverr
RESP=$(curl -s -X POST "$FS_URL" \
  -H 'Content-Type: application/json' \
  -d @/tmp/fs_req.json)

# Save cookies for next request (persistent session)
echo "$RESP" | python3 -c "
import sys, json
try:
    r = json.load(sys.stdin)
    sol = r.get('solution', {})
    cookies = sol.get('cookies', [])
    # Merge with existing session cookies
    existing = {}
    try:
        with open('/tmp/fs_session_cookies.json') as f:
            for c in json.load(f):
                existing[c['name']] = c
    except: pass
    for c in cookies:
        existing[c['name']] = c
    with open('/tmp/fs_session_cookies.json', 'w') as f:
        json.dump(list(existing.values()), f)
except: pass
" 2>/dev/null || true

# Output the response body
echo "$RESP" | python3 -c "
import sys, json
r = json.load(sys.stdin)
sol = r.get('solution', {})
print(sol.get('response', ''))
"
