#!/bin/bash
# openrouter_signup_integrated.sh — OpenRouter signup with continuous CF bypass
# Single persistent browser + shared bypass server = 1 Chromium, 1 CF cache
set -eo pipefail
export DISPLAY=:1
cd /home/runner/workspace
mkdir -p logs

# === Config ===
CF_BYPASS_SERVER="${CF_BYPASS_SERVER:-http://localhost:8000}"
CRED="/home/runner/workspace/credentials/openrouter_credentials.txt"
PROFILE="/home/runner/workspace/or_profile"
PROTON_PROFILE="/home/runner/workspace/proton_profile"
mkdir -p "$PROFILE" "$PROTON_PROFILE"

# === Wait for bypass server ===
echo "Waiting for CloudflareBypass server at $CF_BYPASS_SERVER ..."
for i in $(seq 1 30); do
  if curl -sf "$CF_BYPASS_SERVER/cache/stats" > /dev/null 2>&1; then
    echo "  Server ready."
    break
  fi
  if [ "$i" -eq 30 ]; then
    echo "ERROR: Server not responding. Start it first:"
    echo "  cd /home/runner/workspace/CloudflareBypassForScraping && python server.py --port 8000"
    exit 1
  fi
  sleep 1
done

# === Get credentials ===
source <(python3 -c "import importlib.util; s=importlib.util.spec_from_file_location('c','$HOME/config.py'); m=importlib.util.module_from_spec(s); s.loader.exec_module(m); print(f'export PROTON_USER={m.PROTON_USERNAME}'); print(f'export PROTON_PASS={m.PROTON_PASSWORD}')")
EMAIL=$(bash scripts/email.sh 2>/dev/null | tail -1 | tr -d '[:space:]')
PASSWORD=$(python3 -c "import secrets,string; c=string.ascii_letters+string.digits+'!@#%'; print(secrets.choice(string.ascii_letters)+secrets.choice(string.digits)+secrets.choice('!@#%')+''.join(secrets.choice(c) for _ in range(12)))")
echo "Email: $EMAIL"

# === Single Python script: one browser, all steps ===
cat > ~/or_integrated.py << 'PYEOF'
import sys, re, time, asyncio, os, urllib.request, urllib.parse

CF_SERVER = os.environ.get("CF_BYPASS_SERVER", "http://localhost:8000")
EMAIL = sys.argv[1]
PASSWORD = sys.argv[2]
PROTON_USER = os.environ["PROTON_USER"]
PROTON_PASS = os.environ["PROTON_PASS"]
CRED_PATH = os.environ.get("CRED", "/home/runner/workspace/credentials/openrouter_credentials.txt")
OR_PROFILE = os.environ.get("OR_PROFILE", "/home/runner/workspace/or_profile")

def warm_cookies(hostname):
    """Ask bypass server to warm cookies for a host (uses cache if available)."""
    req = urllib.request.Request(f"{CF_SERVER}/")
    req.add_header("x-hostname", hostname)
    try:
        resp = urllib.request.urlopen(req, timeout=60)
        return resp.status
    except urllib.error.HTTPError:
        return 0
    except:
        return 0

async def main():
    from cloakbrowser import launch_persistent_context_async

    # === ONE browser for the entire flow ===
    print("Launching single persistent browser...", flush=True)
    ctx = await launch_persistent_context_async(OR_PROFILE, headless=False, humanize=True,
                                                args=["--enable-blink-features=FakeShadowRoot"])
    page = ctx.pages[0] if ctx.pages else await ctx.new_page()
    page.set_default_timeout(60000)

    # ============================================================
    # STEP 1: Pre-warm CF cookies for OpenRouter
    # ============================================================
    print("\n=== STEP 1: Pre-warm CF cookies ===", flush=True)
    warm_cookies("openrouter.ai")
    await asyncio.sleep(2)

    # ============================================================
    # STEP 2: Signup on OpenRouter
    # ============================================================
    print("\n=== STEP 2: Signup ===", flush=True)
    await page.goto("https://openrouter.ai/sign-up", wait_until="domcontentloaded", timeout=60000)
    await page.wait_for_timeout(3000)

    # Handle challenge if still present
    title = await page.title()
    if "just a moment" in title.lower():
        print("  Challenge detected — waiting...", flush=True)
        for _ in range(6):
            await page.wait_for_timeout(5000)
            title = await page.title()
            if "just a moment" not in title.lower():
                break
            # Try Turnstile click
            for frame in page.frames:
                if "challenges.cloudflare" in (frame.url or ""):
                    try:
                        info = await frame.evaluate("""() => {
                            function find(root){
                                if(!root) return null;
                                const d = root.querySelector && root.querySelector('input[type=checkbox]');
                                if(d) return d;
                                for(const el of (root.querySelectorAll ? root.querySelectorAll('*') : [])){
                                    const sr = el.fakeShadowRoot || el.shadowRoot;
                                    if(sr){ const r = find(sr); if(r) return r; }
                                }
                                return null;
                            }
                            const cb = find(document);
                            if(!cb) return {found:false};
                            const r = cb.getBoundingClientRect();
                            return {found:true, checked:cb.checked, x:r.x+r.width/2, y:r.y+r.height/2};
                        }""")
                        if info.get("found") and not info.get("checked"):
                            el = await frame.frame_element()
                            box = await el.bounding_box()
                            if box:
                                await page.mouse.click(box["x"]+info["x"], box["y"]+info["y"])
                                print("  Turnstile clicked", flush=True)
                    except:
                        pass
                    break

    # Fill form
    print("  Filling signup form...", flush=True)
    try:
        await page.locator("#emailAddress-field").wait_for(state="visible", timeout=15000)
        await page.locator("#emailAddress-field").fill(EMAIL)
        await page.locator("#password-field").fill(PASSWORD)
        legal = page.locator("#legalAccepted-field")
        if not await legal.is_checked():
            await legal.check(force=True)
        await page.wait_for_timeout(300)
        await page.get_by_role("button", name="Continue").click()
        await page.wait_for_timeout(8000)
    except Exception as e:
        print(f"  Form issue: {e}", flush=True)

    # Check signup result
    await page.wait_for_timeout(3000)
    cur_url = page.url
    body_text = await page.inner_text("body")
    signup_ok = ("confirm-email" in cur_url or "verification" in body_text.lower()
                 or "check your" in body_text.lower())
    if signup_ok:
        print("  SUCCESS: Signup complete", flush=True)
    else:
        print(f"  URL: {cur_url}", flush=True)
        print(f"  Body: {body_text[:300]}", flush=True)

    # ============================================================
    # STEP 3: Check Proton inbox (same browser, navigate)
    # ============================================================
    print("\n=== STEP 3: Check Proton inbox ===", flush=True)
    await page.goto("https://account.proton.me/login", wait_until="domcontentloaded", timeout=60000)
    await page.wait_for_timeout(3000)

    # Login if needed
    already = False
    try:
        if await page.locator("a:has-text('Mail')").is_visible(timeout=3000):
            already = True
    except:
        pass

    if not already:
        try:
            await page.locator("#username").fill(PROTON_USER)
            await page.locator("#password").fill(PROTON_PASS)
            await page.locator("button[type='submit']").click()
            await page.wait_for_timeout(10000)
        except Exception as e:
            print(f"  Proton login issue: {e}", flush=True)

    # Open Mail
    try:
        await page.locator("a:has-text('Mail')").first.click(timeout=5000)
        await page.wait_for_timeout(5000)
    except:
        pass

    # Search for verification email
    verify_url = None
    for attempt in range(1, 6):
        print(f"  Inbox search {attempt}/5...", flush=True)
        try:
            await page.keyboard.press("/")
            await page.wait_for_timeout(1000)
            await page.keyboard.type(EMAIL, delay=50)
            await page.keyboard.press("Enter")
            await page.wait_for_timeout(5000)
            latest = page.locator(".item-container").first
            if await latest.is_visible(timeout=5000):
                await latest.click()
                await page.wait_for_timeout(5000)
                # Extract verify link from frames
                for frame in page.frames:
                    try:
                        html = await frame.content()
                        matches = re.findall(r'https://clerk\.openrouter\.ai/v1/verify[^\s"\'<>]+', html)
                        if not matches:
                            matches = re.findall(r'https://openrouter\.ai[^\s"\'<>]*(?:verify|confirm|token)[^\s"\'<>]+', html)
                        if matches:
                            verify_url = matches[0].replace('&amp;', '&')
                            break
                    except:
                        pass
                if not verify_url:
                    for link in await page.query_selector_all("a[href]"):
                        href = await link.get_attribute("href")
                        if href and ("verify" in href or "confirm" in href) and "openrouter" in href:
                            verify_url = href
                            break
                if verify_url:
                    print(f"  FOUND: {verify_url[:60]}...", flush=True)
                    break
        except:
            pass
        if attempt < 5:
            await page.keyboard.press("Escape")
            await page.wait_for_timeout(3000)

    if not verify_url:
        print("  Verification email NOT FOUND", flush=True)
        await ctx.close()
        sys.exit(1)

    # ============================================================
    # STEP 4: Verify + get API key (same browser)
    # ============================================================
    print("\n=== STEP 4: Verify email + get API key ===", flush=True)

    # Pre-warm cookies for the verify domain
    parsed = urllib.parse.urlparse(verify_url)
    warm_cookies(parsed.netloc)
    await asyncio.sleep(1)

    await page.goto(verify_url, wait_until="domcontentloaded", timeout=30000)
    await page.wait_for_timeout(5000)

    # Click Individual if on OpenRouter
    if "openrouter.ai" in page.url:
        try:
            await page.get_by_text("Individual", exact=False).first.click()
            await page.wait_for_timeout(5000)
        except:
            pass

    # Wait longer for API key to render (it loads after auth + redirect)
    await page.wait_for_timeout(10000)

    # Debug: log current URL and body snippet
    print(f"  Verify URL: {page.url}", flush=True)
    try:
        body_debug = await page.inner_text("body")
        print(f"  Body (first 500): {body_debug[:500]}", flush=True)
    except:
        pass

    # Extract API key — try multiple strategies
    api_key = None

    # Strategy 1: <code> block
    try:
        code_text = await page.locator("code").inner_text(timeout=5000)
        m = re.search(r"sk-or-v1-[a-zA-Z0-9]+", code_text)
        if m:
            api_key = m.group(0)
    except:
        pass

    # Strategy 2: Copy button + clipboard
    if not api_key:
        try:
            await page.locator('button:has-text("Copy")').first.click()
            await page.wait_for_timeout(1500)
            clipboard = await page.evaluate("navigator.clipboard.readText()")
            m = re.search(r"sk-or-v1-[a-zA-Z0-9]+", clipboard or "")
            if m:
                api_key = m.group(0)
        except:
            pass

    # Strategy 3: Full page HTML
    if not api_key:
        content = await page.content()
        m = re.search(r"sk-or-v1-[a-zA-Z0-9]{20,}", content)
        if m:
            api_key = m.group(0)

    # Strategy 4: Look for the key pattern in any visible text
    if not api_key:
        try:
            all_text = await page.inner_text("body")
            m = re.search(r"sk-or-v1-[a-zA-Z0-9]{20,}", all_text)
            if m:
                api_key = m.group(0)
        except:
            pass

    # Strategy 5: Check iframes for the key
    if not api_key:
        for frame in page.frames:
            try:
                frame_text = await frame.inner_text("body")
                m = re.search(r"sk-or-v1-[a-zA-Z0-9]{20,}", frame_text)
                if m:
                    api_key = m.group(0)
                    break
            except:
                pass

    # If key not found, retry the verify page once
    if not api_key:
        print("  Key not found — retrying verify page...", flush=True)
        await page.goto(verify_url, wait_until="domcontentloaded", timeout=30000)
        await page.wait_for_timeout(15000)
        if "openrouter.ai" in page.url:
            try:
                await page.get_by_text("Individual", exact=False).first.click()
                await page.wait_for_timeout(5000)
            except:
                pass
        await page.wait_for_timeout(10000)
        content = await page.content()
        m = re.search(r"sk-or-v1-[a-zA-Z0-9]{20,}", content)
        if m:
            api_key = m.group(0)

    # Save
    with open(CRED_PATH, "a") as f:
        f.write(f"EMAIL={EMAIL}\nPASSWORD={PASSWORD}\nAPI_KEY={api_key or 'NOT_FOUND'}\n")

    print(f"\n  API Key: {api_key or 'NOT_FOUND'}", flush=True)
    print(f"  Saved to: {CRED_PATH}", flush=True)

    await ctx.close()
    print("\nDone!", flush=True)

asyncio.run(main())
PYEOF

echo "Running integrated signup (single browser)..."
PROTON_USER="$PROTON_USER" PROTON_PASS="$PROTON_PASS" \
CF_BYPASS_SERVER="$CF_BYPASS_SERVER" \
OR_PROFILE="$OR_PROFILE" PROTON_PROFILE="$PROTON_PROFILE" \
CRED="$CRED" \
python3 ~/or_integrated.py "$EMAIL" "$PASSWORD"

echo "Done! Credentials:"
cat "$CRED"
