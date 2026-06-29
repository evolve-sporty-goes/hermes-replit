#!/bin/bash
# openrouter_signup.sh — OpenRouter signup + verify + extract API key
# Uses CloakBypasser (CloudflareBypassForScraping) for CF bypass + common profile
set -eo pipefail
export DISPLAY=:1
cd /home/runner/workspace
mkdir -p ~/or_profile proton_profile logs

bash scripts/email.sh > /dev/null 2>&1
EMAIL=$(bash scripts/email.sh 2>/dev/null | tail -1 | tr -d '[:space:]')
source <(python3 -c "import importlib.util; s=importlib.util.spec_from_file_location('c','$HOME/config.py'); m=importlib.util.module_from_spec(s); s.loader.exec_module(m); print(f'export PROTON_USER={m.PROTON_USERNAME}'); print(f'export PROTON_PASS={m.PROTON_PASSWORD}')")
PASSWORD=$(python3 -c "import secrets,string; c=string.ascii_letters+string.digits+'!@#%'; print(secrets.choice(string.ascii_letters)+secrets.choice(string.digits)+secrets.choice('!@#%')+''.join(secrets.choice(c) for _ in range(12)))")
CRED="/home/runner/workspace/credentials/openrouter_credentials.txt"
echo "Email: $EMAIL"

cat > ~/or_signup.py << 'PY'
import sys, re, time, asyncio, json
from cf_bypasser import CloakBypasser

email, password = sys.argv[1], sys.argv[2]
LOG = "/home/runner/workspace/logs/reqs_signup.json"

async def main():
    b = CloakBypasser(max_retries=5, log=True)
    # Step 1: Navigate to signup (CloakBypasser handles CF challenge)
    url = "https://openrouter.ai/sign-up"
    print(f"Navigating to {url}", flush=True)
    result = await b.get_or_generate_html(url)
    if not result:
        print("FAILED: Could not load signup page", flush=True)
        return False

    page = None
    # Re-launch with persistent context to interact
    from cloakbrowser import launch_persistent_context
    ctx = launch_persistent_context("/home/runner/workspace/or_profile", headless=False, humanize=True,
                                    args=["--enable-blink-features=FakeShadowRoot"])
    p = ctx.pages[0] if ctx.pages else ctx.new_page()
    p.set_default_timeout(60000)

    # Restore cookies from bypasser
    if result.get("cookies"):
        await ctx.cookies([{"name": n, "value": v, "url": url} for n, v in result["cookies"].items()])

    await p.goto(url, wait_until="domcontentloaded", timeout=60000)
    await p.wait_for_timeout(3000)

    # Check if we landed on the challenge or the signup form
    title = await p.title()
    html = await p.content()
    if "just a moment" in title.lower() or "please complete the captcha" in html.lower():
        print("Still on challenge page, waiting...", flush=True)
        await asyncio.sleep(10)
        html = await p.content()

    # Fill form via React fiber
    print("Filling signup form...", flush=True)
    await p.evaluate("""(vals) => {
        const { email_val, pass_val } = vals;
        const email = document.querySelector('#emailAddress-field');
        const pass = document.querySelector('#password-field');
        const cb = document.querySelector('#legalAccepted-field');
        const getFiber = (el) => {
            for (const key of Object.keys(el)) {
                if (key.startsWith('__reactFiber$') || key.startsWith('__reactInternalInstance$')) return el[key];
            }
            return null;
        };
        const setReactValue = (el, val, isCheckbox) => {
            const fiber = getFiber(el);
            if (!fiber) return false;
            let current = fiber;
            for (let i = 0; i < 20; i++) {
                if (current && current.memoizedProps && current.memoizedProps.onChange) {
                    current.memoizedProps.onChange(isCheckbox ? {
                        target: { checked: val, type: 'checkbox' },
                        currentTarget: { checked: val },
                        nativeEvent: new Event('change', { bubbles: true }),
                        type: 'change', preventDefault: function(){}, stopPropagation: function(){}, persist: function(){}
                    } : {
                        target: { value: val, name: el.name, type: el.type },
                        currentTarget: { value: val },
                        nativeEvent: new Event('input', { bubbles: true }),
                        type: 'change', preventDefault: function(){}, stopPropagation: function(){}, persist: function(){}
                    });
                    return true;
                }
                current = current.return;
            }
            return false;
        };
        setReactValue(email, email_val, false);
        setReactValue(pass, pass_val, false);
        cb.checked = true;
        setReactValue(cb, true, true);
        return 'VALUES_SET';
    }""", {"email_val": email, "pass_val": password})
    await p.wait_for_timeout(300)

    # Click Continue
    await p.evaluate("""() => {
        const btns = document.querySelectorAll('button');
        for (const b of btns) {
            if (b.textContent.trim() === 'Continue') { b.click(); return 'CLICKED'; }
        }
        return 'NO_BUTTON';
    }""")
    await p.wait_for_timeout(5000)

    # Wait for CF challenge resolution
    print("Waiting for Cloudflare...", flush=True)
    for i in range(30):
        # Try clicking Turnstile checkbox via FakeShadowRoot
        clicked = await p.evaluate("""() => {
            function find(root) {
                if (!root) return null;
                const direct = root.querySelector && root.querySelector('input[type=checkbox]');
                if (direct) return direct;
                for (const el of (root.querySelectorAll ? root.querySelectorAll('*') : [])) {
                    const sr = el.fakeShadowRoot || el.shadowRoot;
                    if (sr) { const r = find(sr); if (r) return r; }
                }
                return null;
            }
            // Check frames
            for (const frame of window.frames) {
                try {
                    const doc = frame.document;
                    const cb = find(doc);
                    if (cb && !cb.checked) {
                        cb.click();
                        return 'clicked_frame';
                    }
                } catch(e) {}
            }
            // Check main page
            const cb = find(document);
            if (cb && !cb.checked) {
                cb.click();
                return 'clicked_main';
            }
            return null;
        }""")
        if clicked:
            print(f"  Turnstile {clicked} (iter {i})", flush=True)
            await p.wait_for_timeout(3000)

        cur_url = p.url
        body = await p.inner_text("body")
        if "confirm-email" in cur_url or "verification" in body.lower() or "check your" in body.lower():
            print("SUCCESS: Signup complete", flush=True)
            await ctx.close()
            return True
        if "sign-up" not in cur_url and "openrouter.ai" in cur_url:
            print(f"Redirected: {cur_url}", flush=True)
            break
        await p.wait_for_timeout(1000)

    body = await p.inner_text("body")
    print(f"URL: {p.url}", flush=True)
    print(f"Body: {body[:400]}", flush=True)
    await ctx.close()
    return False

asyncio.run(main())
PY

cat > ~/or_proton.py << 'PY'
import sys, re, time, os
from cloakbrowser import launch_persistent_context
PROTON_USER, PROTON_PASS, SIGNUP_EMAIL = sys.argv[1], sys.argv[2], sys.argv[3]
ctx = launch_persistent_context("/home/runner/workspace/proton_profile", headless=False)
page = ctx.pages[0] if ctx.pages else ctx.new_page()
page.goto("https://account.proton.me/login", timeout=60000)
page.wait_for_timeout(3000)
already = False
try:
    if page.locator("a:has-text('Mail')").is_visible(timeout=3000):
        already = True
except: pass
if not already:
    page.locator("#username").fill(PROTON_USER)
    page.locator("#password").fill(PROTON_PASS)
    page.locator("button[type='submit']").click()
    page.wait_for_timeout(10000)
page.locator("a:has-text('Mail')").first.click(timeout=0)
page.wait_for_timeout(5000)
verify_url = None
for attempt in range(1, 6):
    print(f"Inbox search {attempt}/5 for {SIGNUP_EMAIL}", flush=True)
    try:
        page.keyboard.press("/")
        page.wait_for_timeout(1000)
        page.keyboard.type(SIGNUP_EMAIL, delay=50)
        page.keyboard.press("Enter")
        page.wait_for_timeout(5000)
        latest = page.locator(".item-container").first
        if latest.is_visible(timeout=5000):
            latest.click()
            page.wait_for_timeout(5000)
            for frame in page.frames:
                try:
                    html = frame.content()
                    matches = re.findall(r'https://clerk\.openrouter\.ai/v1/verify[^\s"\'<>]+', html)
                    if not matches:
                        matches = re.findall(r'https://openrouter\.ai[^\s"\'<>]*(?:verify|confirm|token)[^\s"\'<>]+', html)
                    if matches:
                        verify_url = matches[0].replace('&amp;', '&')
                        break
                except: pass
            if not verify_url:
                for link in page.query_selector_all("a[href]"):
                    href = link.get_attribute("href")
                    if href and ("verify" in href or "confirm" in href) and "openrouter" in href:
                        verify_url = href
                        break
            if verify_url:
                print(f"VERIFY_URL:{verify_url}", flush=True)
                sys.stdout.flush()
                ctx.close()
                os._exit(0)
    except: pass
    if attempt < 5:
        page.keyboard.press("Escape")
        page.wait_for_timeout(3000)
ctx.close()
print("VERIFY_URL:NOT_FOUND", flush=True)
PY

cat > ~/or_verify.py << 'PY'
import sys, re, time, asyncio
from cf_bypasser import CloakBypasser
from cloakbrowser import launch_persistent_context

verify_url, email, password, cred_path = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]

async def main():
    # Use CloakBypasser to navigate (handles CF on verify page)
    b = CloakBypasser(max_retries=5, log=True)
    result = await b.get_or_generate_html(verify_url)

    # Re-launch with common profile for interaction
    ctx = launch_persistent_context("/home/runner/workspace/or_profile", headless=False, humanize=True,
                                    args=["--enable-blink-features=FakeShadowRoot"])
    p = ctx.pages[0] if ctx.pages else ctx.new_page()
    p.set_default_timeout(60000)

    if result and result.get("cookies"):
        await ctx.cookies([{"name": n, "value": v, "url": verify_url} for n, v in result["cookies"].items()])

    await p.goto(verify_url, wait_until="domcontentloaded", timeout=30000)
    await p.wait_for_timeout(5000)

    # Click Individual if on OpenRouter
    if "openrouter.ai" in p.url:
        try:
            p.get_by_text("Individual", exact=False).first.click()
            await p.wait_for_timeout(3000)
        except: pass

    await p.wait_for_timeout(8000)

    # Extract API key
    api_key = None
    try:
        code_text = await p.locator("code").inner_text(timeout=5000)
        m = re.search(r"sk-or-v1-[a-zA-Z0-9]+", code_text)
        if m: api_key = m.group(0)
    except: pass
    if not api_key:
        try:
            await p.locator('button:has-text("Copy")').first.click()
            await p.wait_for_timeout(1500)
            clipboard = await p.evaluate("navigator.clipboard.readText()")
            m = re.search(r"sk-or-v1-[a-zA-Z0-9]+", clipboard or "")
            if m: api_key = m.group(0)
        except: pass
    if not api_key:
        content = await p.content()
        m = re.search(r"sk-or-v1-[a-zA-Z0-9]{20,}", content)
        if m: api_key = m.group(0)

    with open(cred_path, "a") as f:
        f.write(f"EMAIL={email}\nPASSWORD={password}\nAPI_KEY={api_key or 'NOT_FOUND'}\n")
    print(f"API Key: {api_key or 'NOT_FOUND'}")
    await ctx.close()

asyncio.run(main())
PY

for ATTEMPT in 1 2 3; do
  [ "$ATTEMPT" -gt 1 ] && {
    EMAIL=$(bash scripts/email.sh 2>/dev/null | tail -1 | tr -d '[:space:]')
    PASSWORD=$(python3 -c "import secrets,string; c=string.ascii_letters+string.digits+'!@#%'; print(secrets.choice(string.ascii_letters)+secrets.choice(string.digits)+secrets.choice('!@#%')+''.join(secrets.choice(c) for _ in range(12)))")
    echo "Retry: $EMAIL"
  }
  echo "Step 2: Signup..."
  python3 ~/or_signup.py "$EMAIL" "$PASSWORD" || continue
  echo "Step 3: Checking inbox..."
  VURL=$(python3 ~/or_proton.py "$PROTON_USER" "$PROTON_PASS" "$EMAIL" 2>/dev/null | grep '^VERIFY_URL:' | tail -1 | sed 's/^VERIFY_URL://')
  if [ -z "$VURL" ] || [ "$VURL" = "NOT_FOUND" ]; then echo "Not found, retrying..."; continue; fi
  echo "Found: ${VURL:0:60}..."
  echo "Step 4: Verifying + getting key..."
  python3 ~/or_verify.py "$VURL" "$EMAIL" "$PASSWORD" "$CRED"
  echo "Done! Saved to $CRED"
  exit 0
done
echo "FAILED: 3 attempts exhausted"; exit 1
