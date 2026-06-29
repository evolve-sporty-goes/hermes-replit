#!/bin/bash
# magiclink.sh — Request TorBox OTP + extract verify URL from Proton Mail
set -euo pipefail
command -v playwright >/dev/null 2>&1  || pip install playwright
CH="https://db.torbox.app"
KEY=$(cat /home/runner/workspace/credentials/.supabase_anon_key)
EMAIL="${1:?Usage: bash magiclink.sh <email>}"

# Step 1: Request OTP (bypasses Cloudflare via Playwright browser fetch)
RESULT=$(python3 - "$CH" "$KEY" "$EMAIL" << 'PYEOF'
import json, sys, os
sys.path.insert(0, os.path.expanduser("~"))
from playwright.sync_api import sync_playwright
import importlib

if "config" in sys.modules: del sys.modules["config"]
C = importlib.import_module("config")

base = sys.argv[1]
key = sys.argv[2]
email = sys.argv[3]

CHROME = "/nix/store/qa9cnw4v5xkxyip6mb9kxqfq1z4x2dx1-chromium-138.0.7204.100/bin/chromium"
PROFILE = os.path.expanduser("~/proton_profile")

with sync_playwright() as p:
    ctx = p.chromium.launch_persistent_context(PROFILE)
    pg = ctx.new_page()
    pg.goto("https://torbox.app", timeout=30000)
    pg.wait_for_timeout(2000)

    result = pg.evaluate('''async () => {
        const key = "''' + key + '''";
        const resp = await fetch("''' + base + '''/auth/v1/otp", {
            method: "POST",
            headers: { "apikey": key, "Authorization": "Bearer " + key, "Content-Type": "application/json" },
            body: JSON.stringify({ email: "''' + email + '''" })
        });
        return await resp.text();
    }''')
    print(result)
    ctx.close()
PYEOF
)

echo "OTP request: $RESULT" >&2
echo "Checking Proton Mail..."

# Step 2: Extract verify URL from Proton Mail
VERIFY_URL=$(python3 - "$EMAIL" << 'PYEOF'
import sys, os, re
sys.path.insert(0, os.path.expanduser("~"))
from playwright.sync_api import sync_playwright
import importlib

if "config" in sys.modules: del sys.modules["config"]
C = importlib.import_module("config")

email = sys.argv[1]
PROFILE = os.path.expanduser("~/proton_profile")

with sync_playwright() as p:
    ctx = p.chromium.launch_persistent_context(PROFILE)
    pg = ctx.new_page()
    pg.goto("https://account.proton.me/login", timeout=60000)
    pg.wait_for_timeout(3000)

    logged_in = False
    try:
        if pg.locator("a:has-text('Mail')").is_visible(timeout=3000):
            logged_in = True
    except: pass

    if not logged_in:
        pg.locator("#username").fill(C.PROTON_USERNAME)
        pg.locator("#password").fill(C.PROTON_PASSWORD)
        pg.locator("button[type='submit']").click()
        pg.wait_for_timeout(10000)
        pg.locator("a:has-text('Mail')").first.click(timeout=0)
        pg.wait_for_timeout(5000)

    pg.goto("https://mail.proton.me/u/0/inbox", timeout=30000)
    pg.wait_for_timeout(2000)

    for _ in range(7):
        try:
            pg.keyboard.press("/")
            pg.wait_for_timeout(800)
            pg.keyboard.type(email, delay=20)
            pg.keyboard.press("Enter")
            pg.wait_for_timeout(4000)
            items = pg.locator(".item-container,.message-item,[data-testid='message-item']")
            if items.count() > 0:
                items.first.click()
                pg.wait_for_timeout(2000)
                break
            pg.reload()
            pg.wait_for_load_state("networkidle")
            pg.wait_for_timeout(2000)
        except:
            try: pg.keyboard.press("Escape")
            except: pass
            pg.wait_for_timeout(2000)
    else:
        print("NOT_FOUND")
        ctx.close()
        sys.exit(0)

    pg.wait_for_timeout(1500)

    url = "NOT_FOUND"
    for frame in pg.frames:
        try:
            hrefs = frame.eval_on_selector_all("a[href]", "els => els.map(e => e.href)")
            for href in hrefs:
                if "db.torbox.app/auth/v1/verify" in href:
                    url = href
                    break
            if url != "NOT_FOUND": break
        except: continue

    if url == "NOT_FOUND":
        html = ""
        for f in pg.frames:
            try: html += f.content() + "\n"
            except: pass
        m = re.search(r'https://db\.torbox\.app/auth/v1/verify[^\s"<>]*', html)
        if m: url = m.group(0).replace("&amp;", "&")

    ctx.close()
    print(url)
PYEOF
)

echo "$VERIFY_URL"
