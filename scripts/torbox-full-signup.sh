#!/usr/bin/env bash
# torbox-full-signup.sh — TorBox signup via Tor, verify via Proton, extract API key
#   Step 1: signup via curl + Tor + FlareSolverr (Cloudflare bypass)
#   Step 2: get verify URL via Playwright + Proton (normal, no Tor)
#   Step 3: visit verify URL + extract API key via Playwright + Tor + FlareSolverr
set -euo pipefail

CRED="/home/runner/workspace/credentials/torbox_credentials.txt"
ANON_KEY=$(cat /home/runner/workspace/credentials/.supabase_anon_key)
PR="/home/runner/proton_profile"

EMAIL_PREFIX="${1:-bavmin}"
PASSWORD="${2:-Satyana@1234}"
RAND=$(shuf -i 10000-99999 -n 1)
EMAIL="${EMAIL_PREFIX}+${RAND}@proton.me"

# ═══════════════════════════════════════════════════════════════════
# STEP 1: Signup via Tor + FlareSolverr
# ═══════════════════════════════════════════════════════════════════
echo "━━━ Step 1: Signup via Tor + FlareSolverr ━━━"

# 1a: FlareSolverr — solve Cloudflare, get cf_clearance cookie
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

COOKIE_STR=$(echo "$FS_RESP" | python3 -c "
import sys,json
r=json.load(sys.stdin)
cs=r.get('solution',{}).get('cookies',[])
print('; '.join(f\"{c['name']}={c['value']}\" for c in cs))")
USER_AGENT=$(echo "$FS_RESP" | python3 -c "
import sys,json
r=json.load(sys.stdin)
print(r.get('solution',{}).get('userAgent',''))")

if [ -z "$COOKIE_STR" ]; then
  echo "✗ FlareSolverr returned no cookies"
  exit 1
fi
echo "✓ Got cf_clearance cookie"

# 1b: Save values to files (avoids shell quoting hell)
echo -n "$ANON_KEY"   > /tmp/tb_anon_key.txt
echo -n "$EMAIL"      > /tmp/tb_email.txt
echo -n "$PASSWORD"   > /tmp/tb_password.txt
echo -n "$COOKIE_STR" > /tmp/tb_cf_cookies.txt
echo -n "$USER_AGENT" > /tmp/tb_cf_ua.txt

# 1c: Signup POST via Python + PySocks through Tor
cat > /tmp/tb_step1_signup.py << 'PYEOF'
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

RESP=$(python3 /tmp/tb_step1_signup.py)

ID=$(echo "$RESP" | python3 -c "
import sys,json
r=json.load(sys.stdin)
print(r.get('id','?'))" 2>/dev/null || echo "?")

echo "✓ Signed up via Tor"
echo "  Email:    $EMAIL"
echo "  Password: $PASSWORD"
echo "  User ID:  $ID"

# ═══════════════════════════════════════════════════════════════════
# STEP 2: Get verify URL via Playwright + Proton (normal, no Tor)
# ═══════════════════════════════════════════════════════════════════
echo ""
echo "━━━ Step 2: Get verify URL from Proton ━━━"

# Save email for the Python script to read
echo -n "$EMAIL" > /tmp/tb_verify_email.txt

cat > /tmp/tb_step2_proton.py << 'PYEOF'
import sys, os, re
sys.path.insert(0, os.path.expanduser("~"))
from cloakbrowser import launch, launch_persistent_context
with open('/tmp/tb_email.txt') as f:      email      = f.read().strip()
with open('/tmp/tb_password.txt') as f:   password   = f.read().strip()

PR = os.path.expanduser("~/proton_profile")
url = "NOT_FOUND"


    ctx = launch_persistent_context(PR, headless=True, humanize=True)
    pg = ctx.new_page()
    pg.goto("https://account.proton.me/login", timeout=60000)
    pg.wait_for_timeout(3000)

    logged_in = False
    try:
        if pg.locator("a:has-text('Mail')").is_visible(timeout=3000): logged_in = True
    except: pass

    if not logged_in:
        pg.locator("#username").fill(email)
        pg.locator("#password").fill(password)
        pg.locator("button[type='submit']").click()
        pg.wait_for_timeout(10000)
        pg.locator("a:has-text('Mail')").first.click(timeout=0)
        pg.wait_for_timeout(5000)

    pg.goto("https://mail.proton.me/u/0/inbox", timeout=30000)
    pg.wait_for_timeout(2000)

    # Search for the TorBox verification email
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

    # Extract verify link from email
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

VERIFY_URL=$(python3 /tmp/tb_step2_proton.py)

if [ "$VERIFY_URL" = "NOT_FOUND" ]; then
  echo "✗ Could not find verify URL in Proton inbox"
  echo "  Check manually for: $EMAIL"
  # Write what we have
  echo "email=$EMAIL"              >> "$CRED"
  echo "password=$PASSWORD"        >> "$CRED"
  echo "user_id=$ID"               >> "$CRED"
  echo "magic_link=NOT_FOUND"      >> "$CRED"
  echo ""                           >> "$CRED"
  exit 1
fi

echo "✓ Got verify URL:"
echo "  $VERIFY_URL"

# ═══════════════════════════════════════════════════════════════════
# STEP 3: Visit verify URL + extract API key via Playwright + Tor + FlareSolverr
# ═══════════════════════════════════════════════════════════════════
echo ""
echo "━━━ Step 3: Verify + extract API key via Tor ━━━"

# Save verify URL for the Python script
echo -n "$VERIFY_URL" > /tmp/tb_verify_url.txt

cat > /tmp/tb_step3_verify_api.py << 'PYEOF'
import sys, os, json, re
from cloakbrowser import launch, launch_persistent_context

with open("/tmp/tb_verify_url.txt") as f:  verify_url = f.read().strip()
with open("/tmp/tb_email.txt") as f:       email      = f.read().strip()
with open("/tmp/tb_password.txt") as f:    password   = f.read().strip()

PROXY = {"server": "socks5://127.0.0.1:9050"}
PROTON_PROFILE="/home/runner/proton_profile"
api_key = "NOT_FOUND"
demo_info = {}


    # Launch with Tor proxy
    browser = p.chromium.launch(proxy=PROXY)

    # 3a: Visit verify URL (Cloudflare challenge auto-solved by real browser)
    pg = browser.new_page()
    print(f"→ Visiting verify URL via Tor ...")
    pg.goto(verify_url, timeout=60000)
    pg.wait_for_timeout(5000)

    # Check if verification succeeded
    body_text = pg.locator("body").inner_text(timeout=10000) if pg.locator("body").count() > 0 else ""
    if "verified" in body_text.lower() or "confirmed" in body_text.lower():
        print("✓ Account verified!")
    else:
        print(f"  Verify page: {body_text[:200]}")

    # 3b: Login to TorBox dashboard to get API key
    print("→ Logging into TorBox dashboard ...")
    pg.goto("https://torbox.app/login", timeout=60000)
    pg.wait_for_timeout(3000)

    # Fill login form
    try:
        pg.locator("input[type='email'], input[name='email'], input[placeholder*='email' i]").first.fill(email)
        pg.locator("input[type='password'], input[name='password'], input[placeholder*='password' i]").first.fill(password)
        pg.locator("button[type='submit'], button:has-text('Login'), button:has-text('Sign in')").first.click()
        pg.wait_for_timeout(8000)
        print("✓ Logged in")
    except Exception as e:
        print(f"⚠ Login form issue: {e}, trying to continue ...")

    # 3c: Navigate to settings/API page
    print("→ Extracting API key ...")
    try:
        pg.goto("https://torbox.app/settings", timeout=30000)
        pg.wait_for_timeout(3000)
    except:
        pass

    # Try multiple selectors for API key
    page_text = pg.locator("body").inner_text(timeout=10000) if pg.locator("body").count() > 0 else ""

    # Look for API key patterns in page text
    # TorBox API keys are typically UUIDs or long hex strings
    ak_match = re.search(r'(?:api[_\s-]?key|token)["\s:]*([a-f0-9\-]{32,}|[A-Za-z0-9]{32,})', page_text, re.I)
    if ak_match:
        api_key = ak_match.group(1)

    # Also check input fields that might contain the key
    if api_key == "NOT_FOUND":
        for sel in ['input[value*="-"]', 'input[readonly]', 'input[type="text"]', 'code', 'pre', '[data-testid*="api"]', '[data-testid*="key"]', '[data-testid*="token"]']:
            try:
                els = pg.locator(sel)
                for i in range(min(els.count(), 10)):
                    val = els.nth(i).input_value() if els.nth(i).is_input() else els.nth(i).inner_text(timeout=2000)
                    if val and len(val) >= 32 and re.match(r'^[a-f0-9\-]{32,}$', val, re.I):
                        api_key = val
                        break
            except: continue
            if api_key != "NOT_FOUND": break

    # Try the direct API endpoint as fallback
    if api_key == "NOT_FOUND":
        print("→ Trying /api/user/me endpoint ...")
        try:
            # Re-use page's cookies for API call
            resp = pg.evaluate("""async () => {
                const r = await fetch('https://api.torbox.app/v1/api/user/me');
                return await r.text();
            }""")
            rj = json.loads(resp)
            if rj.get("success") and rj.get("data"):
                d = rj["data"]
                api_key = d.get("api_key", d.get("token", "NOT_FOUND"))
                demo_info = d
        except Exception as e:
            print(f"  API fallback: {e}")

    # 3d: Get subscription/demo info
    try:
        info_text = pg.locator("body").inner_text(timeout=5000)
        # Extract plan info
        for pat, key in [(r'plan[:\s]+(\w+)', 'plan'), (r'(\d+)\s*slots?', 'slots')]:
            m = re.search(pat, info_text, re.I)
            if m: demo_info[key] = m.group(1)
    except: pass

    browser.close()

# Output results
print(f"API_KEY={api_key}")
if demo_info:
    print(f"DEMO_INFO={json.dumps(demo_info)}")
PYEOF

STEP3_OUT=$(python3 /tmp/tb_step3_verify_api.py)
echo "$STEP3_OUT"

# Parse API key from step 3 output
API_KEY=$(echo "$STEP3_OUT" | grep "^API_KEY=" | cut -d= -f2-)
DEMO_INFO=$(echo "$STEP3_OUT" | grep "^DEMO_INFO=" | cut -d= -f2-)

# ═══════════════════════════════════════════════════════════════════
# Write credentials
# ═══════════════════════════════════════════════════════════════════
echo ""
echo "━━━ Results ━━━"

echo "email=$EMAIL"               >> "$CRED"
echo "password=$PASSWORD"         >> "$CRED"
echo "user_id=$ID"                >> "$CRED"
echo "magic_link=$VERIFY_URL"     >> "$CRED"
echo "api_key=$API_KEY"           >> "$CRED"
if [ -n "$DEMO_INFO" ]; then
  echo "demo=$DEMO_INFO"          >> "$CRED"
fi
echo ""                            >> "$CRED"

echo "✓ Credentials appended to $CRED"
echo "  Email:     $EMAIL"
echo "  Password:  $PASSWORD"
echo "  User ID:   $ID"
echo "  Verify:    ${VERIFY_URL:0:80}..."
echo "  API Key:   ${API_KEY:0:20}..."

# ═══════════════════════════════════════════════════════════════════
# Cleanup
# ═══════════════════════════════════════════════════════════════════
rm -f /tmp/fs_get.json /tmp/tb_anon_key.txt /tmp/tb_email.txt \
      /tmp/tb_password.txt /tmp/tb_cf_cookies.txt /tmp/tb_cf_ua.txt \
      /tmp/tb_verify_email.txt /tmp/tb_verify_url.txt \
      /tmp/tb_step1_signup.py /tmp/tb_step2_proton.py /tmp/tb_step3_verify_api.py
