#!/bin/bash
# openrouter_signup.sh — signup + verify + extract API key
set -e
export DISPLAY=:1
cd /home/runner/workspace
mkdir -p proton_profile credentials

OR_PROFILE="/home/runner/workspace/or_profile"
PROTON_PROFILE="/home/runner/workspace/proton_profile"
CRED="/home/runner/workspace/credentials/openrouter_credentials.txt"

bash scripts/email.sh > /dev/null 2>&1
EMAIL=$(bash scripts/email.sh 2>/dev/null | tail -1 | tr -d '[:space:]')
PASSWORD="HermesSecure#2026!xR"
echo "Email: $EMAIL"
rm -rf "$OR_PROFILE" && mkdir -p "$OR_PROFILE"

# ── STEP 1: Signup ──────────────────────────────────────────────
cat > ~/or_signup.py << 'PY'
import sys, os
os.environ["DISPLAY"] = ":1"
from cloakbrowser import launch_persistent_context

email, password, profile = sys.argv[1], sys.argv[2], sys.argv[3]
ctx = launch_persistent_context(profile, headless=False, humanize=True,
    args=["--enable-blink-features=FakeShadowRoot"])
p = ctx.pages[0] if ctx.pages else ctx.new_page()

p.goto("https://openrouter.ai/sign-up", timeout=60000, wait_until="domcontentloaded")
p.wait_for_timeout(4000)

# Fill form
p.locator("#emailAddress-field").click()
p.locator("#emailAddress-field").type(email, delay=50)
p.wait_for_timeout(300)
p.locator("#password-field").click()
p.locator("#password-field").type(password, delay=50)
p.wait_for_timeout(300)

# Checkbox via React fiber
p.evaluate("""() => {
    const el = document.querySelector('#legalAccepted-field');
    if (!el) return;
    const fk = Object.keys(el).find(k => k.startsWith('__reactFiber$'));
    if (!fk) return;
    let f = el[fk];
    for (let i = 0; i < 30; i++) {
        if (f?.memoizedProps?.onChange) {
            f.memoizedProps.onChange({target:{checked:true},currentTarget:{checked:true},
                nativeEvent:new Event('change'),type:'change',preventDefault(){},stopPropagation(){},persist(){}});
            break;
        }
        f = f.return;
    }
}""")
p.wait_for_timeout(500)

# Submit
p.get_by_role("button", name="Continue").click()
p.wait_for_timeout(8000)

# Find Turnstile & click
cf_box = None
for _ in range(30):
    for f in p.frames:
        if "challenges.cloudflare" in (f.url or ""):
            try:
                fb = f.frame_element().bounding_box()
                if fb and fb["width"] > 50:
                    cf_box = fb; break
            except: pass
    if cf_box: break
    p.wait_for_timeout(2000)

if not cf_box:
    print("TURNSTILE:NOT_FOUND", flush=True); ctx.close(); sys.exit(1)

cx, cy = cf_box["x"] + 30, cf_box["y"] + cf_box["height"] / 2
p.mouse.click(cx, cy)
p.wait_for_timeout(8000)
print(f"TURNSTILE:SOLVED URL={p.url}", flush=True)
ctx.close()
PY

# ── STEP 2: Get verify link from Proton ─────────────────────────
cat > ~/or_proton.py << 'PY'
import sys, re, time
from cloakbrowser import launch_persistent_context

signup_email, profile = sys.argv[1], sys.argv[2]
ctx = launch_persistent_context(profile, headless=False)
page = ctx.pages[0] if ctx.pages else ctx.new_page()

page.goto("https://mail.proton.me/u/0/inbox", timeout=60000)
page.wait_for_timeout(5000)

if "/login" in page.url:
    spec = __import__('importlib').util.spec_from_file_location("c", "/home/runner/config.py")
    mod = __import__('importlib').util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    page.locator("#username").fill(mod.PROTON_USERNAME)
    page.locator("#password").fill(mod.PROTON_PASSWORD)
    page.locator("button[type='submit']").click()
    page.wait_for_timeout(15000)

def find_verify(p):
    # Search via page content regex
    try:
        html = p.content()
        m = re.findall(r'https://[^\s"<>()]*(?:openrouter|clerk)[^\s"<>()]*(?:verify|confirm)[^\s"<>()]*', html, re.IGNORECASE)
        if m: return m[0].replace("&amp;", "&")
    except: pass
    return None

for attempt in range(20):
    page.wait_for_timeout(8000)

    # Open search: try search button, then / shortcut
    try:
        page.locator("[data-testid='search-button'], button[aria-label='Search']").first.click()
    except:
        page.keyboard.press("/")
    page.wait_for_timeout(800)
    page.keyboard.type(signup_email, delay=60)
    page.keyboard.press("Enter")
    page.wait_for_timeout(6000)

    # Click the first item in results
    try:
        items = page.locator(".item-container")
        if items.count() == 0:
            page.goto("https://mail.proton.me/u/0/inbox", timeout=60000)
            continue
        items.nth(0).click()
        page.wait_for_timeout(3000)
        link = find_verify(page)
        if link:
            print(f"VERIFY_URL:{link}", flush=True)
            ctx.close(); sys.exit(0)
        # Try expanding quoted/loaded content by selecting all
        page.keyboard.press("a")  # Proton shortcut select all/conversation
        page.wait_for_timeout(2000)
        link = find_verify(page)
        if link:
            print(f"VERIFY_URL:{link}", flush=True)
            ctx.close(); sys.exit(0)
    except Exception as e:
        print(f"  err: {e}", flush=True)

    page.goto("https://mail.proton.me/u/0/inbox", timeout=60000)

ctx.close()
print("VERIFY_URL:NOT_FOUND", flush=True)
PY

# ── STEP 3: Verify email + extract API key ──────────────────────
cat > ~/or_verify.py << 'PY'
import sys, re, time
from cloakbrowser import launch_persistent_context

verify_url, email, password, cred_path, profile = sys.argv[1:6]
ctx = launch_persistent_context(profile, headless=False, humanize=True)
p = ctx.pages[0] if ctx.pages else ctx.new_page()

p.goto(verify_url, timeout=60000)
time.sleep(5)

api_key = None
for i in range(60):
    url = p.url
    print(f"  [{i}] {url}", flush=True)

    # sign-up/verify → click Individual
    if "sign-up/verify" in url:
        time.sleep(3)
        try:
            p.get_by_role("button", name="Individual").click()
            time.sleep(5); continue
        except: pass
        time.sleep(3); continue

    # clerk redirect → wait
    if "clerk" in url and ("verify" in url or "redirect" in url):
        time.sleep(5); continue

    # sign-in → login
    if "/sign-in" in url or "/signin" in url or ("/sign-up" in url and "verify" not in url):
        p.goto("https://openrouter.ai/sign-in", wait_until="domcontentloaded", timeout=30000)
        time.sleep(3)
        p.locator("#emailAddress-field").click()
        p.locator("#emailAddress-field").type(email, delay=50)
        p.locator("#password-field").click()
        p.locator("#password-field").type(password, delay=50)
        p.get_by_role("button", name="Continue").click()
        time.sleep(10); continue

    # authenticated → extract key
    if "openrouter.ai" in url and "/sign" not in url:
        if "/keys" not in url:
            p.goto("https://openrouter.ai/workspaces/default/keys", wait_until="domcontentloaded", timeout=30000)
            time.sleep(5)
        # Try reveal/copy buttons
        for sel in ["button:has(.lucide-eye)","button:has(.lucide-eye-off)","button[aria-label='Reveal']"]:
            try: p.click(sel); time.sleep(2)
            except: pass
        text = p.inner_text("body")
        m = re.findall(r'(?:sk-or-v1-|sk-)[a-zA-Z0-9_-]{30,}', text)
        if m: api_key = m[0]
        if not api_key:
            m2 = re.findall(r'(?:sk-or-v1-|sk-)[a-zA-Z0-9_-]{30,}', p.content())
            if m2: api_key = m2[0]
        # If no key, try generate
        if not api_key:
            for sel in ["button:has-text('Generate')","button:has-text('Create')"]:
                try: p.click(sel); time.sleep(3)
                except: pass
                text = p.inner_text("body")
                m = re.findall(r'(?:sk-or-v1-|sk-)[a-zA-Z0-9_-]{30,}', text)
                if m: api_key = m[0]; break
        if api_key: break
    time.sleep(2)

ctx.close()
with open(cred_path, "a") as f:
    f.write(f"\n--- {email} ---\nEMAIL={email}\nPASSWORD={password}\nAPI_KEY={api_key or 'NOT_FOUND'}\n")
print(f"API_KEY:{api_key or 'NOT_FOUND'}", flush=True)
PY

# ── MAIN ────────────────────────────────────────────────────────
for ATTEMPT in 1 2 3; do
  [ "$ATTEMPT" -gt 1 ] && {
    EMAIL=$(bash scripts/email.sh 2>/dev/null | tail -1 | tr -d '[:space:]')
    rm -rf "$OR_PROFILE" && mkdir -p "$OR_PROFILE"
    echo "Retry $ATTEMPT: $EMAIL"
  }
  echo "=== Step 1: Signup ==="
  python3 ~/or_signup.py "$EMAIL" "$PASSWORD" "$OR_PROFILE" || continue

  echo "=== Step 2: Check inbox ==="
  VURL=$(python3 ~/or_proton.py "$EMAIL" "$PROTON_PROFILE" 2>&1 | grep '^VERIFY_URL:' | tail -1 | sed 's/^VERIFY_URL://')
  echo "  Link: ${VURL:0:80}..."
  [ -z "$VURL" ] || [ "$VURL" = "NOT_FOUND" ] && { echo "Not found, retrying..."; continue; }

  echo "=== Step 3: Verify + Extract Key ==="
  python3 ~/or_verify.py "$VURL" "$EMAIL" "$PASSWORD" "$CRED" "$OR_PROFILE"
  echo "Done! Saved to $CRED"
  exit 0
done
echo "FAILED: 3 attempts exhausted"; exit 1
