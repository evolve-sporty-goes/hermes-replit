#!/bin/bash
# cloudflare_signup.sh — signup + verify + create Workers AI API token
bash "$HOME/workspace/setup_wireproxy.sh" >/dev/null  2>&1
set -e
export DISPLAY=:1
cd /home/runner/workspace
mkdir -p proton_profile credentials

CF_PROFILE="/home/runner/cf_profile"
PROTON_PROFILE="/home/runner/workspace/proton_profile"
CRED="/home/runner/workspace/credentials/cloudflare.txt"
EMAIL=$(bash scripts/email.sh 2>/dev/null | tail -1 | tr -d '[:space:]')

source <(python3 -c "import importlib.util; s=importlib.util.spec_from_file_location('c','$HOME/config.py'); m=importlib.util.module_from_spec(s); s.loader.exec_module(m); print(f'export PROTON_USER={m.PROTON_USERNAME}'); print(f'export PROTON_PASS={m.PROTON_PASSWORD}')")
PASSWORD=$(python3 -c "import secrets,string; c=string.ascii_letters+string.digits+'!@#%'; print(secrets.choice(string.ascii_letters)+secrets.choice(string.digits)+secrets.choice('!@#%')+''.join(secrets.choice(c) for _ in range(12)))")
echo "Email: $EMAIL"
rm -rf "$CF_PROFILE" && mkdir -p "$CF_PROFILE"

# ── STEP 1: Cloudflare Signup ────────────────────────────────────────────
cat > ~/cf_signup.py << 'PY'
import sys
from cloakbrowser import launch_persistent_context
email, password, profile = sys.argv[1], sys.argv[2], sys.argv[3]
ctx = launch_persistent_context(profile, headless=False, humanize=True, proxy="socks5://127.0.0.1:40000", geoip=True)
p = ctx.pages[0] if ctx.pages else ctx.new_page()
p.goto("https://dash.cloudflare.com/sign-up", timeout=60000, wait_until="domcontentloaded")
p.wait_for_timeout(4000)
# Fill form
p.locator("#emailAddress-field").type(email, delay=50)
p.wait_for_timeout(300)
p.locator("#password-field").type(password, delay=50)
p.wait_for_timeout(500)
# Submit
p.get_by_role("button", name="Signup").click()
p.wait_for_timeout(8000)
# Solve Turnstile if visible
for f in p.frames:
    if "challenges.cloudflare" in (f.url or ""):
        try:
            fb = f.frame_element().bounding_box()
            if fb and fb["width"] > 50:
                p.mouse.click(fb["x"] + 30, fb["y"] + fb["height"] / 2)
                p.wait_for_timeout(15000)
                break
        except: pass
print(f"TURNSTILE:RESULT URL={p.url}", flush=True)
ctx.close()
PY

# ── STEP 2: Get verify link from Proton ───────────────────────────────────
cat > ~/cf_proton.py << 'PY'
import sys, re, time, html
from cloakbrowser import launch_persistent_context

PROTON_USER, PROTON_PASS, SIGNUP_EMAIL = sys.argv[1], sys.argv[2], sys.argv[3]
td = sys.argv[4] if len(sys.argv) > 4 else None

ctx = launch_persistent_context("/home/runner/workspace/proton_profile", headless=False, proxy="socks5://127.0.0.1:40000", geoip=True)
page = ctx.pages[0] if ctx.pages else ctx.new_page()

page.goto("https://mail.proton.me/u/1/inbox#filter=unread", timeout=60000)
page.wait_for_timeout(5000)

if "account.proton.me" not in page.url:
    print("Already logged in")
else:
    page.locator("#username").fill(PROTON_USER)
    page.locator("#password").fill(PROTON_PASS)
    page.locator("button[type='submit']").click()
    page.wait_for_timeout(15000)

def find_verify():
    for frame in page.frames:
        try:
            raw_html = frame.content()
            if "cloudflare.com" in raw_html:
                clean_html = html.unescape(raw_html)
                matches = re.findall(r'https://dash\.cloudflare\.com/email-verification\?[^\s"<>()]+', clean_html)
                if matches:
                    return matches[0]
        except Exception as e:
            pass
    try:
        links = page.locator("a[href*='cloudflare.com/email-verification']").all()
        for link in reversed(links):
            href = link.get_attribute("href")
            if href and "email-verification" in href:
                return html.unescape(href)
    except Exception as e:
        pass
    return None

checked = set()
for attempt in range(15):
    page.wait_for_timeout(15000)
    items = page.locator(".item-container")
    count = items.count()
    if count == 0:
        page.goto("https://mail.proton.me/u/1/inbox#filter=unread", timeout=60000)
        page.wait_for_timeout(5000)
        continue
    for i in range(min(count, 5)):
        subj = items.nth(i).text_content().strip()[:80]
        if subj not in checked:
            checked.add(subj)
            items.nth(i).click()
            page.wait_for_timeout(6000)
            link = find_verify()
            if link:
                print(f"VERIFY_URL:{link}")
                ctx.close()
                sys.exit(0)
            break
    if len(checked) >= count:
        checked.clear()
    page.goto("https://mail.proton.me/u/1/inbox#filter=unread", timeout=60000)
    page.wait_for_timeout(5000)

ctx.close()
print("VERIFY_URL:NOT_FOUND")
PY

# ── STEP 3: Verify email + create Workers AI API token ───────────────────────
cat > ~/cf_verify.py << 'PY'
import sys, re, time
from cloakbrowser import launch_persistent_context

verify_url, email, password, cred_path, profile = sys.argv[1:6]
ctx = launch_persistent_context(profile, headless=False, humanize=True, proxy="socks5://127.0.0.1:40000", geoip=True)
ctx.grant_permissions(["clipboard-read", "clipboard-write"])
p = ctx.pages[0] if ctx.pages else ctx.new_page()

p.goto(verify_url, timeout=60000)
p.wait_for_timeout(5000)

# Solve Turnstile if visible
for f in p.frames:
    if "challenges.cloudflare" in (f.url or ""):
        try:
            fb = f.frame_element().bounding_box()
            if fb and fb["width"] > 50:
                p.mouse.click(fb["x"] + 30, fb["y"] + fb["height"] / 2)
                p.wait_for_timeout(15000)
                break
        except: pass

# Step 2: Workers and Pages
p.goto("https://dash.cloudflare.com/?to=/:account/workers-and-pages", timeout=60000)
p.wait_for_timeout(5000)

# Step 3: Workers AI API Quick Start
p.goto("https://dash.cloudflare.com/?to=/:account/ai/workers-ai/api-quick-start", timeout=60000)
p.wait_for_timeout(5000)

# Step 4: extract account ID from URL path
account_id = None
for m in re.findall(r'/([a-f0-9]{32})/', p.url):
    account_id = m
    break

# Step 5: click Create a Workers AI API Token button
p.locator("button:has-text('Create a Workers AI API Token')").first.click()

# Step 6: wait 2s
p.wait_for_timeout(2000)

# Step 7: click Create API Token
p.locator("button:has-text('Create API Token')").first.click()
p.wait_for_timeout(3000)

# Step 8: extract API token from page
api_key = None
for el in p.locator("pre, code, span, div").all():
    text = el.inner_text() or ""
    for m in re.findall(r'(?:cf_|cfut_)[a-zA-Z0-9_-]{30,}', text):
        api_key = m
        break
    if api_key:
        break

# Step 9: click Finish
try:
    p.locator("button:has-text('Finish')").first.click()
except Exception:
    pass
p.wait_for_timeout(2000)

ctx.close()
with open(cred_path, "a") as f:
    f.write(f"\nEMAIL={email}\nPASSWORD={password}\nACCOUNT_ID={account_id or 'NOT_FOUND'}\nAPI_KEY={api_key or 'NOT_FOUND'}\n")
print(f"API_KEY:{api_key or 'NOT_FOUND'}", flush=True)
if account_id:
    print(f"ACCOUNT_ID:{account_id}", flush=True)
PY

# ── MAIN ───────────────────────────────────────────────────────────────────
set +e

for ATTEMPT in 1 2 3; do
  if [ "$ATTEMPT" -gt 1 ]; then
    EMAIL=$(bash scripts/email.sh 2>/dev/null | tail -1 | tr -d '[:space:]')
    PASSWORD=$(python3 -c "import secrets,string; c=string.ascii_letters+string.digits+'!@#%'; print(secrets.choice(string.ascii_letters)+secrets.choice(string.digits)+secrets.choice('!@#%')+''.join(secrets.choice(c) for _ in range(12)))")
    rm -rf "$CF_PROFILE" && mkdir -p "$CF_PROFILE"
    echo "Retry $ATTEMPT: $EMAIL"
  fi

  echo "=== Step 1: Signup ==="
  python3 ~/cf_signup.py "$EMAIL" "$PASSWORD" "$CF_PROFILE"
  if [ $? -ne 0 ]; then echo "Signup failed, retrying..."; continue; fi

  echo "=== Step 2: Check inbox for verification ==="
  VURL=$(python3 ~/cf_proton.py "$PROTON_USER" "$PROTON_PASS" "$EMAIL" "$PROTON_PROFILE" 2>&1 | grep '^VERIFY_URL:' | head -1 | cut -d: -f2-)
  echo "  Link: ${VURL:0:80}..."
  if [ -z "$VURL" ] || [ "$VURL" = "NOT_FOUND" ]; then echo "Not found, retrying..."; continue; fi

  echo "=== Step 3: Verify + Create Workers AI API Token ==="
  python3 ~/cf_verify.py "$VURL" "$EMAIL" "$PASSWORD" "$CRED" "$CF_PROFILE"

  echo "Done! Saved to $CRED"
  exit 0
done

echo "FAILED: 3 attempts exhausted"
exit 1