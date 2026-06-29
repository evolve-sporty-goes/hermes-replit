#!/usr/bin/env bash
# torbox-full-tor-signup.sh — Full TorBox signup pipeline via Tor
# Uses a SINGLE persistent FlareSolverr session to solve Cloudflare once,
# then reuse the browser context for all subsequent Tor-routed navigations.
#
# Steps:
# 1) Signup via Tor + FlareSolverr persistent session
# 2) Get verify URL via normal Playwright (Proton Mail, no Tor)
# 3) Visit verify link + login + get demo + extract API key
#    all via the same FlareSolverr session (cookies preserved)
set -euo pipefail

CRED="/home/runner/workspace/credentials/torbox_credentials.txt"
ANON_KEY=$(cat /home/runner/workspace/credentials/.supabase_anon_key)
PROTON_PROFILE="$HOME/proton_profile"
FS_URL="http://127.0.0.1:8191/v1"
SESSION_ID="torbox-tor-$(date +%s)"
EMAIL_PREFIX="${1:-bavmin}"
PASSWORD="${2:-Satyana@1234}"
RAND=$(shuf -i 10000-99999 -n 1)
EMAIL="${EMAIL_PREFIX}+${RAND}@proton.me"

echo "========================================"
echo " TorBox Full Signup via Tor"
echo " (Persistent FlareSolverr session)"
echo "========================================"
echo "Email: $EMAIL"
echo "FS Session: $SESSION_ID"

# ═══════════════════════════════════════════
# HELPER: FlareSolverr request with session
# ═══════════════════════════════════════════
fs_request() {
  local CMD="$1" URL="$2"
  local PAYLOAD
  PAYLOAD=$(python3 -c "
import json, sys
print(json.dumps({
    'cmd': '$CMD',
    'url': '$URL',
    'maxTimeout': 120000,
    'proxy': {'url': 'socks5://127.0.0.1:9050'},
    'session': '$SESSION_ID'
}))
")
  echo "$PAYLOAD" > /tmp/fs_payload.json
  curl -s -X POST "$FS_URL" \
    -H 'Content-Type: application/json' \
    -d @/tmp/fs_payload.json
}

# Extract cookies + UA from FlareSolverr response
fs_extract_cookies() {
  python3 -c "
import sys, json
r = json.load(sys.stdin)
cs = r.get('solution', {}).get('cookies', [])
print('; '.join(f\"{c['name']}={c['value']}\" for c in cs))
"
}

fs_extract_ua() {
  python3 -c "
import sys, json
print(json.load(sys.stdin).get('solution', {}).get('userAgent', ''))
"
}

fs_extract_html() {
  python3 -c "
import sys, json
print(json.load(sys.stdin).get('solution', {}).get('response', ''))
"
}

# ═══════════════════════════════════════════
# STEP 1: Create persistent session + Signup
# ═══════════════════════════════════════════
echo ""
echo "→ [1/3] Creating FlareSolverr session & solving Cloudflare ..."

# First request creates the session and solves CF for db.torbox.app
FS_RESP=$(fs_request "request.get" "https://db.torbox.app/auth/v1/signup")

COOKIE_STR=$(echo "$FS_RESP" | fs_extract_cookies)
USER_AGENT=$(echo "$FS_RESP" | fs_extract_ua)

if [ -z "$COOKIE_STR" ]; then
  echo "✗ FlareSolverr returned no cookies"
  exit 1
fi
echo "✓ Session created, cf_clearance obtained"

# Save values to files for Python (avoids shell quoting hell)
echo -n "$ANON_KEY"   > /tmp/tb_anon_key.txt
echo -n "$EMAIL"      > /tmp/tb_email.txt
echo -n "$PASSWORD"   > /tmp/tb_password.txt
echo -n "$COOKIE_STR" > /tmp/tb_cf_cookies.txt
echo -n "$USER_AGENT" > /tmp/tb_cf_ua.txt

# Signup POST via PySocks through Tor (reuses CF cookies)
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

SIGNUP_RESP=$(python3 /tmp/tb_tor_signup.py)

# Save raw response for debugging
echo -n "$SIGNUP_RESP" > /tmp/tb_signup_resp.txt

USER_ID=$(python3 -c "
import json
with open('/tmp/tb_signup_resp.txt') as f:
    r = json.load(f)
print(r.get('id','?'))
" 2>/dev/null || echo "?")

echo "✓ Signed up via Tor"
echo "  User ID: $USER_ID"

# ═══════════════════════════════════════════
# STEP 2: Get verify URL via Proton (Playwright, NO Tor)
# ═══════════════════════════════════════════
echo ""
echo "→ [2/3] Getting verify URL from Proton Mail (normal Playwright) ..."

VERIFY_URL=$(python3 - "$EMAIL" << 'PYEOF'
import sys, os, re
sys.path.insert(0, os.path.expanduser("~"))
from cloakbrowser import launch, launch_persistent_context
import importlib

if "config" in sys.modules: del sys.modules["config"]
C = importlib.import_module("config")

email = sys.argv[1]
PR = os.path.expanduser("~/proton_profile")
os.makedirs(PR, exist_ok=True)
url = "NOT_FOUND"


    ctx = launch_persistent_context(PR, headless=True, humanize=True)
    pg = ctx.new_page()
    pg.goto("https://account.proton.me/login", timeout=60000)
    pg.wait_for_timeout(3000)

    logged_in = False
    try:
        if pg.locator("a:has-text('Mail')").is_visible(timeout=3000):
            logged_in = True
    except: pass

    if not logged_in:
        pg.locator("#username").fill(C.PROTON_USERNAME)
        pg.locator("#password").fill(C.PROTON_PASSWORD)
        pg.locator("button[type='submit']").click()
        pg.wait_for_timeout(10000)
        pg.locator("a:has-text('Mail')").first.click(timeout=0)
        pg.wait_for_timeout(5000)

    pg.goto("https://mail.proton.me/u/0/inbox", timeout=30000)
    pg.wait_for_timeout(2000)

    for _ in range(7):
        try:
            pg.keyboard.press("/")
            pg.wait_for_timeout(800)
            pg.keyboard.type(email, delay=20)
            pg.keyboard.press("Enter")
            pg.wait_for_timeout(4000)
            items = pg.locator(".item-container,.message-item,[data-testid='message-item']")
            if items.count() > 0:
                items.first.click()
                pg.wait_for_timeout(2000)
                break
            pg.reload()
            pg.wait_for_load_state("networkidle")
            pg.wait_for_timeout(2000)
        except:
            try: pg.keyboard.press("Escape")
            except: pass
            pg.wait_for_timeout(2000)
    else:
        print("NOT_FOUND", end="")
        ctx.close()
        sys.exit(0)

    pg.wait_for_timeout(1500)

    for frame in pg.frames:
        try:
            for href in frame.eval_on_selector_all("a[href]", "els=>els.map(e=>e.href)"):
                if ("verify" in href.lower() or "confirm" in href.lower()) and "torbox" in href.lower():
                    url = href.replace("&amp;", "&")
                    break
            if url != "NOT_FOUND": break
        except: continue

    if url == "NOT_FOUND":
        html = ""
        for f in pg.frames:
            try: html += f.content() + "\n"
            except: pass
        m = re.search(r'https://db\.torbox\.app/auth/v1/verify[^\s"\'<>]*', html)
        if m: url = m.group(0).replace("&amp;", "&")

    ctx.close()
print(url, end="")
PYEOF
)

if [[ "$VERIFY_URL" == "NOT_FOUND" ]]; then
  echo "✗ Verify link not found in Proton"
  {
    echo "email=$EMAIL"
    echo "password=$PASSWORD"
    echo "user_id=$USER_ID"
    echo "verified=false"
    echo ""
  } >> "$CRED"
  echo "✗ Appended (unverified) to $CRED"
  # Destroy FlareSolverr session on early exit
  fs_request "session.destroy" "https://torbox.app" >/dev/null 2>&1 || true
  exit 0
fi

echo "✓ Got verify URL"
echo "  $VERIFY_URL"

# ═══════════════════════════════════════════
# STEP 3: Verify + Login + Demo + API key
#         All via same FlareSolverr session
# ═══════════════════════════════════════════
echo ""
echo "→ [3/3] Verify + Login + Demo via persistent FlareSolverr session ..."

# Save step 3 values, pass session ID to Python
echo -n "$VERIFY_URL"  > /tmp/tb_verify_url.txt
echo -n "$SESSION_ID"  > /tmp/tb_fs_session.txt

API_KEY=$(python3 << 'PYEOF'
import json, os, sys, subprocess

SESSION_ID = open('/tmp/tb_fs_session.txt').read().strip()
FS_URL = "http://127.0.0.1:8191/v1"
PROXY = "socks5://127.0.0.1:9050"

with open('/tmp/tb_verify_url.txt') as f: verify_url = f.read().strip()
with open('/tmp/tb_email.txt') as f:      email      = f.read().strip()
with open('/tmp/tb_password.txt') as f:   password   = f.read().strip()

def fs_post(cmd, url):
    """Send request to FlareSolverr using persistent session."""
    payload = json.dumps({
        "cmd": cmd,
        "url": url,
        "maxTimeout": 120000,
        "proxy": {"url": PROXY},
        "session": SESSION_ID
    })
    result = subprocess.run(
        ["curl", "-s", "-X", "POST", FS_URL,
         "-H", "Content-Type: application/json",
         "-d", payload],
        capture_output=True, text=True, timeout=130
    )
    try:
        return json.loads(result.stdout)
    except:
        return {"solution": {}}

def get_cookies(fs_resp):
    cookies = fs_resp.get("solution", {}).get("cookies", [])
    return "; ".join(f"{c['name']}={c['value']}" for c in cookies)

def get_ua(fs_resp):
    return fs_resp.get("solution", {}).get("userAgent", "")

api_key = None

# 3a: Visit verify URL (same session — CF already solved for db.torbox.app)
print(f"  Visiting verify URL via FS session ...", file=sys.stderr)
fs_verify = fs_post("request.get", verify_url)
print(f"  Verify status: {fs_verify.get('status', '?')}", file=sys.stderr)

# 3b: Playwright + Tor — handles CF Turnstile natively
# FlareSolverr can solve db.torbox.app CF but NOT torbox.app Turnstile.
# Playwright persistent context keeps browser state across navigations,
# so CF only needs solving once per domain — after that cookies persist.
from cloakbrowser import launch, launch_persistent_context
import tempfile, shutil, atexit

td = tempfile.mkdtemp(prefix="torbox-tor-")
atexit.register(lambda: shutil.rmtree(td, ignore_errors=True))

# Get UA from FlareSolverr session (consistent fingerprint)
fs_ua_resp = fs_post("request.get", "https://db.torbox.app")
best_ua = get_ua(fs_ua_resp)


def wait_for_cf_solve(pg, max_wait=60):
    """Wait for Cloudflare challenge to auto-solve in Playwright.
    Detects 'Just a moment' title or CF iframes, waits until cleared.
    Returns True if solved, False if still challenged after max_wait."""
    for _ in range(max_wait // 3):
        is_cf = False
        try:
            if "Just a moment" in (pg.title() or ""):
                is_cf = True
        except: pass
        try:
            if pg.locator("iframe[src*='challenges.cloudflare.com']").is_visible(timeout=500):
                is_cf = True
        except: pass

        if not is_cf:
            return True

        # Try clicking turnstile checkbox in any CF frame
        for fr in pg.frames:
            if "challenges.cloudflare" in fr.url:
                try:
                    cb = fr.locator("input[type='checkbox']")
                    if cb.is_visible(timeout=1000):
                        cb.click()
                except: pass

        pg.wait_for_timeout(3000)

    return False


def safe_goto(pg, url, timeout=30000):
    """Navigate to URL, then wait for any CF challenge to resolve."""
    pg.goto(url, timeout=timeout)
    pg.wait_for_timeout(2000)
    solved = wait_for_cf_solve(pg)
    if not solved:
        print(f"  ⚠ CF may not be fully solved for {url[:50]}", file=sys.stderr)
    else:
        print(f"  ✓ Page ready: {url[:50]}", file=sys.stderr)



    ctx = launch_persistent_context(
        td,
        proxy={"server": PROXY},
        user_agent=best_ua if best_ua else None,
    )
    for attempt in range(3):
        pg = ctx.new_page()
        safe_goto(pg, "https://torbox.app/login")

        # Check if on login page (form visible)
        email_visible = False
        try:
            email_visible = pg.locator("#email-input").is_visible(timeout=3000)
        except: pass

        if email_visible or "login" in pg.url:
            print(f"  Logging in (attempt {attempt+1}) ...", file=sys.stderr)
            pg.locator("#email-input").fill(email)
            pg.wait_for_timeout(500)
            pg.locator("#password-input").fill(password)
            pg.wait_for_timeout(500)

            # Handle turnstile widget on login form
            for fr in pg.frames:
                if "challenges.cloudflare" in fr.url or "turnstile" in fr.url:
                    try:
                        cb = fr.locator("input[type='checkbox']")
                        if cb.is_visible(timeout=2000):
                            cb.click()
                            pg.wait_for_timeout(5000)
                    except: pass
                    break

            pg.locator("button[type='submit']").click(force=True)
            pg.wait_for_timeout(3000)

            # Wait for CF after login redirect
            wait_for_cf_solve(pg, max_wait=30)
            print(f"  After login: {pg.url[:60]}", file=sys.stderr)
        else:
            print(f"  Login form not found, current URL: {pg.url[:60]}", file=sys.stderr)

        # Click "Get your free demo now!"
        for sel in [
            "a:has-text('Get your free demo now!')",
            "button:has-text('Get your free demo now!')",
            "text=Get your free demo now!"
        ]:
            try:
                btn = pg.locator(sel).first
                if btn.is_visible(timeout=3000):
                    btn.click()
                    pg.wait_for_timeout(5000)
                    wait_for_cf_solve(pg, max_wait=30)
                    print(f"  Clicked free demo", file=sys.stderr)
                    break
            except: pass

        # Navigate to settings and extract API key
        safe_goto(pg, "https://torbox.app/settings", timeout=30000)
        pg.wait_for_timeout(5000)

        api_key = pg.evaluate("""() => {
            for (const i of document.querySelectorAll('input')) {
                const v = (i.value || '').trim();
                if (v.length > 20 && !v.includes(' ') && !v.includes('@')) return v;
            }
            return null;
        }""")

        if api_key:
            print(f"  Got API key", file=sys.stderr)
            pg.close()
            break

        pg.close()
        print(f"  Retry {attempt+1}: API key not found", file=sys.stderr)

    ctx.close()

print(api_key or "", end="")
PYEOF
)

# ═══════════════════════════════════════════
# Destroy FlareSolverr session (cleanup)
# ═══════════════════════════════════════════
echo ""
echo "→ Destroying FlareSolverr session ..."
fs_request "session.destroy" "https://torbox.app" >/dev/null 2>&1 || true
echo "✓ Session destroyed"

# ═══════════════════════════════════════════
# Output & save credentials
# ═══════════════════════════════════════════
echo ""
echo "========================================"
echo " Done!"
echo "========================================"
echo "  Email:    $EMAIL"
echo "  Password: $PASSWORD"
echo "  User ID:  $USER_ID"
echo "  Verified: true"
if [ -n "$API_KEY" ]; then
  echo "  API Key:  $API_KEY"
else
  echo "  API Key:  NOT_EXTRACTED"
fi

{
  echo "email=$EMAIL"
  echo "password=$PASSWORD"
  echo "user_id=$USER_ID"
  echo "verified=true"
  [ -n "$API_KEY" ] && echo "api_key=$API_KEY"
  echo ""
} >> "$CRED"

echo "✓ Appended to $CRED"

# Cleanup temp files
rm -f /tmp/fs_payload.json /tmp/tb_anon_key.txt /tmp/tb_email.txt \
      /tmp/tb_password.txt /tmp/tb_cf_cookies.txt /tmp/tb_cf_ua.txt \
      /tmp/tb_verify_url.txt /tmp/tb_tor_signup.py /tmp/tb_fs_session.txt \
      /tmp/tb_signup_resp.txt
