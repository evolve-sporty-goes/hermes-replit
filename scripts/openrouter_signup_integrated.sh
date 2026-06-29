#!/bin/bash
# openrouter_signup_integrated.sh — OpenRouter signup with continuous CF bypass
# Single persistent browser + CloakBypasser for inline CF solving
set -eo pipefail
export DISPLAY=:1
cd /home/runner/workspace
mkdir -p logs

CRED="/home/runner/workspace/credentials/openrouter_credentials.txt"
PROFILE="/home/runner/workspace/or_profile"
PROTON_PROFILE="/home/runner/workspace/proton_profile"
mkdir -p "$PROFILE" "$PROTON_PROFILE"

# === Get credentials ===
source <(python3 -c "import importlib.util; s=importlib.util.spec_from_file_location('c','$HOME/config.py'); m=importlib.util.module_from_spec(s); s.loader.exec_module(m); print(f'export PROTON_USER={m.PROTON_USERNAME}'); print(f'export PROTON_PASS={m.PROTON_PASSWORD}')")
EMAIL=$(bash scripts/email.sh 2>/dev/null | tail -1 | tr -d '[:space:]')
PASSWORD=$(python3 -c "import secrets,string; c=string.ascii_letters+string.digits+'!@#%'; print(secrets.choice(string.ascii_letters)+secrets.choice(string.digits)+secrets.choice('!@#%')+''.join(secrets.choice(c) for _ in range(12)))")
echo "Email: $EMAIL"

# === Single Python script: one browser, all steps, inline CF bypass ===
cat > ~/or_integrated.py << 'PYEOF'
import sys, re, asyncio, os, json

EMAIL = sys.argv[1]
PASSWORD = sys.argv[2]
PROTON_USER = os.environ["PROTON_USER"]
PROTON_PASS = os.environ["PROTON_PASS"]
CRED_PATH = os.environ.get("CRED", "/home/runner/workspace/credentials/openrouter_credentials.txt")
OR_PROFILE = os.environ.get("OR_PROFILE", "/home/runner/workspace/or_profile")

async def main():
    from cloakbrowser import launch_persistent_context_async

    # === ONE browser for the entire flow ===
    print("Launching single persistent browser...", flush=True)
    ctx = await launch_persistent_context_async(OR_PROFILE, headless=False, humanize=True,
                                                args=["--enable-blink-features=FakeShadowRoot"])
    page = ctx.pages[0] if ctx.pages else await ctx.new_page()
    page.set_default_timeout(60000)

    # ============================================================
    # STEP 1: Pre-warm by loading openrouter through CloakBypasser
    # (solves CF challenge and caches cookies in the browser context)
    # ============================================================
    print("\n=== STEP 1: Pre-warm CF bypass ===", flush=True)
    from cf_bypasser import CloakBypasser
    b = CloakBypasser(max_retries=5, log=True)
    result = await b.get_or_generate_html("https://openrouter.ai/sign-up")
    if result and result.get("cookies"):
        # Inject solved cookies into persistent context
        await ctx.cookies([{"name": n, "value": v, "url": "https://openrouter.ai"}
                           for n, v in result["cookies"].items()])
        print(f"  Injected {len(result['cookies'])} cookies from bypass", flush=True)
    else:
        print("  WARNING: CF bypass failed, will handle inline", flush=True)

    # ============================================================
    # STEP 2: Signup on OpenRouter
    # ============================================================
    print("\n=== STEP 2: Signup ===", flush=True)
    await page.goto("https://openrouter.ai/sign-up", wait_until="domcontentloaded", timeout=60000)
    await page.wait_for_timeout(3000)

    # Handle challenge if still present
    title = await page.title()
    if "just a moment" in title.lower():
        print("  Challenge detected — waiting for auto-resolution...", flush=True)
        for _ in range(8):
            await page.wait_for_timeout(5000)
            title = await page.title()
            if "just a moment" not in title.lower():
                break
            # Try Turnstile click via FakeShadowRoot
            clicked = await page.evaluate("""() => {
                function find(root) {
                    if (!root) return null;
                    const d = root.querySelector && root.querySelector('input[type=checkbox]');
                    if (d) return d;
                    for (const el of (root.querySelectorAll ? root.querySelectorAll('*') : [])) {
                        const sr = el.fakeShadowRoot || el.shadowRoot;
                        if (sr) { const r = find(sr); if (r) return r; }
                    }
                    return null;
                }
                const frames = document.querySelectorAll('iframe');
                for (const iframe of frames) {
                    try {
                        const doc = iframe.contentDocument || iframe.contentWindow.document;
                        const cb = find(doc);
                        if (cb && !cb.checked) { cb.click(); return 'clicked_frame'; }
                    } catch(e) {}
                }
                const cb = find(document);
                if (cb && !cb.checked) { cb.click(); return 'clicked_main'; }
                return null;
            }""")
            if clicked:
                print(f"  Turnstile {clicked}", flush=True)

    # Fill form
    print("  Filling signup form...", flush=True)
    try:
        await page.locator("#emailAddress-field").wait_for(state="visible", timeout=15000)
        await page.locator("#emailAddress-field").fill(EMAIL)
        await page.locator("#password-field").fill(PASSWORD)

        # Legal checkbox — pure JS to avoid clicking hyperlinks
        print("  Checking legal checkbox...", flush=True)
        for attempt in range(3):
            cb_result = await page.evaluate("""() => {
                const cb = document.querySelector('#legalAccepted-field');
                if (!cb) return 'not_found';
                if (cb.checked) return 'already_checked';
                cb.checked = true;
                cb.dispatchEvent(new Event('change', { bubbles: true }));
                cb.dispatchEvent(new Event('input', { bubbles: true }));
                cb.dispatchEvent(new MouseEvent('click', { bubbles: true, cancelable: true }));
                return cb.checked ? 'checked' : 'failed';
            }""")
            print(f"  Checkbox attempt {attempt+1}: {cb_result}", flush=True)
            if cb_result in ('checked', 'already_checked'):
                break
            await page.wait_for_timeout(300)

        await page.wait_for_timeout(200)
        print("  Clicking Continue...", flush=True)
        await page.get_by_role("button", name="Continue").click()
    except Exception as e:
        print(f"  Form issue: {e}", flush=True)

    # After Continue: wait for CF challenge or confirm-email
    print("  Waiting for page to settle...", flush=True)
    await page.wait_for_timeout(5000)

    for _ in range(12):
        cur_url = page.url
        body = ""
        try:
            body = await page.inner_text("body")
        except:
            pass

        if "confirm-email" in cur_url or "verification" in body.lower() or "check your" in body.lower():
            print("  Signup confirmed!", flush=True)
            break

        # Try Turnstile
        clicked = await page.evaluate("""() => {
            function find(root) {
                if (!root) return null;
                const d = root.querySelector && root.querySelector('input[type=checkbox]');
                if (d) return d;
                for (const el of (root.querySelectorAll ? root.querySelectorAll('*') : [])) {
                    const sr = el.fakeShadowRoot || el.shadowRoot;
                    if (sr) { const r = find(sr); if (r) return r; }
                }
                return null;
            }
            const frames = document.querySelectorAll('iframe');
            for (const iframe of frames) {
                try {
                    const doc = iframe.contentDocument || iframe.contentWindow.document;
                    const cb = find(doc);
                    if (cb && !cb.checked) { cb.click(); return 'clicked_frame'; }
                } catch(e) {}
            }
            const cb = find(document);
            if (cb && !cb.checked) { cb.click(); return 'clicked_main'; }
            return null;
        }""")
        if clicked:
            print(f"  Turnstile {clicked}", flush=True)
            await page.wait_for_timeout(3000)
        else:
            await page.wait_for_timeout(2000)

    # ============================================================
    # STEP 3: Check Proton inbox (same browser)
    # ============================================================
    print("\n=== STEP 3: Check Proton inbox ===", flush=True)
    await page.goto("https://account.proton.me/login", wait_until="domcontentloaded", timeout=60000)
    await page.wait_for_timeout(3000)

    # Login if needed
    already = False
    try:
        if page.locator("a:has-text('Mail')").is_visible(timeout=3000):
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
                verify_url = None
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
                    links = await page.query_selector_all("a[href]")
                    for link in links:
                        href = await link.get_attribute("href")
                        if href and ("verify" in href or "confirm" in href) and "openrouter" in href:
                            verify_url = href
                            break
                if verify_url:
                    print(f"  FOUND: {verify_url[:60]}...", flush=True)
                    break
        except Exception as e:
            print(f"  Search error: {e}", flush=True)
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

    # Pre-warm verify domain via CloakBypasser
    from urllib.parse import urlparse
    parsed = urlparse(verify_url)
    print(f"  Pre-warming {parsed.netloc}...", flush=True)
    vresult = await b.get_or_generate_html(verify_url)
    if vresult and vresult.get("cookies"):
        await ctx.cookies([{"name": n, "value": v, "url": verify_url}
                           for n, v in vresult["cookies"].items()])
        print(f"  Injected {len(vresult['cookies'])} cookies", flush=True)

    await page.goto(verify_url, wait_until="domcontentloaded", timeout=30000)
    await page.wait_for_timeout(5000)

    # Click Individual if on OpenRouter
    if "openrouter.ai" in page.url:
        try:
            await page.get_by_text("Individual", exact=False).first.click()
            await page.wait_for_timeout(3000)
        except:
            pass

    await page.wait_for_timeout(8000)

    # Extract API key
    api_key = None
    try:
        code_text = await page.locator("code").inner_text(timeout=5000)
        m = re.search(r"sk-or-v1-[a-zA-Z0-9]+", code_text)
        if m:
            api_key = m.group(0)
    except:
        pass

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

    if not api_key:
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

echo "Running integrated signup (single browser + inline CF bypass)..."
PROTON_USER="$PROTON_USER" PROTON_PASS="$PROTON_PASS" \
OR_PROFILE="$OR_PROFILE" PROTON_PROFILE="$PROTON_PROFILE" \
CRED="$CRED" \
python3 ~/or_integrated.py "$EMAIL" "$PASSWORD"

echo "Done! Credentials:"
cat "$CRED"
