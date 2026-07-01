#!/bin/bash
# firecrawl_signup.sh — Firecrawl signup + verify + extract API key
set -eo pipefail
export DISPLAY=:1
cd /home/runner/workspace
mkdir -p proton_profile credentials

bash scripts/email.sh > /dev/null 2>&1
EMAIL=$(bash scripts/email.sh 2>/dev/null | tail -1 | tr -d '[:space:]')
source <(python3 -c "import importlib.util; s=importlib.util.spec_from_file_location('c','$HOME/config.py'); m=importlib.util.module_from_spec(s); s.loader.exec_module(m); print(f'export PROTON_USER={m.PROTON_USERNAME}'); print(f'export PROTON_PASS={m.PROTON_PASSWORD}')")
PASSWORD=$(python3 -c "import secrets,string; c=string.ascii_letters+string.digits+'!@#%'; print(secrets.choice(string.ascii_letters)+secrets.choice(string.digits)+secrets.choice('!@#%')+''.join(secrets.choice(c) for _ in range(12)))")
CRED="/home/runner/workspace/credentials/firecrawl_credentials.txt"
echo "Email: $EMAIL"

cat > ~/fc_signup.py << 'PY'
import sys
from cloakbrowser import launch_persistent_context
import tempfile, atexit, shutil
email, password = sys.argv[1], sys.argv[2]
td = tempfile.mkdtemp()
atexit.register(lambda: shutil.rmtree(td, ignore_errors=True))
ctx = launch_persistent_context(td, headless=False, humanize=True)
p = ctx.pages[0] if ctx.pages else ctx.new_page()
p.goto("https://www.firecrawl.dev/signin", wait_until="domcontentloaded", timeout=60000)
p.wait_for_timeout(3000)
try: p.click("text=Sign Up")
except: pass
p.wait_for_timeout(2000)
p.locator('input[type="email"]').fill(email)
p.locator('input[type="password"]').fill(password)
p.get_by_role("button", name="Create Account").click()
p.wait_for_timeout(10000)
print(f"Signup URL: {p.url}")
ctx.close()
PY

cat > ~/fc_proton.py << 'PY'
import sys, re, time
from cloakbrowser import launch_persistent_context
PROTON_USER, PROTON_PASS, SIGNUP_EMAIL = sys.argv[1], sys.argv[2], sys.argv[3]
td = sys.argv[4] if len(sys.argv) > 4 else None
ctx = launch_persistent_context("/home/runner/workspace/proton_profile", headless=False) if td else launch_persistent_context("/home/runner/workspace/proton_profile", headless=False)
page = ctx.pages[0] if ctx.pages else ctx.new_page()
page.goto("https://mail.proton.me/u/0/inbox", timeout=60000)
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
            html = frame.content()
            m = re.findall(r'https://[^\s"\'<>,]*firecrawl[^\s"\'<>,]*verify[^\s"\'<>,]*', html)
            if m: return m[0].replace("&amp;", "&")
        except: pass
    for link in page.query_selector_all("a[href]"):
        href = link.get_attribute("href")
        if href and "verify" in href and "firecrawl" in href: return href
    return None
checked = set()
for attempt in range(15):
    page.wait_for_timeout(10000)
    page.keyboard.press("/")
    page.wait_for_timeout(1000)
    page.keyboard.type("firecrawl signup", delay=80)
    page.keyboard.press("Enter")
    page.wait_for_timeout(1000)
    page.keyboard.press("Escape")
    page.wait_for_timeout(5000)
    items = page.locator(".item-container")
    count = items.count()
    if count == 0:
        page.goto("https://mail.proton.me/u/0/inbox", timeout=60000)
        page.wait_for_timeout(5000)
        continue
    # Click latest unchecked email
    for i in range(min(count, 5)):
        subj = items.nth(i).text_content().strip()[:80]
        if subj not in checked:
            checked.add(subj)
            items.nth(i).click()
            page.wait_for_timeout(4000)
            link = find_verify()
            if link:
                print(f"VERIFY_URL:{link}")
                ctx.close(); sys.exit(0)
            # No verify in this one — try next
            break
    # All shown emails checked, reload for new ones
    if len(checked) >= count:
        checked.clear()
    page.goto("https://mail.proton.me/u/0/inbox", timeout=60000)
    page.wait_for_timeout(5000)
ctx.close()
print("VERIFY_URL:NOT_FOUND")
PY

cat > ~/fc_verify.py << 'PY'
import sys, re, time
from cloakbrowser import launch_persistent_context
from playwright._impl._errors import TargetClosedError
import tempfile, atexit, shutil
verify_url, email, password, cred_path = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
td = tempfile.mkdtemp()
atexit.register(lambda: shutil.rmtree(td, ignore_errors=True))
ctx = launch_persistent_context(td, headless=False, humanize=True)
p = ctx.pages[0] if ctx.pages else ctx.new_page()
p.goto(verify_url, timeout=30000)
time.sleep(5)
# Use newest tab if verify opened one
if len(ctx.pages) > 1:
    p = ctx.pages[-1]
api_key = None
for i in range(40):
    try:
        url = p.url
        # Login if on signin page
        if "/signin" in url or "/login" in url:
            print(f"Logging in at: {url}")
            p.goto("https://www.firecrawl.dev/signin?view=signin")
            time.sleep(2)
            p.locator('input[type="email"]').fill(email)
            p.locator('input[type="password"]').fill(password)
            p.get_by_role("button", name="Sign In").click()
            time.sleep(5)
            continue
        if "firecrawl.dev" in url and "/verify" not in url:
            print(f"Dashboard: {url}")
            if "/api-keys" not in url:
                p.goto("https://www.firecrawl.dev/app", wait_until="domcontentloaded", timeout=30000)
                time.sleep(5)
            for sel in ["button:has(.lucide-eye)", "button:has(.lucide-eye-off)", '[aria-label="Copy"]']:
                try:
                    p.click(sel); time.sleep(2)
                    txt = p.locator("text=fc-").first.text_content(timeout=3000).strip()
                    if txt.startswith("fc-"): api_key = txt; break
                except: pass
            if not api_key:
                try:
                    m = re.findall(r"fc-[a-zA-Z0-9]{20,}", p.content())
                    if m: api_key = max(m, key=len)
                except: pass
        if api_key: break
    except TargetClosedError: break
    except: pass
    time.sleep(2)
ctx.close()
with open(cred_path, "a") as f:
    f.write(f"EMAIL={email}\nPASSWORD={password}\nAPI_KEY={api_key or 'NOT_FOUND'}\n")
print(f"API Key: {api_key or 'NOT_FOUND'}")
PY

for ATTEMPT in 1 2 3; do
  [ "$ATTEMPT" -gt 1 ] && {
    EMAIL=$(bash scripts/email.sh 2>/dev/null | tail -1 | tr -d '[:space:]')
    PASSWORD=$(python3 -c "import secrets,string; c=string.ascii_letters+string.digits+'!@#%'; print(secrets.choice(string.ascii_letters)+secrets.choice(string.digits)+secrets.choice('!@#%')+''.join(secrets.choice(c) for _ in range(12)))")
    echo "Retry: $EMAIL"
  }
  echo "Step 2: Signup..."
  python3 ~/fc_signup.py "$EMAIL" "$PASSWORD" || continue
  echo "Step 3: Checking inbox..."
  VURL=$(python3 ~/fc_proton.py "$PROTON_USER" "$PROTON_PASS" "$EMAIL" ~/proton_profile 2>/dev/null | grep '^VERIFY_URL:' | head -1 | cut -d: -f2-)
  [ -z "$VURL" ] || [ "$VURL" = "NOT_FOUND" ] && { echo "Not found, retrying..."; continue; }
  echo "Found: ${VURL:0:60}..."
  echo "Step 4: Verifying..."
  python3 ~/fc_verify.py "$VURL" "$EMAIL" "$PASSWORD" "$CRED"
  echo "Done! Saved to $CRED"
  exit 0
done
echo "FAILED: 3 attempts exhausted"; exit 1
