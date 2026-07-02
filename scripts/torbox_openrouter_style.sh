#!/usr/bin/env bash
# torbox_openrouter_style.sh — TorBox signup + Proton verify + API key extraction
# Uses the OpenRouter-style awstrack.me decoding method
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

ctx.close()
PY

python3 ~/torbox_signup_otp.py "$EMAIL" "$PASSWORD" "$SUPABASE_KEY" "$OR_PROFILE"

# ── STEP 2: Check Proton inbox for awstrack.me link (OpenRouter style) ──
cat > ~/torbox_proton.py << 'PY'
import sys, re, urllib.parse, html
from cloakbrowser import launch_persistent_context

PROTON_USER, PROTON_PASS, SIGNUP_EMAIL = sys.argv[1], sys.argv[2], sys.argv[3]

ctx = launch_persistent_context("/home/runner/workspace/proton_profile", headless=False)
page = ctx.pages[0] if ctx.pages else ctx.new_page()

page.goto("https://mail.proton.me/u/0/inbox#filter=unread", timeout=60000)
page.wait_for_timeout(5000)

if "account.proton.me" in page.url:
    page.locator("#username").fill(PROTON_USER)
    page.locator("#password").fill(PROTON_PASS)
    page.locator("button[type='submit']").click()
    page.wait_for_timeout(15000)

def find_awstrack():
    for frame in page.frames:
        try:
            raw_html = frame.content()
            if "verify" in raw_html.lower():
                clean_html = html.unescape(raw_html)
                # PRIMARY: Look for direct db.torbox.app verify link
                matches = re.findall(r'https://db\.torbox\.app/auth/v1/verify[^\s"<>]+', clean_html)
                if matches:
                    return matches[0]
                # Fallback: awstrack.me
                matches = re.findall(r'https://[^/]+\.awstrack\.me/L0/[^\s"<>]+', clean_html)
                if matches:
                    return matches[0]
                # Fallback: other torbox tracking domains
                matches = re.findall(r'https://[^/]*torbox\.app/[^\s"<>]+verify[^\s"<>]*', clean_html)
                if matches:
                    return matches[0]
        except Exception as e:
            pass
    return None

def decode_awstrack(url):
    # Handle awstrack.me format
    parts = url.split('/L0/')
    if len(parts) > 1:
        encoded = parts[1].rsplit('/', 1)[0]
        return urllib.parse.unquote(encoded)
    # Already a direct verify URL
    return url

checked = set()
for attempt in range(15):
    page.wait_for_timeout(15000)
    
    page.keyboard.press("/")
    page.wait_for_timeout(1000)
    page.keyboard.type("torbox", delay=80)
    page.keyboard.press("Enter")
    page.wait_for_timeout(1000)
    page.keyboard.press("Escape")
    page.wait_for_timeout(5000)
    
    items = page.locator(".item-container")
    count = items.count()
    if count == 0:
        page.goto("https://mail.proton.me/u/0/inbox#filter=unread", timeout=60000)
        page.wait_for_timeout(5000)
        continue
    
    for i in range(min(count, 5)):
        subj = items.nth(i).text_content().strip()[:80]
        if subj not in checked:
            checked.add(subj)
            items.nth(i).click()
            page.wait_for_timeout(6000)
            
            awstrack_url = find_awstrack()
            if awstrack_url:
                verify_url = decode_awstrack(awstrack_url)
                print(f"VERIFY_URL:{verify_url}")
                ctx.close()
                sys.exit(0)
            break
    
    if len(checked) >= count:
        checked.clear()
    
    page.goto("https://mail.proton.me/u/0/inbox#filter=unread", timeout=60000)
    page.wait_for_timeout(5000)

ctx.close()
print("VERIFY_URL:NOT_FOUND")
PY

VURL=$(python3 ~/torbox_proton.py "$PROTON_USER" "$PROTON_PASS" "$EMAIL" 2>&1 | grep '^VERIFY_URL:' | head -1 | cut -d: -f2-)
echo "  Link: ${VURL:0:80}..."
if [ -z "$VURL" ] || [ "$VURL" = "NOT_FOUND" ]; then
    echo "Not found, exiting..."
    exit 1
fi

# ── STEP 3: Click verify link + extract API key from Supabase ──────
# Adapted from openrouter_signup.sh verify pattern
cat > ~/torbox_verify.py << 'PY'
import sys, re, time, json, subprocess, os
os.environ["DISPLAY"] = ":1"
sys.path.insert(0, os.path.expanduser("~"))
from cloakbrowser import launch_persistent_context

if "config" in sys.modules: del sys.modules["config"]
import importlib
C = importlib.import_module("config")

verify_url, email, password, cred_path, profile = sys.argv[1:6]

ctx = launch_persistent_context(profile, headless=False, humanize=True)
p = ctx.pages[0] if ctx.pages else ctx.new_page()

p.goto(verify_url, timeout=60000)
api_key = None

# Wait for redirect to dashboard (success) or error page
for i in range(30):
    url = p.url
    time.sleep(2)
    
    # Check for error/expiration
    if "error=" in url and ("otp_expired" in url or "access_denied" in url):
        print("VERIFY_STATUS:EXPIRED", flush=True)
        ctx.close()
        sys.exit(2)
    
    # Success: redirected to dashboard
    if "torbox.app/dashboard" in url or "torbox.app/#" in url:
        print(f"VERIFY_REDIRECT: {url}", flush=True)
        break

# Query Supabase for API key
SUPABASE_KEY = open('/home/runner/workspace/credentials/.supabase_anon_key').read().strip()

# Login to get access token
login_res = subprocess.run([
    'curl', '-s', '-X', 'POST',
    'https://db.torbox.app/auth/v1/token?grant_type=password',
    '-H', f'apikey: {SUPABASE_KEY}',
    '-H', 'Content-Type: application/json',
    '-d', json.dumps({'email': email, 'password': password})
], capture_output=True, text=True)
login_data = json.loads(login_res.stdout)
access_token = login_data.get('access_token')
user_data = login_data.get('user', {})
user_id = user_data.get('id')

if not access_token:
    print("API_KEY:NOT_FOUND")
    ctx.close()
    sys.exit(1)

# Query api_tokens table using auth_id
api_res = subprocess.run([
    'curl', '-s',
    f'https://db.torbox.app/rest/v1/api_tokens?auth_id=eq.{user_id}&select=token',
    '-H', f'apikey: {SUPABASE_KEY}',
    '-H', f'Authorization: Bearer {access_token}',
    '-H', 'User-Agent: Mozilla/5.0'
], capture_output=True, text=True)

try:
    api_data = json.loads(api_res.stdout)
    if api_data:
        api_key = api_data[0]['token']
        print(f"API_KEY:{api_key}")
        with open(cred_path, "a") as f:
            f.write(f"\nEMAIL={email}\nPASSWORD={password}\nAPI_KEY={api_key}\n\n")
    else:
        print("API_KEY:NOT_FOUND")
except:
    print("API_KEY:NOT_FOUND")

ctx.close()
PY

python3 ~/torbox_verify.py "$VURL" "$EMAIL" "$PASSWORD" "$CRED" "$OR_PROFILE"
STATUS=$?

if [ $STATUS -eq 2 ]; then
    echo "Verification link expired! Retrying..."
    exit 2
elif [ $STATUS -ne 0 ]; then
    echo "Verification failed"
    exit 1
fi

echo "Done! Saved to $CRED"