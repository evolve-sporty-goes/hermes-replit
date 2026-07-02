#!/usr/bin/env bash
# torbox_openrouter_style.sh — TorBox signup + Proton verify + API key extraction
# Uses the same pattern as openrouter_signup.sh
set -euo pipefail

export DISPLAY=:1
cd /home/runner/workspace
mkdir -p proton_profile credentials

OR_PROFILE="/home/runner/or_profile"
PROTON_PROFILE="/home/runner/workspace/proton_profile"
CRED="/home/runner/workspace/credentials/torbox_credentials.txt"

# Load Proton credentials
source <(python3 -c "
import importlib.util
s = importlib.util.spec_from_file_location('c', '$HOME/config.py')
m = importlib.util.module_from_spec(s)
s.loader.exec_module(m)
print(f'export PROTON_USER={m.PROTON_USERNAME}')
print(f'export PROTON_PASS={m.PROTON_PASSWORD}')
")

# Generate password with required char classes
PASSWORD=$(python3 -c "
import secrets,string
c = string.ascii_letters + string.digits + '!@#$%^&*'
pw = secrets.choice(string.ascii_lowercase) + secrets.choice(string.ascii_uppercase) + secrets.choice(string.digits) + secrets.choice('!@#$%^&*')
pw += ''.join(secrets.choice(c) for _ in range(12))
print(''.join(secrets.SystemRandom().sample(pw, len(pw))))
")

# Get email
bash scripts/email.sh > /dev/null 2>&1
EMAIL=$(bash scripts/email.sh 2>/dev/null | tail -1 | tr -d '[:space:]')
echo "Email: $EMAIL"

SUPABASE_KEY=$(cat /home/runner/workspace/credentials/.supabase_anon_key)

# ── STEP 1: Signup + Request OTP ──────────────────────────────────
cat > ~/torbox_signup_otp.py << 'PY'
import sys, os, json, subprocess
os.environ["DISPLAY"] = ":1"
sys.path.insert(0, os.path.expanduser("~"))
from cloakbrowser import launch_persistent_context

if "config" in sys.modules: del sys.modules["config"]
import importlib
C = importlib.import_module("config")

email, pw, supabase_key, profile = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]

# 1. Signup via direct curl
result = subprocess.run([
    'curl', '-s', '-X', 'POST',
    'https://db.torbox.app/auth/v1/signup',
    '-H', 'Content-Type: application/json',
    '-H', f'apikey: {supabase_key}',
    '-d', json.dumps({'email': email, 'password': pw})
], capture_output=True, text=True)
signup_data = json.loads(result.stdout)
user_id = signup_data.get('id', '?')
print(f"SIGNUP:OK ID={user_id}")

# 2. Request OTP via browser fetch (bypasses Cloudflare)
ctx = launch_persistent_context(profile, headless=False, humanize=True)
p = ctx.pages[0] if ctx.pages else ctx.new_page()
p()
p.goto("https://torbox.app", timeout=30000)
p.wait_for_timeout(2000)

otp_res = p.evaluate(f'''async () => {{
    const key = "{supabase_key}";
    const resp = await fetch("https://db.torbox.app/auth/v1/otp", {{
        method: "POST",
        headers: {{ "apikey": key, "Authorization": "Bearer " + key, "Content-Type": "application/json" }},
        body: JSON.stringify({{ email: "{email}" }})
    }});
    return await resp.text();
}}''')
print(f"OTP:{otp_res}")

# 3. Go to Proton inbox and extract verify URL
p.goto("https://mail.proton.me/u/0/inbox", timeout=60000)
p.wait_for_timeout(5000)

# Login if needed
if "account.proton.me" in p.url:
    p.locator("#username").fill(C.PROTON_USERNAME)
    p.locator("#password").fill(C.PROTON_PASSWORD)
    p.locator("button[type='submit']").click()
    p.wait_for_timeout(15000)

url = "NOT_FOUND"
for _ in range(10):
    try:
        p.keyboard.press("/")
        p.wait_for_timeout(800)
        p.keyboard.type(email, delay=20)
        p.keyboard.press("Enter")
        p.wait_for_timeout(5000)
        items = p.locator(".item-container,.message-item,[data-testid='message-item']")
        if items.count() > 0:
            items.first.click()
            p.wait_for_timeout(3000)
            break
        p.reload()
        p.wait_for_load_state("networkidle")
        p.wait_for_timeout(3000)
    except:
        try: p.keyboard.press("Escape")
        except: pass
        p.wait_for_timeout(3000)
else:
    print("VERIFY_URL:NOT_FOUND")
    ctx.close()
    sys.exit(0)

p.wait_for_timeout(2000)

# Extract verify URL - look for awstrack.me first (what TorBox sends)
for frame in p.frames:
    try:
        for href in frame.eval_on_selector_all("a[href]", "els=>els.map(e=>e.href)"):
            if "awstrack.me" in href and "verify" in href.lower():
                url = href
                break
        if url != "NOT_FOUND": break
    except: continue

# Fallback: direct db.torbox.app verify link
if url == "NOT_FOUND":
    for frame in p.frames:
        try:
            for href in frame.eval_on_selector_all("a[href]", "els=>els.map(e=>e.href)"):
                if "db.torbox.app/auth/v1/verify" in href:
                    url = href
                    break
            if url != "NOT_FOUND": break
        except: continue

# Final fallback: regex on raw HTML
if url == "NOT_FOUND":
    import re
    html = ""
    for f in p.frames:
        try: html += f.content() + "\n"
        except: pass
    m = re.search(r'https://db\\.torbox\\.app/auth/v1/verify[^\\s"\'<>]*', html)
    if m: url = m.group(0).replace("&", "&")

print(f"VERIFY_URL:{url}")
ctx.close()
PY

python3 ~/torbox_signup_otp.py "$EMAIL" "$PASSWORD" "$SUPABASE_KEY" "$PROTON_PROFILE"
if [ $? -ne 0 ]; then echo "Signup/OTP failed"; exit 1; fi

# Capture output
VURL=$(grep '^VERIFY_URL:' ~/torbox_signup_otp.py.log 2>/dev/null | cut -d: -f2- || echo "")
if [ -z "$VURL" ] || [ "$VURL" = "NOT_FOUND" ]; then
    echo "Verify URL not found"
    exit 1
fi
echo "Verify URL: ${VURL:0:80}..."

# Decode awstrack.me redirect if needed
if [[ "$VURL" == *"awstrack.me"* ]]; then
    VURL=$(python3 -c "
import urllib.parse, sys
url = sys.argv[1]
parts = url.split('/L0/')
if len(parts) > 1:
    encoded = parts[1].rsplit('/', 1)[0]
    print(urllib.parse.unquote(encoded))
else:
    print(url)
" "$VURL")
    echo "Decoded URL: ${VURL:0:80}..."
fi

# ── STEP 2: Click verify link + extract API key from Supabase ────────
cat > ~/torbox_verify_api.py << 'PY'
import sys, os, json, subprocess, re, time
os.environ["DISPLAY"] = ":1"
sys.path.insert(0, os.path.expanduser("~"))
from cloakbrowser import launch_persistent_context

if "config" in sys.modules: del sys.modules["config"]
import importlib
C = importlib.import_module("config")

verify_url, email, pw, supabase_key, cred_path, profile = sys.argv[1:7]

ctx = launch_persistent_context(profile, headless=False, humanize=True)
p = ctx.pages[0] if ctx.pages else ctx.new_page()

# Click verify link
p.goto(verify_url, timeout=60000)
p.wait_for_timeout(5000)
print(f"VERIFY_REDIRECT: {p.url}")

# Extract API key from Supabase api_tokens table
# First, login to get access token
SUPABASE_KEY = supabase_key
login_res = subprocess.run([
    'curl', '-s', '-X', 'POST',
    'https://db.torbox.app/auth/v1/token?grant_type=password',
    '-H', f'apikey: {SUPABASE_KEY}',
    '-H', 'Content-Type: application/json',
    '-d', json.dumps({'email': email, 'password': pw})
], capture_output=True, text=True)
login_data = json.loads(login_res.stdout)
access_token = login_data.get('access_token')
if not access_token:
    print("API_KEY:NOT_FOUND")
    ctx.close()
    sys.exit(1)

# Query api_tokens table
USER_ID = login_data['user']['id']
api_res = subprocess.run([
    'curl', '-s',
    f'https://db.torbox.app/rest/v1/api_tokens?auth_id=eq.{USER_ID}&select=token',
    '-H', f'apikey: {SUPABASE_KEY}',
    '-H', f'Authorization: Bearer {access_token}',
    '-H', 'User-Agent: Mozilla/5.0'
], capture_output=True, text=True)

try:
    api_data = json.loads(api_res.stdout)
    if api_data:
        api_key = api_data[0]['token']
        print(f"API_KEY:{api_key}")
        # Append to credentials file
        with open(cred_path, 'a') as f:
            f.write(f"\nemail={email}\npassword={pw}\nuser_id={USER_ID}\napi_key={api_key}\n\n")
    else:
        print("API_KEY:NOT_FOUND")
except:
    print("API_KEY:NOT_FOUND")

ctx.close()
PY

python3 ~/torbox_verify_api.py "$VURL" "$EMAIL" "$PASSWORD" "$SUPABASE_KEY" "$CRED" "$PROTON_PROFILE"
if [ $? -ne 0 ]; then echo "Verification/API extraction failed"; exit 1; fi

echo "Done! Check $CRED"