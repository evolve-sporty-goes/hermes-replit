#!/usr/bin/env python3
"""
Request TorBox OTP via Playwright browser fetch (bypasses Cloudflare WAF).
Usage: python3 scripts/torbox-request-otp.py <email>
Output: {} on success
"""
import json, sys, os
sys.path.insert(0, os.path.expanduser("~"))
from playwright.sync_api import sync_playwright
import importlib

if "config" in sys.modules: del sys.modules["config"]
C = importlib.import_module("config")

if len(sys.argv) < 2:
    print("Usage: python3 scripts/torbox-request-otp.py <email>", file=sys.stderr)
    sys.exit(1)

email = sys.argv[1]
CH = "/nix/store/qa9cnw4v5xkxyip6mb9kxqfq1z4x2dx1-chromium-138.0.7204.100/bin/chromium"
PR = os.path.expanduser("~/proton_profile")

with open('/home/runner/workspace/.supabase_anon_key') as f:
    key = f.read().strip()

with sync_playwright() as p:
    ctx = p.chromium.launch_persistent_context(
        PR, executable_path=CH, headless=True,
        args=["--no-sandbox", "--disable-gpu"]
    )
    pg = ctx.new_page()
    pg.goto("https://torbox.app", timeout=30000)
    pg.wait_for_timeout(2000)
    result = pg.evaluate('''async () => {
        const key = "''' + key + '''";
        const resp = await fetch('https://db.torbox.app/auth/v1/otp', {
            method: 'POST',
            headers: { 'apikey': key, 'Authorization': 'Bearer ' + key, 'Content-Type': 'application/json' },
            body: JSON.stringify({ email: "''' + email + '''" })
        });
        return await resp.text();
    }''')
    print(result)
    ctx.close()
