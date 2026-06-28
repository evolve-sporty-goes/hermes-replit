# TorBox Account Signup + Verify Workflow

TorBox (torbox.app) account signup and email verification. Two approaches: lightweight bash (recommended for signup+verify only) and full Python (for API key extraction + Nuvio addon setup).

## Architecture

### A. Lightweight Bash — Single Merged Script (Recommended)

```
email.sh → Supabase API → Proton Mail (Chromium) → verify URL → curl verify
```

- **No Camoufox needed** — Supabase API call bypasses Cloudflare Turnstile entirely
- **Playwright Chromium subprocess** for Proton Mail inbox search (avoids Camoufox crash)
- **Single script** does signup + verify in one run
- Credentials output: `torbox_credentials.txt` (append-only, blank-line separated)

Script: `scripts/torbox-signup.sh` at `/home/runner/workspace/scripts/torbox-signup.sh`

### B. Full Python (signup + verify + API key + Nuvio)

- **Camoufox** for dashboard, API key extraction, Nuvio setup
- **Chromium subprocess** for Proton Mail

Script: `torbox.py` at `/home/runner/workspace/torbox.py`

## Prerequisites

- `playwright` installed (approach A only needs playwright, not camoufox)
- `email.sh` at `/home/runner/workspace/email.sh` — generates Duck email, prints to stdout
- `~/config.py` with `PROTON_USERNAME`, `PROTON_PASSWORD`, `TORBOX_PASSWORD`
- System Chromium at `/nix/store/<hash>-chromium-<version>/bin/chromium`
- Supabase anon key in `.hermes_data/.env` as `SUPABASE_ANON_KEY=<jwt>`
- Proton profile dir `~/proton_profile` (auto-created)

---

## Approach A: Lightweight Bash (Recommended)

### Step 1: Sign up via Supabase API

The TorBox frontend uses Supabase Auth (`https://db.torbox.app`). The anon key is embedded in the JS bundle and can be extracted with:

```python
import re, urllib.request
text = urllib.request.urlopen("https://torbox.app/assets/index-dd8fba39.js").read().decode()
m = re.search(r'eyJhbG[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+', text)
print(m.group())  # JWT anon key
```

Then call the API directly — **bypasses Cloudflare Turnstile completely**:

```bash
curl -s -X POST "https://db.torbox.app/auth/v1/signup" \
  -H 'Content-Type: application/json' \
  -H "apikey: $ANON_KEY" \
  -d "{\"email\":\"$EMAIL\",\"password\":\"$PW\"}"
```

**Key details:**
- Email comes from `bash email.sh`
- Password comes from `config.TORBOX_PASSWORD` (imported via `python3 -c "import config; print(config.TORBOX_PASSWORD)"`)
- Response `confirmation_sent_at` confirms verification email was sent
- Error `msg` field indicates failures (e.g., "Password should contain at least one character of each: abcdefghijklmnopqrstuvwxyz, ABCDEFGHIJKLMNOPQRSTUVWXYZ, 0123456789, !@#$%^&*()...")

### Step 2: Verify email via Proton Mail (Chromium subprocess)

Run as an inline Python subprocess inside the bash script. Key pattern:

```python
# Login to Proton
pg.goto("https://mail.proton.me/", timeout=30000)
if "login" in pg.url:
    pg.locator("#username").fill(config.PROTON_USERNAME)
    pg.locator("#password").fill(config.PROTON_PASSWORD)
    pg.locator('button[type="submit"]').click()

# Navigate to inbox
pg.goto("https://mail.proton.me/u/0/inbox", timeout=30000)

# Search by the SIGNUP EMAIL ADDRESS (not generic keyword)
for attempt in range(7):
    pg.keyboard.press("/")          # open Proton search
    pg.wait_for_timeout(800)
    pg.keyboard.type(email, delay=20)  # the actual signup email
    pg.keyboard.press("Enter")
    pg.wait_for_timeout(4000)
    items = pg.locator(".item-container,.message-item,[data-testid='message-item']")
    if items.count() > 0:
        items.first.click()
        pg.wait_for_timeout(2000)
        break
```

- **Search by the actual signup email address** — Proton indexes the full recipient address, even for Duck.com relay addresses. Do NOT search by generic keyword like "torbox".
- Click first result, then extract verify link from anchor tags across all frames
- Look for `href` containing both "torbox" and "verify" or "confirm"
- Fallback: regex `https://db\.torbox\.app/auth/v1/verify[^\s"'<>]*` across all frame HTML
- Visit the verify URL with `curl -L` — HTTP 200/302 = success

### Step 3: Append credentials

```
email=<address>
password=<pw>
user_id=<uuid>
verified=true

```

Blank line separates entries. Each run appends (`>>`), never overwrites.

### Complete Script Pattern

```bash
#!/usr/bin/env bash
set -euo pipefail

CRED="torbox_credentials.txt"

EMAIL=$(bash /home/runner/workspace/email.sh)
PW=$(python3 -c "import sys,os;sys.path.insert(0,os.path.expanduser('~'));import config;print(config.TORBOX_PASSWORD)")

# Signup via Supabase API
B=$(curl -s -X POST "https://db.torbox.app/auth/v1/signup" \
  -H 'Content-Type: application/json' \
  -H "apikey: $(grep SUPABASE_ANON_KEY /home/runner/workspace/.hermes_data/.env 2>/dev/null | tr -d '\r' | cut -d= -f2- || echo '')" \
  -d "{\"email\":\"$EMAIL\",\"password\":\"$PW\"}")
# ... error check, extract ID ...

# Verify via Proton/Chromium subprocess
VERIFY_URL=$(python3 - "$EMAIL" << 'PYEOF'
import sys,os,re,time
sys.path.insert(0,os.path.expanduser("~"))
from playwright.sync_api import sync_playwright
import importlib
if "config" in sys.modules: del sys.modules["config"]
config=importlib.import_module("config")
email=sys.argv[1]
CHROMIUM="/nix/store/qa9cnw4v5xkxyip6mb9kxqfq1z4x2dx1-chromium-138.0.7204.100/bin/chromium"
PROFILE=os.path.expanduser("~/proton_profile")
url="NOT_FOUND"
with sync_playwright() as p:
  ctx=p.chromium.launch_persistent_context(PROFILE,executable_path=CHROMIUM,headless=True,args=["--no-sandbox","--disable-gpu"])
  pg=ctx.new_page()
  pg.goto("https://account.proton.me/login", timeout=60000); pg.wait_for_timeout(3000)
  already_logged_in=False
  try:
    ml=pg.locator("a:has-text('Mail')")
    if ml.is_visible(timeout=3000): already_logged_in=True
  except: pass
  if already_logged_in:
    pg.goto("https://account.proton.me/login",timeout=60000); pg.wait_for_timeout(3000)
    already_logged_in=False
    try:
      ml=pg.locator("a:has-text('Mail')")
      if ml.is_visible(timeout=3000): already_logged_in=True
    except: pass
    if already_logged_in:
      print("Already logged in",file=sys.stderr)
    else:
      pg.locator("#username").fill(config.PROTON_USERNAME)
      pg.locator("#password").fill(config.PROTON_PASSWORD)
      pg.locator("button[type='submit']").click(); pg.wait_for_timeout(10000)
      pg.locator("a:has-text('Mail')").first.click(timeout=0); pg.wait_for_timeout(5000)
    pg.locator("a:has-text('Mail')").first.click(timeout=0); pg.wait_for_timeout(5000)
  pg.goto("https://mail.proton.me/u/0/inbox",timeout=30000); pg.wait_for_timeout(2000)
  for attempt in range(7):
    try:
      pg.keyboard.press("/"); pg.wait_for_timeout(800)
      pg.keyboard.type(email,delay=20); pg.keyboard.press("Enter"); pg.wait_for_timeout(4000)
      items=pg.locator(".item-container,.message-item,[data-testid='message-item']")
      if items.count()>0:
        items.first.click(); pg.wait_for_timeout(2000); break
    except:
      try: pg.keyboard.press("Escape")
      except: pass
      pg.wait_for_timeout(2000)
  else:
    print("NOT_FOUND",end=""); ctx.close(); sys.exit(0)
  pg.wait_for_timeout(1500)
  for frame in pg.frames:
    try:
      for href in frame.eval_on_selector_all("a[href]","els=>els.map(e=>e.href)"):
        if ("verify" in href.lower() or "confirm" in href.lower()) and "torbox" in href.lower():
          url=href.replace("&amp;","&"); break
      if url!="NOT_FOUND": break
    except: continue
  if url=="NOT_FOUND":
    html=""
    for f in pg.frames:
      try: html+=f.content()+"\n"
      except: pass
    m=re.search(r'https://db\.torbox\.app/auth/v1/verify[^\s"\'<>]*',html)
    if m: url=m.group(0).replace("&amp;","&")
  ctx.close()
print(url,end="")
PYEOF
)

if [[ "$VERIFY_URL" == "NOT_FOUND" ]]; then
  echo "email=$EMAIL" >> "$CRED"; echo "password=$PW" >> "$CRED"
  echo "user_id=$ID" >> "$CRED"; echo "verified=false" >> "$CRED"
  echo "" >> "$CRED"; exit 0
fi
CODE=$(curl -s -o /dev/null -w "%{http_code}" -L "$VERIFY_URL")
echo "email=$EMAIL" >> "$CRED"; echo "password=$PW" >> "$CRED"
echo "user_id=$ID" >> "$CRED"
if [[ "$CODE" =~ ^(200|302)$ ]]; then
  echo "verified=true" >> "$CRED"
else
  echo "verified=false" >> "$CRED"
fi
echo "" >> "$CRED"
```

---

## Approach B: Full Python (signup + verify + API key + Nuvio)

Same hybrid pattern as OpenRouter/Firecrawl:
- **Camoufox** (anti-fingerprint Firefox) for signup, verification redirect, API key extraction, and Nuvio setup
- **Playwright Chromium subprocess** for Proton Mail inbox polling and verification link extraction
- **Persistent tmpdir** (`tempfile.mkdtemp` + `atexit` cleanup) shared across Camoufox steps
- **Persistent Proton profile** (`~/proton_profile`) for Chromium to survive login across runs

### Step 1: Generate Duck Email
- Run `bash email.sh`, capture email from stdout (last line with `@`)
- Subprocess env: venv `PATH`, `VIRTUAL_ENV`, `.pythonlibs` in `PYTHONPATH`
- Import `~/config.py` fresh (delete stale pyc, reload module)

### Step 2: Register on TorBox (Camoufox)

```python
page.goto("https://torbox.app/login", timeout=0)
page.wait_for_timeout(2000)

# Click "Sign up" if on login page
signup_btn = page.get_by_role("button", name="Sign up")
if signup_btn.is_visible():
    signup_btn.click()
    page.wait_for_timeout(1000)

page.wait_for_selector("#email-input", timeout=0)
page.locator("#email-input").fill(alias_email)
page.locator("#password-input").fill(password)
page.locator("#consent-checkbox").click()
```

- **Selectors:** `#email-input`, `#password-input`, `#consent-checkbox`, `button[type='submit']`
- **Cloudflare challenge:** Iterate `page.frames`, find `challenges.cloudflare.com`, click `#challenge-stage` / `.ctp-checkbox`
- **Success indicator:** Body text matching `re.compile(r"confirm|check", re.IGNORECASE)` — then 8s wait

### Step 3: Check Proton Mail (Chromium subprocess)

Same pattern as Approach A Step 2. Search by the actual signup email address.

### Step 4: Verify Email (Camoufox)

```python
page.goto(verify_url, timeout=60000)
page.wait_for_timeout(8000)
```

### Step 5: Extract API Key (Camoufox)

1. **Dashboard:** Navigate to `https://torbox.app/dashboard`
2. **Fallback login:** If redirected to login, fill `#email-input` + `#password-input` (using `config.TORBOX_PASSWORD`), handle Cloudflare, submit
3. **Free Demo activation:** Look for "Get your free demo now!" button/link, click it, wait 5s
4. **Settings page:** Navigate to `https://torbox.app/settings`, wait 8s
5. **Key extraction from inputs:** Count `<input>` elements — if 0, retry whole cycle. Scan input values for strings >20 chars with no spaces/no `@`
6. **Fallback text searches:** Scan `<code>`, `<pre>`, `<input>` text_content for same pattern

### Step 6: Setup Nuvio Addon (Camoufox)

```python
manifest = f"https://torrentio.strem.fun/sort=size|qualityfilter=cam,unknown,720p,480p,other,scr|torbox={api_key}/manifest.json"
```

- Login to `https://nuvio.tv/account/login` using `config.STREMIO_EMAIL` / `config.STREMIO_PASSWORD`
- Add new addon with manifest URL, name "torrentio", save

### Step 7: Save Credentials
- Append to `torbox_credentials.txt` with blank-line separators

---

## TorBox-Specific Notes

- **Login URL is `/login` not `/sign-up`** — signup form is accessed by clicking "Sign up" button on the login page
- **Supabase API at `db.torbox.app`** — the frontend uses Supabase Auth; calling the API directly bypasses Cloudflare Turnstile (no browser needed for signup)
- **Supabase anon key is public** — embedded in the JS bundle; not a secret. It's a JWT with `role: "anon"`. Store in `.hermes_data/.env` as `SUPABASE_ANON_KEY`
- **Password must have lower + upper + digit + symbol** — TorBox enforces all four classes. The Supabase API returns 422 with a descriptive message if missing
- **Proton login URL is `account.proton.me/login`** — Always navigate here first with `timeout=60000` (not `mail.proton.me`). Check if "Mail" link is visible (already logged in) before entering credentials. After submit, wait 10s, click `a:has-text('Mail')` with `timeout=0`, wait 5s.
- **Proton search: use the actual signup email address** — Search for the full email address (e.g. `some-words-here@duck.com`) using the `/` shortcut + `keyboard.type(email, delay=20)`. Proton indexes the full recipient address even for Duck.com relay. Do NOT search by generic keyword like "torbox".
- **Free trial must be activated** before API key is available — "Get your free demo now!" button on dashboard
- **Settings page input count = 0 means activation failed** — retry dashboard → demo → settings cycle
- **API key is in an `<input>` value** on settings page (not `<code>` block like OpenRouter)
- **TorBox password from `config.TORBOX_PASSWORD`** for fallback login
- **Nuvio manifest URL:** `https://torrentio.strem.fun/sort=size|qualityfilter=cam,unknown,720p,480p,other,scr|torbox={api_key}/manifest.json`
- **Credential file is append-only** with blank-line separators — each run adds a block, never overwrites

## Retry Logic (Approach B)
- Main loop: 3 attempts
- If Proton returns NOT_FOUND: generate fresh email, new password, restart from Step 2
- After 3 failed attempts: print "FAILED: 3 signup attempts exhausted."

## Approach C: Verify-Only Python Script

For when signup and Proton Mail verification are already done (e.g. by Approach A). This script only visits the verify link, activates the free trial, extracts the API key, and appends to credentials.

Script: `scripts/torbox_signup.py` at `/home/runner/workspace/scripts/torbox_signup.py`

```bash
# After getting VERIFY_URL from Proton:
python3 scripts/torbox_signup.py "https://db.torbox.app/auth/v1/verify?token=..." "user@duck.com" "password123"

# Or with env vars:
VERIFY_URL="https://..." TORBOX_EMAIL="user@duck.com" TORBOX_PASSWORD=*** python3 scripts/torbox_signup.py
```

Flow: visit verify URL → dashboard (click "free demo") → settings (extract API key from `<input>` values) → append credentials. 3-attempt retry on API key extraction. Falls back to reading email/password from existing cred file or `config.py`.

---

## VPN / Proxy Integration

See `references/proxy-and-vpn-patterns.md` for full patterns. TL;DR:
- **Free SOCKS5 proxy** with `geoip=True` is recommended (zero-touch, auto-connects)
- **Browser VPN extensions do NOT work** for automation (require user click)
- **Tor** works but takes 2-3 min to bootstrap
