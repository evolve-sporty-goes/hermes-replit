#!/bin/bash
# openrouter_signup.sh — OpenRouter signup + verify + extract API key
# Follows firecrawl_signup.sh architecture (see docs/Instructions.txt)
# Persistent profile for signup→verify flow (Clerk session must carry over)
set -e
export DISPLAY=:1
cd /home/runner/workspace
mkdir -p /home/runner/workspace/proton_profile credentials

OR_PROFILE="/home/runner/workspace/or_profile"
PROTON_PROFILE="/home/runner/workspace/proton_profile"
CRED="/home/runner/workspace/credentials/openrouter_credentials.txt"

# ── Credentials ──────────────────────────────────────────────────
bash scripts/email.sh > /dev/null 2>&1
EMAIL=$(bash scripts/email.sh 2>/dev/null | tail -1 | tr -d '[:space:]')
PASSWORD="HermesSecure#2026!xR"
echo "Email: $EMAIL"

# Clean or_profile for fresh signup each run
rm -rf "$OR_PROFILE"
mkdir -p "$OR_PROFILE"

# ═════════════════════════════════════════════════════════════════
# STEP 1: Signup (or_signup.py)
#   Uses persistent profile so Clerk session persists to Step 3
# ═════════════════════════════════════════════════════════════════
cat > ~/or_signup.py << 'PYEOF'
import sys, os
os.environ["DISPLAY"] = ":1"
from cloakbrowser import launch_persistent_context
import shutil

email, password, profile_dir = sys.argv[1], sys.argv[2], sys.argv[3]

ctx = launch_persistent_context(profile_dir, headless=False, humanize=True,
    args=["--enable-blink-features=FakeShadowRoot"])
p = ctx.pages[0] if ctx.pages else ctx.new_page()

print("[+] Navigating...", flush=True)
p.goto("https://openrouter.ai/sign-up", timeout=60000, wait_until="domcontentloaded")
p.wait_for_timeout(4000)

print("[+] Filling form...", flush=True)
p.locator("#emailAddress-field").click()
p.locator("#emailAddress-field").type(email, delay=50)
p.wait_for_timeout(300)
p.locator("#password-field").click()
p.locator("#password-field").type(password, delay=50)
p.wait_for_timeout(300)

print("[+] Checkbox (React fiber)...", flush=True)
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

print("[+] Submitting...", flush=True)
p.get_by_role("button", name="Continue").click()
p.wait_for_timeout(8000)

# Find CF Turnstile frame
print("[+] Finding Turnstile...", flush=True)
cf_box = None
for _ in range(30):
    for f in p.frames:
        if "challenges.cloudflare" in (f.url or ""):
            try:
                fb = f.frame_element().bounding_box()
                if fb and fb["width"] > 50:
                    cf_box = fb
                    break
            except:
                pass
    if cf_box:
        break
    p.wait_for_timeout(2000)

if not cf_box:
    print("TURNOTILE:NOT_FOUND", flush=True)
    ctx.close()
    sys.exit(1)

print(f"  Turnstile frame: {cf_box}", flush=True)

# Click checkbox inside Turnstile (frame_x + 30, frame_y + height/2)
click_x = cf_box["x"] + 30
click_y = cf_box["y"] + cf_box["height"] / 2
print(f"[+] Clicking Turnstile at ({click_x}, {click_y})...", flush=True)
p.mouse.click(click_x, click_y)
p.wait_for_timeout(8000)

url = p.url
print(f"  URL: {url}", flush=True)

if "verify" in url or "confirm" in url:
    print("TURNOTILE:SOLVED", flush=True)
else:
    p.mouse.click(click_x, click_y)
    p.wait_for_timeout(8000)
    url = p.url
    print(f"  Retry URL: {url}", flush=True)
    if "verify" in url or "confirm" in url:
        print("TURNOTILE:SOLVED", flush=True)
    else:
        print("TURNOTILE:UNSURE", flush=True)

ctx.close()
PYEOF

# ═════════════════════════════════════════════════════════════════
# STEP 2: Check inbox for verification email (or_proton.py)
#   Uses persistent proton_profile
# ═════════════════════════════════════════════════════════════════
cat > ~/or_proton.py << 'PYEOF'
import sys, re
from cloakbrowser import launch_persistent_context

signup_email = sys.argv[1]
profile_dir = sys.argv[2]

ctx = launch_persistent_context(profile_dir, headless=False)
page = ctx.pages[0] if ctx.pages else ctx.new_page()

page.goto("https://mail.proton.me/u/0/inbox", timeout=60000)
page.wait_for_timeout(5000)

if "/login" in page.url:
    print("[+] logging in...", flush=True)
    spec = __import__('importlib').util.spec_from_file_location("c", "/home/runner/config.py")
    mod = __import__('importlib').util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    page.locator("#username").fill(mod.PROTON_USERNAME)
    page.locator("#password").fill(mod.PROTON_PASSWORD)
    page.locator("button[type='submit']").click()
    page.wait_for_timeout(15000)

def find_verify():
    for link in page.query_selector_all("a[href]"):
        href = link.get_attribute("href")
        if href and ("openrouter" in href or "clerk" in href) and ("verify" in href or "confirm" in href):
            return href
    for frame in page.frames:
        try:
            html = frame.content()
            m = re.findall(r'https://[^\s"<>()]*(?:openrouter|clerk)[^\s"<>()]*(?:verify|confirm)[^\s"<>()]*', html, re.IGNORECASE)
            if m:
                return m[0].replace("&amp;", "&")
        except:
            pass
    return None

checked = set()
for attempt in range(15):
    page.wait_for_timeout(8000)
    page.keyboard.press("/")
    page.wait_for_timeout(1000)
    page.keyboard.type(signup_email, delay=80)
    page.keyboard.press("Enter")
    page.wait_for_timeout(5000)

    items = page.locator(".item-container")
    count = items.count()
    if count == 0:
        page.goto("https://mail.proton.me/u/0/inbox", timeout=60000)
        page.wait_for_timeout(5000)
        continue

    for i in range(min(count, 5)):
        subj = items.nth(i).text_content().strip()[:80]
        if subj not in checked:
            checked.add(subj)
            items.nth(i).click()
            page.wait_for_timeout(4000)
            link = find_verify()
            if link:
                print(f"VERIFY_URL:{link}", flush=True)
                ctx.close()
                sys.exit(0)
            break

    if len(checked) >= count:
        checked.clear()
    page.goto("https://mail.proton.me/u/0/inbox", timeout=60000)
    page.wait_for_timeout(5000)

ctx.close()
print("VERIFY_URL:NOT_FOUND", flush=True)
PYEOF

# ═════════════════════════════════════════════════════════════════
# STEP 3: Verify + Extract API Key (or_verify.py)
#   Uses SAME or_profile as signup (Clerk session carries over)
# ═════════════════════════════════════════════════════════════════
cat > ~/or_verify.py << 'PYEOF'
import sys, re, time
from cloakbrowser import launch_persistent_context
from playwright._impl._errors import TargetClosedError

verify_url, email, password, cred_path, profile_dir = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5]

# Use same persistent profile from signup — Clerk session cookies here
ctx = launch_persistent_context(profile_dir, headless=False, humanize=True)
p = ctx.pages[0] if ctx.pages else ctx.new_page()

print(f"[+] Opening verify URL in persistent profile...", flush=True)
p.goto(verify_url, timeout=60000)
time.sleep(5)

if len(ctx.pages) > 1:
    p = ctx.pages[-1]

api_key = None
for i in range(60):
    try:
        url = p.url
        print(f"  [{i}] URL: {url}", flush=True)

        # Clerk verify redirect page — wait then click Individual
        if "openrouter.ai" in url and "sign-up/verify" in url:
            print(f"  On sign-up/verify page, waiting 3s...", flush=True)
            time.sleep(3)
            try:
                ind = p.get_by_role("button", name="Individual")
                if ind.is_visible(timeout=5000):
                    print("  Clicking 'Individual'...", flush=True)
                    ind.click()
                    time.sleep(5)
                    continue
            except:
                pass
            # If no Individual button, just continue
            time.sleep(3)
            continue

        # Wait for clerk verify redirect to complete
        if "clerk" in url and ("verify" in url or "redirect" in url):
            time.sleep(5)
            continue

        # After Clerk verify redirect — the account is created.
        # MUST check BEFORE /sign-up login check (substring match)
        if "openrouter.ai" in url and "sign-up/verify" in url:
            print(f"  Clerk verified! Account created. Going to sign-in...", flush=True)
            p.goto("https://openrouter.ai/sign-in", wait_until="domcontentloaded", timeout=30000)
            time.sleep(3)
            p.locator("#emailAddress-field").click()
            p.locator("#emailAddress-field").type(email, delay=50)
            time.sleep(0.3)
            p.locator("#password-field").click()
            p.locator("#password-field").type(password, delay=50)
            p.get_by_role("button", name="Continue").click()
            time.sleep(10)
            continue

        # Login if on sign-in page (NOT sign-up/verify — handled above)
        if "/sign-in" in url or "/signin" in url or ("/sign-up" in url and "verify" not in url):
            print("  Logging in (Clerk)...", flush=True)
            p.goto("https://openrouter.ai/sign-in", wait_until="domcontentloaded", timeout=30000)
            time.sleep(3)
            p.locator("#emailAddress-field").click()
            p.locator("#emailAddress-field").type(email, delay=50)
            time.sleep(0.3)
            p.locator("#password-field").click()
            p.locator("#password-field").type(password, delay=50)
            p.get_by_role("button", name="Continue").click()
            time.sleep(10)
            continue

        # On authenticated OpenRouter page (not sign-up or sign-in)
        if "openrouter.ai" in url and "/sign" not in url:
            print(f"  On OpenRouter: {url}", flush=True)

            # Handle "Individual or Business" selection page (alternate location)
            try:
                individual_btn = p.get_by_role("button", name="Individual")
                if individual_btn.is_visible(timeout=2000):
                    print("  Clicking 'Individual' (dashboard)...", flush=True)
                    individual_btn.click()
                    time.sleep(5)
                    continue
            except:
                pass

            if "/keys" not in url:
                p.goto("https://openrouter.ai/workspaces/default/keys", wait_until="domcontentloaded", timeout=30000)
                time.sleep(5)

            # API key extraction (same pattern as firecrawl_signup.sh)
            time.sleep(3)
            all_text = p.inner_text("body")

            # Method 1: key already visible
            m = re.findall(r'(?:sk-or-v1-|sk-)[a-zA-Z0-9_-]{30,}', all_text)
            if m:
                api_key = m[0]

            # Method 2: click eye icon to reveal, then read
            if not api_key:
                for sel in ["button:has(.lucide-eye)", "button:has(.lucide-eye-off)", "button[aria-label='Reveal']", "button[aria-label='Show']", "[data-testid='reveal-button']"]:
                    try:
                        p.click(sel)
                        time.sleep(2)
                        txt = p.locator("text=fc-,text=sk-or,input[value*='sk-or']").first.text_content(timeout=3000).strip()
                        if txt.startswith("sk-or-") or txt.startswith("sk-"):
                            api_key = txt
                            break
                    except:
                        pass
                    # Re-scan body text
                    all_text = p.inner_text("body")
                    m = re.findall(r'(?:sk-or-v1-|sk-)[a-zA-Z0-9_-]{30,}', all_text)
                    if m:
                        api_key = m[0]
                        break

            # Method 3: click copy button + read clipboard
            if not api_key:
                try:
                    import subprocess
                    p.click('[aria-label="Copy"]')
                    time.sleep(1)
                    result = subprocess.run(["xclip", "-o", "-selection", "clipboard"], capture_output=True, text=True)
                    clip = result.stdout.strip()
                    if clip.startswith("sk-or-") or clip.startswith("sk-"):
                        api_key = clip
                except:
                    pass

            # Method 4: HTML regex
            if not api_key:
                html = p.content()
                m2 = re.findall(r'(?:sk-or-v1-|sk-)[a-zA-Z0-9_-]{30,}', html)
                if m2:
                    api_key = m2[0]

            # Method 5: no key exists yet — click "Generate" / "Create"
            if not api_key:
                for gen_sel in ["button:has-text('Generate')", "button:has-text('Create')", "button:has-text('New')", "a:has-text('Generate')"]:
                    try:
                        p.click(gen_sel)
                        time.sleep(3)
                        text = p.inner_text("body")
                        m = re.findall(r'(?:sk-or-v1-|sk-)[a-zA-Z0-9_-]{30,}', text)
                        if m:
                            api_key = m[0]
                            break
                        # Reveal buttons
                        for rev_sel in ["button[aria-label='Reveal']", "button .lucide-eye", "button .lucide-eye-off"]:
                            try:
                                for btn in p.locator(rev_sel).all():
                                    btn.click()
                                    time.sleep(1.5)
                                    text = p.inner_text("body")
                                    m = re.findall(r'(?:sk-or-v1-|sk-)[a-zA-Z0-9_-]{30,}', text)
                                    if m:
                                        api_key = m[0]
                                        break
                            except:
                                pass
                            if api_key:
                                break
                    except:
                        pass
                if api_key:
                    break

            if api_key:
                break

    except TargetClosedError:
        break
    except Exception as e:
        import traceback
        traceback.print_exc()
        print(f"  Error: {e}", flush=True)

    time.sleep(2)

ctx.close()

with open(cred_path, "a") as f:
    f.write(f"\n--- {email} ---\n")
    f.write(f"EMAIL={email}\nPASSWORD={password}\nAPI_KEY={api_key or 'NOT_FOUND'}\n")

print(f"API_KEY:{api_key or 'NOT_FOUND'}", flush=True)
PYEOF

# ═════════════════════════════════════════════════════════════════
# MAIN — 3 attempts with retry
# ═════════════════════════════════════════════════════════════════
for ATTEMPT in 1 2 3; do
  [ "$ATTEMPT" -gt 1 ] && {
    # Fresh email + fresh profile for retry
    EMAIL=$(bash scripts/email.sh 2>/dev/null | tail -1 | tr -d '[:space:]')
    rm -rf "$OR_PROFILE"
    mkdir -p "$OR_PROFILE"
    echo "Retry $ATTEMPT: $EMAIL"
  }

  echo ""
  echo "=== Step 1: Signup ==="
  python3 ~/or_signup.py "$EMAIL" "$PASSWORD" "$OR_PROFILE" || continue

  echo "=== Step 2: Check inbox ==="
  VURL=$(python3 ~/or_proton.py "$EMAIL" "$PROTON_PROFILE" 2>&1 | grep '^VERIFY_URL:' | tail -1 | sed 's/^VERIFY_URL://')
  echo "  Verify URL: ${VURL:0:80}..."
  [ -z "$VURL" ] || [ "$VURL" = "NOT_FOUND" ] && { echo "Not found, retrying..."; continue; }

  echo "=== Step 3: Verify + Extract API Key ==="
  python3 ~/or_verify.py "$VURL" "$EMAIL" "$PASSWORD" "$CRED" "$OR_PROFILE"
  echo ""
  echo "Done! Saved to $CRED"
  exit 0
done

echo "FAILED: 3 attempts exhausted"
exit 1
