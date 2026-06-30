#!/bin/bash
export DISPLAY=:1

# ── Generate fresh email ─────────────────────────────────────────
bash ~/workspace/scripts/email.sh > /dev/null 2>&1
EMAIL=$(tail -1 ~/workspace/credentials/mail.txt 2>/dev/null)
PASSWORD="HermesSecure#2026!xR"

echo "[+] Email: $EMAIL"
echo "[+] Password: $PASSWORD"

# ── Python helper ────────────────────────────────────────────────
cat > ~/or_run.py << 'PYEOF'
import os, sys, time, subprocess
os.environ["DISPLAY"] = ":1"
from cloakbrowser import launch_persistent_context
import shutil

EMAIL = sys.argv[1]
PASSWORD = sys.argv[2]

PROFILE = os.path.expanduser("~/or_profile_run")
if os.path.exists(PROFILE): shutil.rmtree(PROFILE)
os.makedirs(PROFILE)

ctx = launch_persistent_context(PROFILE, headless=False, humanize=True,
    args=["--enable-blink-features=FakeShadowRoot"])
p = ctx.pages[0] if ctx.pages else ctx.new_page()

# Navigate
print("[+] Navigating...", flush=True)
p.goto("https://openrouter.ai/sign-up", timeout=60000, wait_until="domcontentloaded")
p.wait_for_timeout(4000)

# Fill form
p.locator("#emailAddress-field").click()
p.locator("#emailAddress-field").type(EMAIL, delay=50)
p.wait_for_timeout(300)
p.locator("#password-field").click()
p.locator("#password-field").type(PASSWORD, delay=50)
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
            f.memoizedProps.onChange({
                target: { checked: true }, currentTarget: { checked: true },
                nativeEvent: new Event('change'), type: 'change',
                preventDefault(){}, stopPropagation(){}, persist(){}
            }); break;
        }
        f = f.return;
    }
}""")
p.wait_for_timeout(500)

# Submit
print("[+] Submitting...", flush=True)
p.get_by_role("button", name="Continue").click()
p.wait_for_timeout(8000)

# Find Turnstile CF frame
print("[+] Finding Turnstile frame...", flush=True)
cf_frame = None
for _ in range(30):
    for i, f in enumerate(p.frames):
        if "challenges.cloudflare" in (f.url or ""):
            try:
                fb = f.frame_element().bounding_box()
                if fb and fb["width"] > 50:
                    cf_frame = fb
                    break
            except:
                pass
    if cf_frame:
        break
    p.wait_for_timeout(2000)

if not cf_frame:
    print("[!] No CF frame found", flush=True)
    ctx.close()
    sys.exit(1)

print(f"  CF frame: {cf_frame}", flush=True)

# Click at frame_x + 30, frame_y + height/2 (checkbox position inside Turnstile)
click_x = cf_frame["x"] + 30
click_y = cf_frame["y"] + cf_frame["height"] / 2
print(f"[+] Clicking Turnstile checkbox at ({click_x}, {click_y})...", flush=True)
p.mouse.click(click_x, click_y)
p.wait_for_timeout(8000)

# Check result
url = p.url
if "confirm" in url or "verify" in url or "/keys" in url:
    print(f"\n{'='*50}", flush=True)
    print(f"SUCCESS!", flush=True)
    print(f"EMAIL={EMAIL}", flush=True)
    print(f"PASSWORD={PASSWORD}", flush=True)
    print(f"URL={url}", flush=True)
    print(f"{'='*50}", flush=True)
else:
    print(f"[?] Page at: {url} — may need manual check", flush=True)
    print(f"EMAIL={EMAIL} PASSWORD={PASSWORD}", flush=True)

ctx.close()
PYEOF

# ── Run ──────────────────────────────────────────────────────────
echo ""
python3 ~/or_run.py "$EMAIL" "$PASSWORD"
