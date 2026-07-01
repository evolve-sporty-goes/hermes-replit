#!/bin/bash
# openrouter_signup.sh — signup + verify + extract API key
set -e
export DISPLAY=:1
cd /home/runner/workspace
mkdir -p proton_profile credentials

OR_PROFILE="/home/runner/or_profile"
PROTON_PROFILE="/home/runner/workspace/proton_profile"
CRED="/home/runner/workspace/credentials/openrouter_credentials.txt"

bash scripts/email.sh > /dev/null 2>&1
EMAIL=$(bash scripts/email.sh 2>/dev/null | tail -1 | tr -d '[:space:]')

source <(python3 -c "import importlib.util; s=importlib.util.spec_from_file_location('c','$HOME/config.py'); m=importlib.util.module_from_spec(s); s.loader.exec_module(m); print(f'export PROTON_USER={m.PROTON_USERNAME}'); print(f'export PROTON_PASS={m.PROTON_PASSWORD}')")
PASSWORD=$(python3 -c "import secrets,string; c=string.ascii_letters+string.digits+'!@#%'; print(secrets.choice(string.ascii_letters)+secrets.choice(string.digits)+secrets.choice('!@#%')+''.join(secrets.choice(c) for _ in range(12)))")
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
p.wait_for_timeout(15000)
print(f"TURNSTILE:SOLVED URL={p.url}", flush=True)
ctx.close()
PY

# ── STEP 2: Get verify link from Proton ─────────────────────────
cat > ~/or_proton.py << 'PY'
import sys, re, time, html
from cloakbrowser import launch_persistent_context

PROTON_USER, PROTON_PASS, SIGNUP_EMAIL = sys.argv[1], sys.argv[2], sys.argv[3]
td = sys.argv[4] if len(sys.argv) > 4 else None

ctx = launch_persistent_context("/home/runner/workspace/proton_profile", headless=False)
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

    for frame in page.frames:
        try:
            raw_html = frame.content()
            if "clerk.openrouter.ai" in raw_html:
                clean_html = html.unescape(raw_html)
                matches = re.findall(r'https://clerk\.openrouter\.ai/v1/verify\?[^\s"<>()]+', clean_html)
                if matches:
                    return matches[0]
        except Exception as e:
            pass           

    try:
        links = page.locator("a[href*='clerk.openrouter.ai']").all()
        for link in reversed(links):
            href = link.get_attribute("href")
            if href and "verify" in href:
                return html.unescape(href)
    except Exception as e:
        pass

    return None

checked = set()
for attempt in range(15):
    page.wait_for_timeout(10000)

    page.keyboard.press("/")
    page.wait_for_timeout(1000)
    page.keyboard.type("openrouter sign up", delay=80)
    page.keyboard.press("Enter")
    page.wait_for_timeout(5000)

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

# ── STEP 3: Verify email + extract API key ──────────────────────
cat > ~/or_verify.py << 'PY'
import sys, re, time
from cloakbrowser import launch_persistent_context

verify_url, email, password, cred_path, profile = sys.argv[1:6]
ctx = launch_persistent_context(profile, headless=False, humanize=True)
ctx.grant_permissions(["clipboard-read", "clipboard-write"])
p = ctx.pages[0] if ctx.pages else ctx.new_page()

p.goto(verify_url, timeout=60000)
api_key = None

for i in range(60):
    url = p.url
    time.sleep(2)

    # Check explicitly for link expiration
    if any(status in url for status in (
        "verify?__clerk_status=expired",
        "verify?__clerk_status=client_mismatch",
    )):
        print("VERIFY_STATUS:EXPIRED", flush=True)
        ctx.close()
        sys.exit(2)

    # Route 1: Onboarding / Select Individual
    if "sign-up/verify" in url or "onboarding" in url:
        p.goto("https://openrouter.ai/keys")
        p.wait_for_timeout(3000)
        for sel in ["button:has-text('Individual')", "div[role='button']:has-text('Individual')"]:
            try: p.locator(sel).first.click(); break
            except: pass
        # Strategy A: Scan token-flattened text elements
        for el in p.locator("pre, code, span, div[class*='code']").all():
            m = re.search(r'(?:sk-or-v1-|sk-)[a-zA-Z0-9_-]{30,}', el.inner_text())
            if m: api_key = m.group(0); break

        # Strategy B: Clipboard Fallback via Copy Button
        if not api_key:
            for sel in ["button:has(.lucide-copy)", "button[aria-label*='Copy']"]:
                try:
                    p.locator(sel).first.click()
                    m = re.search(r'(?:sk-or-v1-|sk-)[a-zA-Z0-9_-]{30,}', p.evaluate("navigator.clipboard.readText()"))
                    if m: api_key = m.group(0); break
                except: pass

        if api_key: break

ctx.close()
with open(cred_path, "a") as f:
    f.write(f"\nEMAIL={email}\nPASSWORD={password}\nAPI_KEY={api_key or 'NOT_FOUND'}\n")
print(f"API_KEY:{api_key or 'NOT_FOUND'}", flush=True)
PY

# ── MAIN ────────────────────────────────────────────────────────
# Temporarily disable 'set -e' context behavior inside loop evaluations
# so an exit code of 2 doesn't prematurely terminate the master script.
set +e

for ATTEMPT in 1 2 3; do
  if [ "$ATTEMPT" -gt 1 ]; then
    EMAIL=$(bash scripts/email.sh 2>/dev/null | tail -1 | tr -d '[:space:]')
    PASSWORD=$(python3 -c "import secrets,string; c=string.ascii_letters+string.digits+'!@#%'; print(secrets.choice(string.ascii_letters)+secrets.choice(string.digits)+secrets.choice('!@#%')+''.join(secrets.choice(c) for _ in range(12)))")
    rm -rf "$OR_PROFILE" && mkdir -p "$OR_PROFILE"
    echo "Retry $ATTEMPT: $EMAIL"
  fi

  echo "=== Step 1: Signup ==="
  python3 ~/or_signup.py "$EMAIL" "$PASSWORD" "$OR_PROFILE"
  if [ $? -ne 0 ]; then echo "Signup failed, retrying..."; continue; fi

  echo "=== Step 2: Check inbox ==="
  VURL=$(python3 ~/or_proton.py "$PROTON_USER" "$PROTON_PASS" "$EMAIL" ~/proton_profile 2>&1 | grep '^VERIFY_URL:' | head -1 | cut -d: -f2-)
  echo "  Link: ${VURL:0:80}..."
  if [ -z "$VURL" ] || [ "$VURL" = "NOT_FOUND" ]; then echo "Not found, retrying..."; continue; fi

  echo "=== Step 3: Verify + Extract Key ==="
  python3 ~/or_verify.py "$VURL" "$EMAIL" "$PASSWORD" "$CRED" "$OR_PROFILE"
  STATUS=$?

  if [ $STATUS -eq 2 ]; then
    echo "Verification link expired! Restarting step 1 context..."
    continue
  elif [ $STATUS -ne 0 ]; then
    echo "An unknown error occurred during verification, retrying..."
    continue
  fi

  echo "Done! Saved to $CRED"
  exit 0
done

echo "FAILED: 3 attempts exhausted"
exit 1