#!/usr/bin/env bash
# torbox-signup.sh — TorBox full signup via Playwright + rotating free SOCKS5
#
# Strategy:
# 1) Grab free SOCKS5 proxies from ProxyScrape
# 2) Test each proxy against torbox.app
# 3) First proxy that passes CF wins → full signup pipeline through it
# 4) Fallback: Supabase API signup via Tor+FlareSolverr, then Playwright for dashboard
#
# Requires: playwright, PySocks, tor, flaresolverr
set -euo pipefail

CRED="/home/runner/workspace/credentials/torbox_credentials.txt"
ANON_KEY=$(cat /home/runner/workspace/credentials/.supabase_anon_key)
CHROMIUM="/nix/store/qa9cnw4v5xkxyip6mb9kxqfq1z4x2dx1-chromium-138.0.7204.100/bin/chromium"
PROTON_PROFILE="$HOME/proton_profile"
EMAIL_PREFIX="${1:-bavmin}"
PASSWORD="Satyana@1234"
EMAIL="${EMAIL_PREFIX}+${RANDOM}@proton.me"
PROXY_LIST="/tmp/free_socks5_proxies.txt"
MAX_CF_RETRIES=5
MAX_PROXY_TRIES=10

echo "========================================"
echo " TorBox Signup via Playwright + Free SOCKS5"
echo "========================================"
echo "Email: $EMAIL"

# Save values to files (avoids shell quoting hell)
echo -n "$ANON_KEY" > /tmp/tb_anon_key.txt
echo -n "$EMAIL"    > /tmp/tb_email.txt
echo -n "$PASSWORD" > /tmp/tb_password.txt

# ═══════════════════════════════════════════
# STEP 0: Fetch free SOCKS5 proxies
# ═══════════════════════════════════════════
echo ""
echo "→ [0] Fetching free SOCKS5 proxies from ProxyScrape ..."

curl -s "https://api.proxyscrape.com/v2/?request=displayproxies&protocol=socks5&timeout=10000&country=all" \
  > "$PROXY_LIST" 2>/dev/null || true

# Fallback: try HTTP proxies too
if [ ! -s "$PROXY_LIST" ] || [ $(wc -l < "$PROXY_LIST") -lt 3 ]; then
  echo "  Few SOCKS5 results, trying SOCKS4 ..."
  curl -s "https://api.proxyscrape.com/v2/?request=displayproxies&protocol=socks4&timeout=10000&country=all" \
    >> "$PROXY_LIST" 2>/dev/null || true
fi

PROXY_COUNT=$(grep -c '.' "$PROXY_LIST" 2>/dev/null || echo 0)
echo "  Got $PROXY_COUNT proxies"

if [ "$PROXY_COUNT" -eq 0 ]; then
  echo "✗ No proxies available, falling back to Tor + FlareSolverr"
  # Fall through to TOR_FALLBACK at the end
  NEED_TOR_FALLBACK=1
else
  NEED_TOR_FALLBACK=0
  # Shuffle for random selection
  shuf "$PROXY_LIST" -o "$PROXY_LIST"
fi

# ═══════════════════════════════════════════
# STEP 1: Signup via Supabase API (Tor+FlareSolverr)
#         This always works — CF bypassed by FS
# ═══════════════════════════════════════════
echo ""
echo "→ [1/4] Signup via Supabase API (Tor + FlareSolverr) ..."

SESSION_ID="torbox-$(date +%s)"

# FlareSolverr: solve CF for Supabase endpoint
cat > /tmp/fs_signup.json << JSONEOF
{
  "cmd": "request.get",
  "url": "https://db.torbox.app/auth/v1/signup",
  "maxTimeout": 120000,
  "proxy": {"url": "socks5://127.0.0.1:9050"},
  "session": "$SESSION_ID"
}
JSONEOF

FS_RESP=$(curl -s -X POST http://127.0.0.1:8191/v1 \
  -H 'Content-Type: application/json' \
  -d @/tmp/fs_signup.json)

CF_COOKIES=$(echo "$FS_RESP" | python3 -c "
import sys,json
r=json.load(sys.stdin)
cs=r.get('solution',{}).get('cookies',[])
print('; '.join(f\"{c['name']}={c['value']}\" for c in cs))
")
CF_UA=$(echo "$FS_RESP" | python3 -c "
import sys,json
print(json.load(sys.stdin).get('solution',{}).get('userAgent',''))
")

if [ -z "$CF_COOKIES" ]; then
  echo "X FlareSolverr failed, trying direct signup ..."
  # Direct signup (no Tor) as last resort — write to file to avoid quoting hell
  echo -n "$ANON_KEY" > /tmp/tb_anon_key.txt
  cat > /tmp/tb_direct_signup.py << 'DIREOF'
import urllib.request, json
with open('/tmp/tb_anon_key.txt') as f:   anon_key = f.read().strip()
with open('/tmp/tb_email.txt') as f:      email    = f.read().strip()
with open('/tmp/tb_password.txt') as f:   password = f.read().strip()
url = 'https://db.torbox.app/auth/v1/signup'
data = json.dumps({"email": email, "password": password}).encode()
req = urllib.request.Request(url, data=data, method='POST')
req.add_header('Content-Type', 'application/json')
req.add_header('apikey', anon_key)
try:
    resp = urllib.request.urlopen(req, timeout=30)
    print(resp.read().decode())
except urllib.error.HTTPError as e:
    print(e.read().decode())
DIREOF
  SIGNUP_RESP=$(python3 /tmp/tb_direct_signup.py)
else
  echo "OK Got CF cookies"

  # Save cookies for Python
  echo -n "$CF_COOKIES" > /tmp/tb_cf_cookies.txt
  echo -n "$CF_UA"     > /tmp/tb_cf_ua.txt

  # Signup POST via PySocks through Tor
  SIGNUP_RESP=$(python3 << 'PYEOF'
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
)
fi

USER_ID=$(echo "$SIGNUP_RESP" | python3 -c "
import sys,json
print(json.load(sys.stdin).get('id','?'))
" 2>/dev/null || echo "?")

echo "✓ Signed up"
echo "  User ID: $USER_ID"

# Destroy FS session
cat > /tmp/fs_destroy.json << JSONEOF
{"cmd": "session.destroy", "session": "$SESSION_ID"}
JSONEOF
curl -s -X POST http://127.0.0.1:8191/v1 -d @/tmp/fs_destroy.json >/dev/null 2>&1 || true

# ═══════════════════════════════════════════
# STEP 2: Get verify URL via Proton (Chromium, no proxy)
# ═══════════════════════════════════════════
echo ""
echo "→ [2/4] Getting verify URL from Proton Mail ..."

VERIFY_URL=$(python3 - "$EMAIL" << 'PYEOF'
import sys, os, re
sys.path.insert(0, os.path.expanduser("~"))
from playwright.sync_api import sync_playwright
import importlib

if "config" in sys.modules: del sys.modules["config"]
C = importlib.import_module("config")

email = sys.argv[1]
CH = "/nix/store/qa9cnw4v5xkxyip6mb9kxqfq1z4x2dx1-chromium-138.0.7204.100/bin/chromium"
PR = os.path.expanduser("~/proton_profile")
os.makedirs(PR, exist_ok=True)
url = "NOT_FOUND"

with sync_playwright() as p:
    ctx = p.chromium.launch_persistent_context(
        PR, executable_path=CH, headless=True,
        args=["--no-sandbox", "--disable-gpu"]
    )
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
  echo "✗ Verify link not found"
  {
    echo "email=$EMAIL"
    echo "password=$PASSWORD"
    echo "user_id=$USER_ID"
    echo "verified=false"
    echo ""
  } >> "$CRED"
  echo "X Appended (unverified) to $CRED"
  exit 0
fi

echo "✓ Got verify URL"

# ═══════════════════════════════════════════
# STEP 3: Verify + Dashboard + API Key
#         via Playwright + free SOCKS5 (rotating)
# ═══════════════════════════════════════════
echo ""
echo "→ [3/4] Verify + Login + Demo + API Key via Playwright ..."

echo -n "$VERIFY_URL" > /tmp/tb_verify_url.txt

API_KEY=$(python3 << 'PYEOF'
import json, os, sys, time, tempfile, shutil, atexit
from playwright.sync_api import sync_playwright

CHROMIUM = "/nix/store/qa9cnw4v5xkxyip6mb9kxqfq1z4x2dx1-chromium-138.0.7204.100/bin/chromium"

with open('/tmp/tb_verify_url.txt') as f: verify_url = f.read().strip()
with open('/tmp/tb_email.txt') as f:      email      = f.read().strip()
with open('/tmp/tb_password.txt') as f:   password   = f.read().strip()
with open('/tmp/tb_anon_key.txt') as f:   anon_key   = f.read().strip()

PROXY_LIST_FILE = '/tmp/free_socks5_proxies.txt'
MAX_PROXY_TRIES = int(os.environ.get('MAX_PROXY_TRIES', '10'))
MAX_CF_RETRIES  = int(os.environ.get('MAX_CF_RETRIES', '5'))

def load_proxies():
    """Load shuffled proxy list."""
    try:
        with open(PROXY_LIST_FILE) as f:
            proxies = [line.strip() for line in f if line.strip()]
        import random
        random.shuffle(proxies)
        return proxies
    except:
        return []

def test_proxy(proxy_addr):
    """Quick test — does this proxy work at all?"""
    import socks, socket
    host, port = proxy_addr.split(':')
    try:
        s = socks.socksocket()
        s.set_proxy(socks.SOCKS5, host, int(port))
        s.settimeout(8)
        s.connect(("torbox.app", 443))
        s.close()
        return True
    except:
        return False

def cf_solved(page):
    """Check if page is past Cloudflare."""
    try:
        title = page.title()
        if "Just a moment" in title or "Checking" in title:
            return False
    except: pass
    try:
        if page.locator("iframe[src*='challenges.cloudflare.com']").is_visible(timeout=1000):
            return False
    except: pass
    return True

def wait_for_cf(page, timeout=15):
    """Wait for Cloudflare to auto-solve."""
    for _ in range(timeout):
        if cf_solved(page):
            return True
        page.wait_for_timeout(1000)
    return False

def handle_cf_turnstile(page):
    """Click Cloudflare Turnstile checkbox if present."""
    for fr in page.frames:
        if "challenges.cloudflare" in fr.url or "cloudflare" in fr.name.lower():
            try:
                checkbox = fr.locator("input[type='checkbox'], .ctp-checkbox, #challenge-stage")
                if checkbox.first.is_visible(timeout=2000):
                    checkbox.first.click()
                    page.wait_for_timeout(5000)
                    return True
            except: pass
    return False

api_key = None
proxies = load_proxies()

if not proxies:
    print("  No free proxies, trying without proxy ...", file=sys.stderr)
    proxies = [None]

for proxy_idx, proxy_addr in enumerate(proxies[:MAX_PROXY_TRIES]):
    proxy_label = f"socks5://{proxy_addr}" if proxy_addr else "direct (no proxy)"
    print(f"\n  === Proxy {proxy_idx+1}/{min(len(proxies),MAX_PROXY_TRIES)}: {proxy_label} ===", file=sys.stderr)

    # Quick connectivity test for non-direct
    if proxy_addr and not test_proxy(proxy_addr):
        print(f"  ✗ Proxy unreachable, skipping", file=sys.stderr)
        continue

    proxy_config = {"server": f"socks5://{proxy_addr}"} if proxy_addr else None

    td = tempfile.mkdtemp(prefix="torbox-browser-")
    atexit.register(lambda d=td: shutil.rmtree(d, ignore_errors=True))

    try:
        with sync_playwright() as p:
            context = p.chromium.launch_persistent_context(
                td,
                executable_path=CHROMIUM,
                headless=False,
                proxy=proxy_config,
            )
            page = context.new_page()

            # 3a: Visit verify URL
            print(f"  Visiting verify URL ...", file=sys.stderr)
            page.goto(verify_url, timeout=30000)
            page.wait_for_timeout(3000)

            if not cf_solved(page):
                print(f"  CF challenge on verify, waiting ...", file=sys.stderr)
                if not wait_for_cf(page, 20):
                    handle_cf_turnstile(page)
                    if not wait_for_cf(page, 10):
                        print(f"  ✗ CF unsolvable with this proxy, next", file=sys.stderr)
                        continue

            print(f"  ✓ Verify URL loaded", file=sys.stderr)
            page.close()

            # 3b: Login
            page = browser.new_page()
            success = False

            for attempt in range(MAX_CF_RETRIES):
                print(f"  Login attempt {attempt+1} ...", file=sys.stderr)
                page.goto("https://torbox.app/login", timeout=30000)
                page.wait_for_timeout(5000)

                if not cf_solved(page):
                    print(f"  CF on login page, waiting ...", file=sys.stderr)
                    if not wait_for_cf(page, 20):
                        handle_cf_turnstile(page)
                        if not wait_for_cf(page, 10):
                            print(f"  ✗ CF unsolvable, next proxy", file=sys.stderr)
                            break

                # Check if we need to log in
                try:
                    email_input = page.locator("#email-input")
                    if email_input.is_visible(timeout=3000):
                        email_input.fill(email)
                        page.wait_for_timeout(500)
                        page.locator("#password-input").fill(password)
                        page.wait_for_timeout(500)
                        page.locator("button[type='submit']").click(force=True)
                        page.wait_for_timeout(5000)

                        # Handle post-submit CF
                        if not cf_solved(page):
                            handle_cf_turnstile(page)
                            wait_for_cf(page, 10)
                except Exception as e:
                    print(f"  Login interaction error: {e}", file=sys.stderr)

                # 3c: Click "Get your free demo now!"
                page.wait_for_timeout(3000)
                for sel in [
                    "a:has-text('Get your free demo now!')",
                    "button:has-text('Get your free demo now!')",
                    "text=Get your free demo now!"
                ]:
                    try:
                        btn = page.locator(sel).first
                        if btn.is_visible(timeout=2000):
                            btn.click()
                            page.wait_for_timeout(5000)
                            print(f"  ✓ Clicked free demo", file=sys.stderr)
                            break
                    except: pass

                # 3d: Extract API key from settings
                page.goto("https://torbox.app/settings", timeout=30000)
                page.wait_for_timeout(8000)

                if not cf_solved(page):
                    wait_for_cf(page, 15)

                api_key = page.evaluate("""() => {
                    for (const i of document.querySelectorAll('input')) {
                        const v = (i.value || '').trim();
                        if (v.length > 20 && !v.includes(' ') && !v.includes('@')) return v;
                    }
                    return null;
                }""")

                if api_key:
                    print(f"  ✓ Got API key!", file=sys.stderr)
                    success = True
                    break

                print(f"  Retry {attempt+1}: API key not found", file=sys.stderr)

            page.close()

            if success:
                break
            else:
                print(f"  ✗ Failed with this proxy, trying next", file=sys.stderr)

    except Exception as e:
        print(f"  ✗ Playwright error: {e}", file=sys.stderr)
        shutil.rmtree(td, ignore_errors=True)
        continue

print(api_key or "", end="")
PYEOF
)

# ═══════════════════════════════════════════
# STEP 4: Output & save
# ═══════════════════════════════════════════
echo ""
echo "========================================"
echo " Done!"
echo "========================================"
echo "  Email:    $EMAIL"
echo "  Password: $PASSWORD"
echo "  User ID:  $USER_ID"
if [ -n "$VERIFY_URL" ] && [ "$VERIFY_URL" != "NOT_FOUND" ]; then
  echo "  Verified: true"
else
  echo "  Verified: false"
fi
if [ -n "$API_KEY" ]; then
  echo "  API Key:  $API_KEY"
else
  echo "  API Key:  NOT_EXTRACTED"
fi

{
  echo "email=$EMAIL"
  echo "password=$PASSWORD"
  echo "user_id=$USER_ID"
  if [ -n "$VERIFY_URL" ] && [ "$VERIFY_URL" != "NOT_FOUND" ]; then
    echo "verified=true"
  else
    echo "verified=false"
  fi
  [ -n "$API_KEY" ] && echo "api_key=$API_KEY"
  echo ""
} >> "$CRED"

echo "✓ Appended to $CRED"

# Cleanup
rm -f /tmp/fs_signup.json /tmp/fs_destroy.json /tmp/tb_anon_key.txt \
      /tmp/tb_email.txt /tmp/tb_password.txt /tmp/tb_cf_cookies.txt \
      /tmp/tb_cf_ua.txt /tmp/tb_verify_url.txt /tmp/free_socks5_proxies.txt
