# OpenRouter Signup + API Key Extraction Workflow

## Overview

Complete workflow to create an OpenRouter account, verify email, and extract the API key using Camoufox for the target site + Playwright Chromium in a subprocess for Proton Mail.

## Architecture

- **Steps 2/5/6** (OpenRouter signup, verify, key extraction): Camoufox (anti-fingerprint Firefox)
  - Fresh tmpdir per run via `tempfile.mkdtemp`, cleaned up on exit
  - `persistent_context=True` with `user_data_dir=tmpdir`
- **Step 3** (Proton Mail verification link): Playwright Chromium subprocess
  - Persistent profile at `~/proton_profile` (survives across runs)
  - If profile already has Proton logged in, skips credential entry
  - Runs in subprocess — Camoufox Firefox crashes on Proton Mail JS errors
    - Root cause: Playwright `coreBundle.js` bug — `pageError.location` is undefined
    - Fix: patch coreBundle.js to guard `pageError.location` before accessing `.url`

## Prerequisites

- `camoufox` + `playwright` installed
- `email.sh` at `/home/runner/workspace/email.sh` — generates Duck email, prints to stdout
- `~/config.py` with `PROTON_USERNAME`, `PROTON_PASSWORD`, credential pools
- System Chromium at `/nix/store/<hash>-chromium-<version>/bin/chromium`
- Proton profile dir `~/proton_profile` (auto-created)

## Workflow Steps

### 1. Generate Duck Email

Run `email.sh` and capture email from **stdout** (last line containing `@`), not from `mail.txt`:

```python
venv_bin = os.path.dirname(sys.executable)
venv_dir = os.path.dirname(venv_bin)
pythonlibs = "/home/runner/workspace/.pythonlibs/lib/python3.12/site-packages"
result = subprocess.run(
    ["bash", "/home/runner/workspace/email.sh"],
    capture_output=True, text=True, timeout=120,
    cwd="/home/runner/workspace",
    env={**os.environ,
         "PYTHONPATH": pythonlibs + ":/home/runner:/home/runner/workspace",
         "PATH": venv_bin + ":" + os.environ.get("PATH", ""),
         "VIRTUAL_ENV": venv_dir}
)
out_lines = [l.strip() for l in result.stdout.strip().split("\n") if l.strip()]
email = out_lines[-1] if out_lines else None
```

**Critical:** The subprocess env must include venv `PATH`, `VIRTUAL_ENV`, and `.pythonlibs` in `PYTHONPATH` — otherwise `duckmail.py` can't find `camoufox` (it's in `.pythonlibs`, not the venv or system python).

### 2. Sign Up on OpenRouter (Camoufox)

```python
with Camoufox(headless=False, persistent_context=True, user_data_dir=cam_tmpdir) as browser:
    page = browser.new_page()
    page.goto("https://openrouter.ai/sign-up", wait_until="networkidle", timeout=60000)
    page.wait_for_timeout(5000)
    page.locator("#emailAddress-field").wait_for(state="visible", timeout=30000)
    page.locator("#emailAddress-field").fill(email)
    page.locator("#password-field").fill(password)
    page.locator("#legalAccepted-field").check()
    page.get_by_role("button", name="Continue").click()
    page.wait_for_timeout(15000)
```

- **Cloudflare challenge:** Iterate `page.frames` looking for `challenges.cloudflare.com`, click `#challenge-stage` or `.ctp-checkbox`
- **Confirm-email detection:** Dual-signal — check both `"confirm-email" in page.url` AND body text for `"verification"` or `"check your"`

### 3. Proton Mail Verification Link (Chromium subprocess)

Runs as subprocess to avoid Camoufox Firefox crash. Uses persistent Chromium profile at `~/proton_profile`:

```python
# Login check — skip if already logged in
page.goto("https://account.proton.me/login", timeout=60000)
page.wait_for_timeout(3000)
if page.locator("a:has-text('Mail')").is_visible(timeout=3000):
    print("Already logged in — skipping credentials")
else:
    page.locator("#username").fill(PROTON_USER)
    page.locator("#password").fill(PROTON_PASS)
    page.locator("button[type='submit']").click()
    page.wait_for_timeout(10000)

page.locator("a:has-text('Mail')").first.click(timeout=0)  # timeout=0 to avoid hanging
page.wait_for_timeout(5000)
```

**Inbox search using Proton's search box (5 retries, 5s wait):**

```python
# Open search with / shortcut, type email, press Enter
page.keyboard.press("/")
page.wait_for_timeout(1000)
page.keyboard.type(SIGNUP_EMAIL, delay=50)  # NOT .fill() — input is readonly until activated
page.keyboard.press("Enter")
page.wait_for_timeout(5000)

# Click latest (first) mail in results
latest_mail = page.locator(".item-container").first
if latest_mail.is_visible(timeout=5000):
    latest_mail.click()
    page.wait_for_timeout(5000)
```

**Why `keyboard.type()` not `.fill()`?** The Proton search input (`data-testid="search-keyword"`) is `readonly` until the `/` shortcut activates it. `.fill()` silently fails on readonly inputs.

**Verification link extraction from email frames:**
- Primary: `re.findall(r'https://clerk.openrouter.ai/v1/verify[^\s"\'<>]+', html)`
- Fallback: `re.findall(r'https://openrouter\.ai[^\s"\'<>]*(?:verify|confirm|token)[^\s"\'<>]+', html)`
- Always `.replace("&amp;", "&")` on extracted URLs
- Communicates back to parent via stdout: `print("VERIFY_URL:" + verify_url)`

### 5. Verify Email + Individual Account (Camoufox)

```python
page.goto(verify_url, wait_until="domcontentloaded", timeout=30000)
page.wait_for_timeout(5000)

# If on openrouter.ai, click "Individual" (personal account selection)
if "openrouter.ai" in page.url:
    page.get_by_text("Individual", exact=False).first.click()
    page.wait_for_timeout(3000)
```

### 6. Extract API Key (Camoufox)

After visiting the verify URL and clicking "Individual", the user is auto-logged in. The script stays on the current page and looks for the key inline — it does NOT explicitly navigate to `/workspaces/default/keys` (the post-verify redirect lands on a page where the key is already visible in a `<code>` block).

The verify step uses `Camoufox(headless=False, humanize=True, enable_cache=True, persistent_context=True, user_data_dir=cam_tmpdir)` — `humanize=True` helps avoid bot detection on the post-verify redirect.

**Three extraction methods (tried in order):**

```python
# 1. <code> block (primary — key shown in fetch code snippet)
code_text = page.locator("code").inner_text(timeout=5000)
match = re.search(r"sk-or-v1-[a-zA-Z0-9]+", code_text)

# 2. Copy button + clipboard
page.locator('button:has-text("Copy")').first.click()
clipboard = page.evaluate("navigator.clipboard.readText()")
match = re.search(r"sk-or-v1-[a-zA-Z0-9]+", clipboard)

# 3. Full HTML regex (last resort)
html = page.content()
match = re.search(r"sk-or-v1-[a-zA-Z0-9]{20,}", html)
```

### 7. Save Credentials

Append to `openrouter_credentials.txt`: `EMAIL=`, `PASSWORD=`, `API_KEY=`

## Retry Logic

- Main loop: 3 signup attempts
- If Step 3 returns `NOT_FOUND` (email not found after 5 inbox retries):
  - Generate fresh email via `email.sh`, new password
  - Restart from Step 2
- After 3 failures: print "FAILED: 3 signup attempts exhausted."

## Playwright coreBundle.js Patch

Camoufox Firefox crashes on Proton Mail because `pageError.location` is undefined in the Juggler driver. Patch before running:

```bash
COREBUNDLE="$(python3 -c 'import playwright; print(playwright.__path__[0])')/driver/package/lib/coreBundle.js"
sed -i 's/url: pageError\.location\.url/url: (pageError.location \&\& pageError.location.url) || ""/g' "$COREBUNDLE"
sed -i 's/line: pageError\.location\.lineNumber/line: (pageError.location \&\& pageError.location.lineNumber) || 0/g' "$COREBUNDLE"
sed -i 's/column: pageError\.location\.columnNumber/column: (pageError.location \&\& pageError.location.columnNumber) || 0/g' "$COREBUNDLE"
```

## Pitfalls

- **Credential file accumulates partial results** — Each run appends to `openrouter_credentials.txt`. Failed attempts (where API_KEY=NOT_FOUND) are still written. When reading the file, check the API_KEY value — if it's `NOT_FOUND`, that account is unusable. The file is append-only, so old failed entries remain unless manually cleaned.
- **Email from stdout, not mail.txt** — `email.sh` prints email to stdout; capture last line with `@` sign. Subprocess env needs venv PATH + VIRTUAL_ENV + PYTHONPATH.
- **Proton search input is readonly** — Must use `keyboard.type()` after `/` shortcut, not `.fill()`.
- **`get_by_label("Password")` resolves to 2 elements** — The input + "Show password" button. Use `#password-field` selector instead.
- **6-digit sign-in code (factor-two) must NOT be automated** — User explicitly rejected this ("6 digit do not involve in py"). Do not add code-fetch subprocesses for sign-in codes; user enters manually.
- **Confirm-email detection is dual-signal** — Check both URL and body text.
- **`persistent_context=True` requires `user_data_dir`** — TypeError if missing.
- **`&amp;` escaping** — Verification URLs from Proton frames have HTML-escaped ampersands; always `.replace("&amp;", "&")`.
- **Verify step uses `humanize=True`** — The `do_verify_and_key` Camoufox instance uses `humanize=True` (in addition to `headless=False`) for the post-verify page. This reduces bot detection risk on the redirect chain after clicking the verification link. The signup step does NOT use `humanize=True` (only `headless=False`).
