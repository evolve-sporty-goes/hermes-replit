# Full TorBox Signup Pipeline (2026-06-28)

## Overview

The `scripts/torbox-full-signup.sh` script merges three independent flows into a single end-to-end TorBox account creation + verification + API key extraction pipeline.

## Pipeline Architecture

```
┌─────────────────────────────────────────────────────────────┐
│ Step 1: Signup via Tor + FlareSolverr                       │
│   curl → FlareSolverr (headless Chrome + Tor SOCKS5)        │
│   → solves Cloudflare JS challenge                          │
│   → extracts cf_clearance cookie + User-Agent               │
│   → Python + PySocks replays cookie → POST /auth/v1/signup  │
│   Output: user_id, confirmation_sent_at                     │
├─────────────────────────────────────────────────────────────┤
│ Step 2: Verify URL via Playwright + Proton (NO Tor)         │
│   Playwright (headless=False → fallback headless=True)      │
│   → logs into Proton Mail via persistent profile            │
│   → searches inbox for TorBox verification email            │
│   → extracts verify URL from email body/iframe             │
│   Output: verify_url                                        │
├─────────────────────────────────────────────────────────────┤
│ Step 3: Verify + API Key via Playwright + Tor               │
│   Playwright (headless=False → fallback headless=True)      │
│   → proxy: socks5://127.0.0.1:9050                          │
│   → visits verify URL (CF auto-solved by real browser)      │
│   → logs into TorBox dashboard                              │
│   → navigates to /settings                                  │
│   → extracts API key (regex on page text + input values)    │
│   → fallback: fetch /api/user/me via page context          │
│   Output: api_key, demo_info (plan, slots)                  │
└─────────────────────────────────────────────────────────────┘
```

## Why This Architecture

### Step 1: FlareSolverr (not raw Playwright)
The signup is a single POST request. Using Playwright just to execute one fetch is heavyweight. FlareSolverr is lighter (API call, returns cookies in ~5s) and lets us use raw `urllib`/PySocks for the actual POST — no browser kept alive.

### Step 2: No Tor (Proton verification)
Proton Mail may block Tor exit nodes or present additional challenges. Running Playwright without a proxy for the Proton step is more reliable. The verify URL extraction doesn't need anonymity — it needs reliability.

### Step 3: Playwright + Tor (not FlareSolverr)
Step 3 requires multi-page browser interaction (verify → login → dashboard → settings). This is pure browser automation, so Playwright directly is the right tool. The real browser auto-solves Cloudflare on `page.goto()` — no FlareSolverr needed. The Tor proxy provides anonymity for the session.

### headless=False with Fallback
The user requested visible browsers where possible. Each Playwright step tries `headless=False` first:
- **With display** (X11/Wayland): browser window visible for debugging
- **Without display**: throws exception → catch block launches `headless=True`

This is controlled per-step, not globally, so step 2 could be visible while step 3 falls back (or vice versa).

## Shell Quoting Strategy

Long secrets (anon_key ~208 chars, cookies, user agents) break shell interpolation. The script writes all values to `/tmp/tb_*.txt` files first, then reads them inside Python scripts:

```bash
echo -n "$ANON_KEY"   > /tmp/tb_anon_key.txt
echo -n "$COOKIE_STR" > /tmp/tb_cf_cookies.txt
```

```python
with open('/tmp/tb_anon_key.txt') as f: anon_key = f.read().strip()
```

This avoids all quoting/escaping issues. Never interpolate long tokens directly into shell heredocs.

## RANDOM in Bash

`$RANDOM` is a bash built-in (0-32767). When using Python, use `random.randint(10000, 99999)` instead. The script generates the email in bash (`EMAIL="${EMAIL_PREFIX}+${RAND}@proton.me"`) but the value is written to `/tmp/tb_email.txt` for Python to read.

## Error Handling

- **Step 1 fails** (no CF cookies) → exit 1
- **Step 2 fails** (verify URL not found) → writes partial credentials with `magic_link=NOT_FOUND`, exit 1
- **Step 3 partial** (API key not found) → writes credentials with `api_key=NOT_FOUND`, continues

Partial results are always written — the user can complete manual steps with the partial data.

## Credential File Format

Appended to `torbox_credentials.txt`:

```
email=bavmin+80589@proton.me
password=Satyana@1234
user_id=<uuid>
magic_link=https://db.torbox.app/auth/v1/verify?token=...&type=magiclink&redirect_to=...
api_key=<32+ char hex/uuid>
demo_info={"plan":"free","slots":"1"}
```
