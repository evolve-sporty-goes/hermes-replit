#!/bin/bash
# cloudflare_signup.sh — signup + verify + create Workers AI API token
set -e
export DISPLAY=:1
cd /home/runner/workspace
mkdir -p proton_profile credentials

CF_PROFILE="/tmp/cf_profile"
PROTON_PROFILE="/tmp/proton_profile"
CRED="/home/runner/workspace/credentials/cloudflare.txt"
EMAIL=$(bash scripts/email.sh 2>/dev/null | tail -1 | tr -d '[:space:]')

source <(python3 -c "import importlib.util; s=importlib.util.spec_from_file_location('c','$HOME/config.py'); m=importlib.util.module_from_spec(s); s.loader.exec_module(m); print(f'export PROTON_USER={m.PROTON_USERNAME}'); print(f'export PROTON_PASS={m.PROTON_PASSWORD}')")
PASSWORD=$(python3 -c "import secrets,string; c=string.ascii_letters+string.digits+'!@#%'; print(secrets.choice(string.ascii_letters)+secrets.choice(string.digits)+secrets.choice('!@#%')+''.join(secrets.choice(c) for _ in range(12)))")
echo "Email: $EMAIL"
rm -rf "$CF_PROFILE" && mkdir -p "$CF_PROFILE"

# ── STEP 1: Cloudflare Signup ────────────────────────────────────────────
cat > ~/cf_signup.py << 'PY'
import sys, random
from cloakbrowser import launch_persistent_context
proxies = [
    "socks5://127.0.0.1:9050",   # Tor
    "socks5://127.0.0.1:40000", #USA
    "socks5://127.0.0.1:40001", #USA
    "socks5://127.0.0.1:40002",
]
selected_proxy = random.choice(proxies)
email, password, profile = sys.argv[1], sys.argv[2], sys.argv[3]
ctx = launch_persistent_context(profile,headless=False,humanize=True,  proxy=selected_proxy,geoip=True,)
#ctx = launch_persistent_context(profile, headless=False, humanize=True, proxy="socks5://127.0.0.1:40000", geoip=True)
p = ctx.pages[0] if ctx.pages else ctx.new_page()
p.goto("https://dash.cloudflare.com/sign-up", timeout=120000, wait_until="domcontentloaded")
p.wait_for_timeout(5000)
# Fill email
p.locator("[data-testid='signup-input-email']").fill(email)
p.wait_for_timeout(2000)
# Fill password
p.locator("[data-testid='signup-input-password']").fill(password)
p.wait_for_timeout(1500)

def click_turnstile(page):
    for f in page.frames:
        if "challenges.cloudflare" in (f.url or ""):
            try:
                fb = f.frame_element().bounding_box()
                if fb and fb["width"] > 50:
                    page.mouse.click(fb["x"] + 30, fb["y"] + fb["height"] / 2)
                    return True
            except: pass
    return False

result = "FAILED"
for attempt in range(3):
    print(f"SIGNUP_ATTEMPT {attempt+1} URL={p.url}", flush=True)
    if "sign-up" not in p.url:
        result = "SUCCESS"
        break
    # attempt Turnstile click if iframe is present
    click_turnstile(p)
    p.wait_for_timeout(10000)
    # submit form
    try:
        p.locator("button[type='submit']").filter(has_text="Sign up").first.click()
    except Exception as e:
        print(f"SIGNUP_CLICK_ERROR {e}", flush=True)
    p.wait_for_timeout(10000)

print(f"SIGNUP_RESULT {result} URL={p.url}", flush=True)
p.wait_for_timeout(10000)
ctx.close()
if result == "FAILED":
    raise RuntimeError("Signup failed after 5 attempts")
    sys.exit(1)
PY

# ── STEP 2: Proton link extractor ─────────────────────────────────────────
cat > ~/cf_proton_extract.py << 'PY'
import sys, re, html
from cloakbrowser import launch_persistent_context

proton_user, proton_pass, signup_email, proton_profile = sys.argv[1:5]
ctx = launch_persistent_context(proton_profile, headless=False, geoip=True)
page = ctx.pages[0] if ctx.pages else ctx.new_page()

page.goto("https://mail.proton.me/u/1/inbox#filter=unread", timeout=60000)
page.wait_for_timeout(5000)

if "account.proton.me" in page.url:
    page.locator("input#username, input[name='username']").first.fill(proton_user)
    page.locator("input#password, input[name='password']").first.fill(proton_pass)
    page.locator("button[type='submit']").first.click()
    page.wait_for_timeout(15000)
def find_verify():
    try:
        messages = page.locator(".message-container, [data-testid='message-view']").all()
        if messages:
            latest_msg = messages[-1]
            summary = latest_msg.locator(".message-header")
            if summary.count() > 0 and "is-expanded" not in (summary.get_attribute("class") or ""):
                summary.click()
                page.wait_for_timeout(2000)
    except Exception as e:
        print(f"Failed to expand latest thread message: {e}")

    links = page.locator("a[href*='cloudflare.com/email-verification']").all()
    for link in reversed(links):
        href = link.get_attribute("href")
        if href and "email-verification" in href:
            return html.unescape(href)
    for frame in page.frames:
        try:
            raw = html.unescape(frame.content())
            m = re.search(r'https://dash\.cloudflare\.com/email-verification\?[^\s"<>()]+', raw)
            if m:
                return m.group(0)
        except: pass
    return None

checked = set()
for attempt in range(15):
    page.wait_for_timeout(15000)

    page.keyboard.press("/")
    page.wait_for_timeout(4000)
    page.keyboard.type("cloudflare verify", delay=80)
    page.keyboard.press("Enter")
    page.wait_for_timeout(4000)
    page.keyboard.press("Escape")
    page.wait_for_timeout(10000)

    items = page.locator(".item-container")
    count = items.count()
    if count == 0:
        page.goto("https://mail.proton.me/u/1/inbox#filter=unread", timeout=60000)
        page.wait_for_timeout(10000)
        continue

    for i in range(min(count, 5)):
        subj = items.nth(i).text_content().strip()[:80]
        if subj not in checked:
            checked.add(subj)
            items.nth(i).click()
            page.wait_for_timeout(10000)

            link = find_verify()
            if link:
                print(f"VERIFY_URL:{link}")
                ctx.close()
                sys.exit(0)
            break

    if len(checked) >= count:
        checked.clear()

    page.goto("https://mail.proton.me/u/1/inbox#filter=unread", timeout=60000)
    page.wait_for_timeout(15000)

ctx.close()
print("VERIFY_URL:NOT_FOUND")
PY

# ── STEP 3: Verify + create Workers AI API token ──────────────────────────
cat > ~/cf_verify_token.py << 'PY'
import sys, re
from cloakbrowser import launch_persistent_context

verify_url, email, password, cred_path, profile = sys.argv[1:6]
ctx = launch_persistent_context(profile, headless=False, humanize=True, geoip=True)
p = ctx.pages[0] if ctx.pages else ctx.new_page()

def click_turnstile(page):
    for f in page.frames:
        if "challenges.cloudflare" in (f.url or ""):
            try:
                fb = f.frame_element().bounding_box()
                if fb and fb["width"] > 50:
                    page.mouse.click(fb["x"] + 30, fb["y"] + fb["height"] / 2)
                    return True
            except: pass
    return False

if verify_url and "cloudflare.com" in verify_url:
    p.goto(verify_url, timeout=60000)
    p.wait_for_timeout(5000)
    click_turnstile(p)
    p.wait_for_timeout(10000)

# Step 13-14: Workers AI API Quick Start
p.goto("https://dash.cloudflare.com/?to=/:account/workers-and-pages", timeout=60000)
p.wait_for_timeout(4000)
p.goto("https://dash.cloudflare.com/?to=/:account/ai/workers-ai/api-quick-start", timeout=60000)
p.wait_for_timeout(7000)

# Step 16-17: extract account ID from URL, fallback to page text
account_id = None
for m in re.findall(r'/([a-f0-9]{32})/', p.url):
    account_id = m
    break
if not account_id:
    try:
        txt = p.inner_text("body")
        for m in re.findall(r'/([a-f0-9]{32})/', txt):
            account_id = m
            break
    except: pass

# Step 19: click Create a Workers AI API Token
for label in ["Create a Workers AI API Token", "Create API token", "Workers AI API Token"]:
    try:
        btn = p.locator(f"button:has-text('{label}')").first
        if btn.is_visible(timeout=1000) and btn.is_enabled(timeout=500):
            btn.click()
            break
    except: pass
p.wait_for_timeout(3000)

# Step 21: click Create API Token
for label in ["Create API Token", "Create token"]:
    try:
        btn = p.locator(f"button:has-text('{label}')").first
        if btn.is_visible(timeout=1000) and btn.is_enabled(timeout=500):
            btn.click()
            break
    except: pass
p.wait_for_timeout(5000)

# Step 22: extract API token
api_key = None
for el in p.locator("pre, code, span, div, input").all():
    try:
        text = el.input_value() if el.evaluate("el => el.tagName.toLowerCase()") == 'input' else (el.inner_text() or "")
    except:
        text = el.inner_text() or ""
    for m in re.findall(r'(?:cf_|cfut_)[a-zA-Z0-9_-]{30,}', text):
        api_key = m
        break
    if api_key:
        break

# Step 23: click Finish
try:
    p.locator("button:has-text('Finish')").first.click()
except Exception:
    pass
p.wait_for_timeout(2000)

ctx.close()
# Step 24: export credentials
if api_key and account_id:
    with open(cred_path, "a") as f:
        f.write(f"\nEMAIL={email}\nPASSWORD={password}\nACCOUNT_ID={account_id}\nAPI_KEY={api_key}\n")
print(f"API_KEY:{api_key or 'NOT_FOUND'}", flush=True)
print(f"ACCOUNT_ID:{account_id or 'NOT_FOUND'}", flush=True)
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

  echo "=== Step 2: Check Proton inbox for verification ==="
  VURL=$(python3 ~/cf_proton_extract.py "$PROTON_USER" "$PROTON_PASS" "$EMAIL" "$PROTON_PROFILE" 2>&1 | grep '^VERIFY_URL:' | tail -1 | cut -d: -f2-)
  echo "  Link: ${VURL:0:80}..."
  if [ -z "$VURL" ] || [ "$VURL" = "NOT_FOUND" ]; then echo "Not found, retrying..."; continue; fi

  echo "=== Step 3: Verify + Create Workers AI API Token ==="
  STEP3_OUT=$(python3 ~/cf_verify_token.py "$VURL" "$EMAIL" "$PASSWORD" "$CRED" "$CF_PROFILE")
  STEP3_STATUS=$?
  echo "$STEP3_OUT"
  if [ $STEP3_STATUS -ne 0 ]; then echo "Verify/token step failed, retrying..."; continue; fi
  API_KEY=$(echo "$STEP3_OUT" | grep '^API_KEY:' | tail -1 | cut -d: -f2-)
  if [ -z "$API_KEY" ] || [ "$API_KEY" = "NOT_FOUND" ]; then echo "API key not found, retrying from step 1..."; continue; fi

  echo "Done! Saved to $CRED"
  exit 0
done

echo "FAILED: 3 attempts exhausted"
exit 1