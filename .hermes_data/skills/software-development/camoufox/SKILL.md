---
name: camoufox
description: "Camoufox anti-fingerprint browser: install, launch, and use for stealth browser automation. Covers the Python package, binary download, CLI manager (sync/set/fetch), prerelease channels, launcher scripts, and Playwright integration."
version: 2.0.0
author: Hermes Agent
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [camoufox, browser, automation, anti-fingerprint, playwright, stealth]
    related_skills: []
---

# Camoufox Anti-Fingerprint Browser
# Camoufox Anti-Fingerprint Browser

Camoufox is an open-source anti-detect Firefox fork built for web scraping & AI agents. It patches browser fingerprints (canvas, WebGL, fonts, User-Agent, etc.) at the C++ level to bypass bot detection on sites like CreepJS, Bot Sannysoft, and similar fingerprinting services.

## When to Use

- User asks to test a site with camoufox / check fingerprint score
- User needs stealth browser automation that evades bot detection
- Browser automation on anti-bot-protected sites
- Comparing camoufox vs vanilla Playwright/Puppeteer fingerprint

## Architecture

Camoufox has two parts:

1. **Python package** (`camoufox`) — provides the Playwright-compatible API, CLI manager, and handles browser binary download
2. **Browser binary** — a patched Firefox build with fingerprint randomization, stored in `~/.cache/camoufox/`

The Python package wraps Playwright and auto-generates fingerprints via [BrowserForge](https://github.com/daijro/browserforge) that mimic real-world device distribution. It also handles proxy-aware geolocation/timezone/locale spoofing.

## Installation

### Python Package

The actively maintained package is `cloverlabs-camoufox` (tracks upstream releases more closely and includes per-context fingerprint patches):

```bash
pip install cloverlabs-camoufox
```

The older `camoufox` package also works but may lag behind on patches:

```bash
pip install -U camoufox[geoip]
```

The `geoip` extra is recommended if using proxies — it downloads a MaxMind GeoLite2 database to determine the user's timezone, country, and locale from the proxy IP.

### Browser Binary (cloverlabs-camoufox)

After installing `cloverlabs-camoufox`, sync repos, choose a channel, and fetch:

```bash
python -m camoufox sync
python -m camoufox set official/prerelease   # or official/stable
python -m camoufox fetch
```

The binary lands at `~/.cache/camoufox/browsers/official/<version>/` (use `python -m camoufox path` to confirm).

### Browser Binary (legacy camoufox)

```bash
# Linux & macOS
python3 -m camoufox fetch

# Windows
camoufox fetch
```

### CLI Manager

Camoufox ships with a CLI manager accessible via `python -m camoufox` (or `camoufox` if on PATH). Key commands:

| Command | Purpose |
|---------|---------|
| `sync` | Pull release asset list from GitHub repos |
| `set official/stable` | Follow a channel (stable/prerelease) |
| `set official/prerelease` | Follow latest prerelease builds |
| `set official/stable/134.0.2-beta.20` | Pin a specific version |
| `fetch` | Install the active version |
| `list` | List installed or all available versions |
| `active` | Print current active version |
| `remove` | Remove downloaded data |
| `version` | Show package & browser version info |
| `path` | Print install directory path |
| `test` | Open Playwright inspector |
| `server` | Launch remote Playwright server |

#### Channels

Use `set` to follow a release channel:

```bash
# Default: stable channel
camoufox set official/stable

# Prerelease channel (newest builds, may be unstable)
camoufox set official/prerelease

# Pin exact version
camoufox set official/stable/134.0.2-beta.20
```

After `set`, run `fetch` to download.

#### Multiple Repos

Camoufox supports multiple repos (e.g., `coryking`). Use `set coryking/stable` to switch.

## Basic Usage (Python)

### Sync API

```python
from camoufox.sync_api import Camoufox

with Camoufox() as browser:
    page = browser.new_page()
    page.goto("https://example.com")
```

### Async API

```python
from camoufox.async_api import AsyncCamoufox

async with AsyncCamoufox() as browser:
    page = await browser.new_page()
    await page.goto("https://example.com")
```

### Playwright Compatibility

Camoufox also exposes a Playwright-compatible interface:

```python
from camoufox import sync_playwright

with sync_playwright() as p:
    browser = p.chromium.launch(headless=True)
    page = browser.new_page()
    page.goto("https://bot.sannysoft.com/")
    page.screenshot(path="fingerprint.png")
    browser.close()
```

**Important:** Use `p.chromium.launch()` even though it's Firefox under the hood — this is the expected API.

### Fingerprint Configuration

Pass a JSON config to spoof individual properties:

```python
with Camoufox(config={"property": "value"}) as browser:
    ...
```

Unset properties are auto-populated by BrowserForge.

### Fingerprint Presets (v149+ binaries)

For stronger evasion, use real-world fingerprint presets instead of synthesized values:

```python
with Camoufox(fingerprint_preset=True, os="macos") as browser:
    ...
```

This loads real Firefox traffic fingerprints (312 presets for v149–v152).

### Proxy-Aware Spoofing

Camoufox auto-calculates geolocation, timezone, and locale from the proxy's target region to avoid proxy-detection systems:

```python
browser = Camoufox(
    proxy={"server": "socks5://127.0.0.1:9050"}
)
```

## Basic Usage (Bash Launcher)

The user prefers bash launcher scripts over Python. A typical launcher:

```bash
#!/usr/bin/env bash
# camoufox-launch.sh — launch camoufox with a test page
cd /home/runner/workspace
python3 - "$@" << 'PYEOF'
import sys
from camoufox import sync_playwright

target_url = sys.argv[1] if len(sys.argv) > 1 else "https://bot.sannysoft.com/"

with sync_playwright() as p:
    browser = p.chromium.launch(headless=False)
    page = browser.new_page()
    page.goto(target_url)
    page.wait_for_load_state("networkidle")
    print(f"Title: {page.title()}")
    print(f"URL: {page.url}")
    browser.close()
PYEOF
```

Make it executable: `chmod +x camoufox-launch.sh`

## Fingerprint Test Sites

Common sites used to verify camoufox's fingerprint evasion:

| Site | What it tests |
|------|--------------|
| `https://bot.sannysoft.com/` | Comprehensive bot detection (WebGL, canvas, fonts, audio) |
| `https://creepjs.com/` | Deep fingerprint scoring |
| `https://browserleaks.com/` | WebRTC, DNS, canvas, WebGL leaks |
| `https://arkoselabs.com/` | FunCaptcha/Arkose Labs detection |
| `https://www.sannysoft.com/` | Sannysoft demo (same as bot.sannysoft) |

## Key Technical Details

### C++ Level Spoofing (Not JS Injection)

Camoufox intercepts calls at the browser's C++ implementation level. All hijacked objects and properties appear native — no JavaScript hijacking to be detected. Anti-bot systems cannot detect tampering via `Object.getOwnPropertyDescriptor`, `toString()`, or worker context mismatches.

### Juggler Protocol

Playwright uses CDP for Chromium but **Juggler** for Firefox. Camoufox patches Juggler to give Playwright an isolated "copy" of the page — the real page is completely unaffected by reads/listeners, and inputs go through Firefox's original user input handlers (making them indistinguishable from human input).

### Human-Like Mouse Movement

Camoufox includes a C++ port of [HumanCursor](https://github.com/riflosnake/HumanCursor) for natural, distance-aware mouse trajectories.

### Per-Context Fingerprint Isolation (Patches)

The `cloverlabs-camoufox` package (updated more frequently) supports per-context fingerprint isolation via `context.addInitScript()`. Each Playwright context gets a unique identity via `userContextId`. 16 JavaScript functions exposed to the page self-destruct after first call:

| Function | What it controls |
|----------|-----------------|
| `window.setFontSpacingSeed(seed)` | Canvas `measureText()` letter spacing |
| `window.setAudioFingerprintSeed(seed)` | Audio buffer/analyser fingerprint hash |
| `window.setTimezone(tz)` | `Date`, `Intl.DateTimeFormat` |
| `window.setScreenDimensions(w, h)` | `screen.width`, `screen.height` |
| `window.setScreenColorDepth(depth)` | `screen.colorDepth` |
| `window.setNavigatorPlatform(platform)` | `navigator.platform` |
| `window.setNavigatorOscpu(oscpu)` | `navigator.oscpu` |
| `window.setNavigatorHardwareConcurrency(cores)` | `navigator.hardwareConcurrency` |
| `window.setNavigatorUserAgent(ua)` | `navigator.userAgent` |
| `window.setWebRTCIPv4(ip)` | WebRTC ICE candidates, SDP |
| `window.setWebRTCIPv6(ip)` | WebRTC IPv6 addresses |
| `window.setWebGLVendor(vendor)` | `UNMASKED_VENDOR_WEBGL` |
| `window.setWebGLRenderer(renderer)` | `UNMASKED_RENDERER_WEBGL` |
| `window.setCanvasSeed(seed)` | Canvas 2D `toDataURL()`/`getImageData()` hash |
| `window.setFontList(fonts)` | Which fonts appear "installed" |
| `window.setSpeechVoices(voices)` | `speechSynthesis.getVoices()` filtering |

### Debloat & Optimizations

- Stripped Mozilla services (200MB memory)
- uBlock Origin with custom privacy filters bundled
- No CSS animations
- Speed & network optimizations from FastFox/LibreWolf/Ghostery
- Firefox addons support (pass paths to `addons` property)

### Version Compatibility

Camoufox versions pin to specific Firefox builds. The Python package version (e.g., 0.5.2) is independent of the browser version (e.g., 135.0.1-beta.24). Use `camoufox version` to see both.

## Troubleshooting

### Fetch interrupted during extraction (exit code 130)

On resource-constrained environments (e.g. Replit, containers), `python -m camoufox fetch` may download successfully but get interrupted during extraction (exit 130 / SIGINT). The `~/.cache/camoufox/browsers/<version>/` directory will be partially extracted and missing critical files (lib, fonts, etc.).

**Fix:** Run the fetch again. The CLI skips the download if already complete and retries extraction:

```bash
python -m camoufox fetch
```

If it keeps failing, clean the broken extraction first:

```bash
python -m camoufox remove
rm -rf ~/.cache/camoufox
python -m camoufox fetch
```

Verify success:

```bash
python -m camoufox version
# Should show: Camoufox: <version>  (not "Not downloaded!")
```

### Binary not found / download fails

If `~/.cache/camoufox/` doesn't contain the browser after install:

```bash
# Force re-download
rm -rf ~/.cache/camoufox/browsers/
python3 -c "from camoufox.sync_api import launch; launch(headless=True).close()"
```

### Headless detection

Some sites detect headless mode. Use `headless=False` for stealth, or set a custom viewport:

```python
browser = p.chromium.launch(
    headless=False,
    args=["--window-size=1920,1080"]
)
```

### Tor integration

For additional anonymity, chain camoufox with Tor:

```bash
# Start tor service first
tor &
# Then launch camoufox with proxy
```

```python
browser = p.chromium.launch(
    proxy={"server": "socks5://127.0.0.1:9050"}
)
```

### Version compatibility

If you upgrade the Python package, clear the old binary:

```bash
pip install --upgrade camoufox
rm -rf ~/.cache/camoufox/browsers/
# Next launch will download the matching binary
```

### Prerelease channel

To get the newest browser patches (may be unstable):

```bash
camoufox set official/prerelease
camoufox fetch
```

Or install the `cloverlabs-camoufox` package which tracks releases more closely:

```bash
pip install cloverlabs-camoufox
python -m camoufox sync
python -m camoufox set official/prerelease
python -m camoufox fetch
```

## Reference Files

- `references/binary-path-layout.md` — exact filesystem layout of `~/.cache/camoufox/`, how to resolve the active binary path from `config.json`, and why hardcoding breaks.
- `references/proton-mail-chromium-workaround.md` — full pattern for Chromium fallback when camoufox crashes on Proton Mail, including encrypted email extraction.
- `references/firecrawl-signup-workflow.md` — complete end-to-end workflow for Firecrawl account signup, email verification, and API key extraction (camoufox + Chromium hybrid).
- `references/openrouter-signup-workflow.md` — OpenRouter account signup via camoufox: sign-up form, Proton Mail verification link extraction, auto-login after verify, and API key extraction from inline `<code>` block.
- `references/torbox-signup-workflow.md` — TorBox (torbox.app) account signup, email verification, API key extraction, and Nuvio addon setup. **Two approaches:** A) Lightweight bash using Supabase API (bypasses Cloudflare, no Camoufox needed) and B) Full Python with Camoufox + Chromium hybrid (for API key + Nuvio).
- `references/cloudflare-challenge-handler.md` — auto-click Cloudflare/Turnstile challenges by iterating `page.frames` — covers both the inline frame pattern and the `challenges.cloudflare.com` iframe pattern.
- `references/persistent-profile-tmpdir.md` — use `persistent_context=True` + `user_data_dir=tempfile.mkdtemp()` to share cookies/state across multiple Camoufox steps, with `atexit` + `shutil.rmtree` cleanup.
- `references/proxy-and-vpn-patterns.md` — free SOCKS5 proxy setup, Tor integration, VPN extension loading (and why they don't auto-connect), IP verification, and error handling with proxies.

## Source & Docs

Clone the source to inspect patches, examples, or docs not covered here:

```bash
git clone https://github.com/daijro/camoufox.git
```

Key directories:
- `pythonlib/camoufox/` — main package (sync_api, async_api, fingerprints, server, addons)
- `docs/` — patch-upgrading-guide, per-context-patches, playwright-maintenance
- `example/` — usage examples
- `patches/` — Firefox source patches (C++ level fingerprint spoofing)

## Interactive Automation Pattern (Python)

For multi-step browser automation (clicking buttons, filling forms, taking screenshots), write a Python script inline in a bash launcher:

```bash
#!/usr/bin/env bash
# camoufox-task.sh — run a camoufox automation task
cd /home/runner/workspace
python3 - "$@" << 'PYEOF'
import sys
import time
from camoufox.sync_api import Camoufox

# Resolve binary path dynamically
import json, os
cache_dir = os.path.expanduser("~/.cache/camoufox")
config_path = os.path.join(cache_dir, "config.json")
with open(config_path) as f:
    active = json.load(f)["active_version"]
binary = os.path.join(cache_dir, active, "camoufox")

target_url = sys.argv[1] if len(sys.argv) > 1 else "https://example.com"

with Camoufox(
    headless=False,
    args=["--window-size=1920,1080"],
    executable_path=binary,
) as browser:
    page = browser.new_page()
    page.goto(target_url)
    page.wait_for_load_state("networkidle")
    time.sleep(3)

    # Click a button by role/text
    button = page.get_by_role("button", name="Get Started")
    if button.count() > 0:
        button.first.click()
        page.wait_for_load_state("networkidle")
        time.sleep(2)

    print(f"Title: {page.title()}")
    print(f"URL: {page.url}")
    page.screenshot(path="/home/runner/workspace/task-result.png")
    print("Screenshot saved: task-result.png")
PYEOF
```

Key points:
- **Always resolve the binary path from `config.json`** — the path changes with versions and is NOT `~/.cache/camoufox/camoufox`.
- Use `page.get_by_role()` or `page.get_by_text()` for resilient element selection.
- Always `wait_for_load_state("networkidle")` after navigation and clicks.
- Screenshots at each step help debug multi-step flows.

## Pitfalls

1. **Don't mix with system Firefox** — Camoufox uses its own binary. System Firefox profiles are irrelevant.
2. **`p.firefox` vs `p.chromium`** — The API exposes `p.chromium` even though it's Firefox. Always use `p.chromium.launch()`.
3. **Lazy binary download** — The binary downloads on first `launch()`, not on `pip install`. Expect a delay the first time.
4. **Headless=True is more detectable** — Use `headless=False` when stealth matters.
5. **Cache location** — `~/.cache/camoufox/` is the default. Don't put it on tmpfs (lost on reboot on some platforms).
6. **JS injection detection** — Camoufox does NOT use JS injection. All spoofing is at the C++ level. This is a key advantage over other solutions.
7. **Chromium fingerprints not fully supported** — Some WAFs test for Spidermonkey engine behavior which cannot be spoofed (Camoufox is Firefox-only).
8. **Per-context patches require cloverlabs-camoufox** — The main `camoufox` package may not have the latest per-context fingerprint isolation patches.
9. **Binary path is NOT `~/.cache/camoufox/camoufox`** — The actual binary lives at `~/.cache/camoufox/browsers/<channel>/<version>/camoufox`. Read `config.json` → `active_version` to find it, or run `python -m camoufox path`. Hardcoding the path breaks on version upgrades.
10. **Config file location** — `~/.cache/camoufox/config.json` contains `{"active_version": "browsers/official/<version>"}`. Always check this if `Camoufox()` fails with "executable not found".
11. **Fetch extraction can be interrupted** — On constrained environments, `fetch` may succeed on download but fail during extraction (exit 130). Re-run `fetch` to retry extraction, or `remove` + clean cache first. Verify with `python -m camoufox version` — should show a version, not "Not downloaded!".
12. **Use `cloverlabs-camoufox` for latest patches** — The `cloverlabs-camoufox` package is actively maintained with per-context fingerprint isolation. Install with `pip install cloverlabs-camoufox`, then `sync`/`set`/`fetch` via `python -m camoufox`.
28. **Camoufox crashes on Proton Mail** — Camoufox Firefox engine throws `TypeError: Cannot read properties of undefined (reading 'url')` when navigating proton.me pages (login, inbox). **Root cause:** `pageError.location` is undefined in Playwright's `coreBundle.js` Juggler handler. **Fix 1 (patch):** Guard `pageError.location` before accessing `.url`/`.lineNumber`/`.columnNumber` in `coreBundle.js` — see `references/proton-mail-chromium-workaround.md` for the sed commands. **Fix 2 (subprocess):** If patch isn't sufficient, run Proton Mail logic in a Chromium subprocess (`subprocess.run`) to avoid both the crash and the asyncio event-loop conflict with Camoufox. Camoufox works fine for all other sites (firecrawl.dev, openrouter.ai, etc.).
29. **Cloudflare/Turnstile challenge blocks signup/login flows** — After clicking submit/continue on Cloudflare-protected sites, a Turnstile checkbox may appear inside an iframe. The page stalls until clicked. **Pattern (VERIFIED — works reliably in production, Jun 2026):** Iterate `page.frames`, find the frame with `challenges.cloudflare.com` in URL or "cloudflare" in name, then `frame.locator("#challenge-stage, .ctp-checkbox, body").first.click()` + 4s wait. See `references/cloudflare-challenge-handler.md`.
30. **Multi-step workflows need persistent profile** — When a workflow spans multiple steps (signup → verify → signin → extract), each `Camoufox()` call normally starts with a blank profile. Use `persistent_context=True, user_data_dir=tempfile.mkdtemp()` to share cookies/state across steps. Register an `atexit` handler with `shutil.rmtree` to clean up. See `references/persistent-profile-tmpdir.md`.
14. **`wait_for_url` with glob patterns fails** — `page.wait_for_url("**/onboarding")` times out. Use a polling loop checking `page.url` instead: `for i in range(30): time.sleep(2); if "/signin" not in page.url: break`.
15. **Form submission hangs on "Loading..."** — If `get_by_role("button", name="Sign in").click()` results in a stuck "Loading..." state, try `page.keyboard.press("Enter")` after filling fields, or add longer waits (15-30s).
18. **Firecrawl API key is masked in UI** — The API Keys page shows `fc-1f985•••••30ab9efb`. The full key is NOT in the page HTML, and `/api/me` is a Next.js frontend route (returns HTML, NOT JSON). **Primary extraction:** Navigate to `/app/api-keys`, then click the eye icon: `page.click("button:has(.lucide-eye)")` — this toggles the key from masked to visible. Then read: `page.locator("text=fc-").first.text_content().strip()`. Fallbacks: (1) `page.click("button:has(.lucide-eye-off)")` if eye-off variant, (2) click `[aria-label="Copy"]` + `navigator.clipboard.readText()`, (3) regex `fc-[a-zA-Z0-9]{20,}` against page HTML.
19. **Firecrawl signup: password must contain special character** — Firecrawl rejects passwords without at least one special character (`!@#$%`). Error message: "Password must contain at least one special character." Generate passwords that include at least one of these.
20. **Firecrawl sign-in button text is "Sign in" (lowercase 'in')** — Using `get_by_role("button", name="Sign In")` (capital I) causes strict mode violation. Use exact: `get_by_role("button", name="Sign in", exact=True)`.
21. **Duck email generation via bash script** — The `email.sh` script calls `duckmail.py` internally, prints the email to stdout, and appends to `mail.txt`. **Capture from stdout** (last line containing `@`), not `mail.txt`. Subprocess env MUST include: venv `PATH`, `VIRTUAL_ENV`, and `.pythonlibs` in `PYTHONPATH` — otherwise `duckmail.py` can't find `camoufox` (installed in `.pythonlibs`, not system python). Do NOT call `duckmail.py` directly when `email.sh` is available.
22. **Proton login: navigate to `account.proton.me/login` with 60s timeout** — Always start at `https://account.proton.me/login` (not `mail.proton.me`) with `timeout=60000`. Check if "Mail" link is visible (already logged in) before entering credentials. After submit, wait 10s, then click `a:has-text('Mail')` with `timeout=0` and wait 5s.
23. **Verification link contains `&amp;`** — URLs extracted from Proton Mail frame HTML have HTML-escaped ampersands (`&amp;` instead of `&`). This breaks query parameter parsing on redirect. Always apply `.replace("&amp;", "&")` before visiting the link.
24. **OpenRouter signup: verification email from `noreply@openrouter.ai`** — The verification email subject is "Verify your email" (not "Confirm Your Signup"). Search Proton Mail inbox for the signup email address (recipient). The verification link format is `https://clerk.openrouter.ai/v1/verify...` (Clerk authentication service, not openrouter.ai directly).
25. **OpenRouter API key extraction** — After email verification, the user is auto-logged in and the key appears inline in a `<code>` block (fetch code snippet). Extract with `page.locator("code").inner_text()` + regex `sk-or-v1-[a-zA-Z0-9]+`. Fallback: "Copy" button + `navigator.clipboard.readText()`, then full HTML regex. The key is NOT behind an eye icon (unlike Firecrawl).
26. **OpenRouter sign-up page: `https://openrouter.ai/sign-up`** — The signup form has email and password fields. After submission, a "Check your email" confirmation appears. Password requirements: no special char enforced at signup (unlike Firecrawl), but the login session may expire quickly if email isn't verified promptly.
27. **OpenRouter confirm-email detection: dual-signal** — After clicking Continue on the signup form, detect success by checking BOTH `page.url` (contains "confirm-email") AND `page.inner_text("body")` (contains "verification" or "check your"). Don't rely on URL alone — the confirmation may render inline without a redirect.
28. **Proton Mail search input is readonly** — The search box (`data-testid="search-keyword"`) is `readonly` until activated. Use `page.keyboard.press("/")` to open search, then `page.keyboard.type(text, delay=50)` to type. `.fill()` silently fails on the readonly input.
29. **Proton persistent profile saves login state** — Use `launch_persistent_context("~/proton_profile", ...)` so Proton login survives across script runs. On repeat runs, check `a:has-text('Mail')` visibility — if visible, skip credential entry and go straight to inbox. Always navigate to `account.proton.me/login` first (not `mail.proton.me`).
30. **OpenRouter API key is in `<code>` block, not eye icon** — After verification, the key appears inside a `<code>` element (fetch code snippet) on the post-verify page. Extract with `page.locator("code").inner_text()` + regex `sk-or-v1-[a-zA-Z0-9]+`. Fallback: "Copy" button + `navigator.clipboard.readText()`.
31. **OpenRouter "Individual" account selection** — After visiting verify URL, if on `openrouter.ai`, the page may show workspace type selection. Click "Individual" text/button to proceed with personal account.
32. **`get_by_label("Password")` can resolve to 2 elements** — On Clerk-based sign-in forms (OpenRouter, etc.), `get_by_label("Password")` matches both the input field and the "Show password" button. Use `page.locator("#password-field")` instead, or `.first` with caution.
33. **OpenRouter 6-digit sign-in code (factor-two) must NOT be automated** — OpenRouter sends a 6-digit verification code on sign-in. **User explicitly rejected automating this in scripts** ("6 digit do not involve in py"). Do NOT add Proton-fetch-code subprocesses for sign-in codes. The user enters it manually if prompted.
34. **Inbox search by signup email address** — When searching Proton inbox for a verification email, search for the signup email address (the recipient) using the `/` shortcut + `keyboard.type(SIGNUP_EMAIL, delay=20)`. This works even for Duck.com relay addresses — Proton indexes the full recipient address. Do NOT search by generic keyword (e.g. "torbox") or sender name; the actual email address is the most precise and reliable search term.
35. **Proton inbox search: `/` shortcut + `keyboard.type()`, NOT `.fill()`** — The search input (`data-testid="search-keyword"`) is readonly until activated. Must use `page.keyboard.press("/")` to open, then `page.keyboard.type(text, delay=50)` to type. `.fill()` silently fails. Press Enter to search, Escape to clear.
36. **Email capture: email.sh stdout, NOT mail.txt** — When `email.sh` runs, capture the email from stdout (last line with `@`), not from `mail.txt`. The subprocess env MUST include venv `PATH`, `VIRTUAL_ENV` set to venv dir, and `.pythonlibs/lib/python3.12/site-packages` in `PYTHONPATH` — otherwise `duckmail.py` inside email.sh can't find `camoufox` (it's in `.pythonlibs`, not system python).
37. **Playwright coreBundle.js patch for Proton Mail crash** — Camoufox Firefox crashes on Proton Mail with `TypeError: Cannot read properties of undefined (reading 'url')` because `pageError.location` is undefined. Patch `coreBundle.js`: guard `pageError.location` before accessing `.url`/`.lineNumber`/`.columnNumber` — replace `url: pageError.location.url` with `url: (pageError.location && pageError.location.url) || ""` (same for line/column). This must be re-done if Playwright is reinstalled/upgraded.
38. **Chromium subprocess for Proton Mail** — Even with the coreBundle.js patch, running Proton Mail in the same process as Camoufox can trigger EPIPE crashes on exit. Run all Proton Mail logic in a `subprocess.run([sys.executable, "-c", SCRIPT, ...])` using Playwright Chromium with `launch_persistent_context("~/proton_profile", ...)`. This isolates the Firefox/Chromium process boundary completely.
39. **Proton Mail search uses `/` keyboard shortcut** — The `/` key opens the search box in Proton Mail inbox. Then `keyboard.type(email, delay=50)` types the search query. Press Enter to execute search, Escape to close/clear. The `?` shortcut also works but `/` is the documented standard.
40. **Proton "Mail" link click: use `timeout=0`** — The `page.locator("a:has-text('Mail')").first.click(timeout=0)` avoids hangs when Proton's UI is slow to respond after login.
41. **Chromium persistent context returns a BrowserContext, not Browser** — `launch_persistent_context()` returns a `BrowserContext` directly. Get the page via `context.pages[0] if context.pages else context.new_page()`. Do NOT call `browser.new_page()` on it.
42. **OpenRouter verify step uses `humanize=True`** — The `do_verify_and_key` Camoufox instance uses `humanize=True` (in addition to `headless=False`) for the post-verify page. This reduces bot detection risk on the redirect chain after clicking the verification link. The signup step does NOT use `humanize=True`.
43. **Credential file accumulates partial results** — Each run of `openrouter_signup.py` appends to `openrouter_credentials.txt`. Failed attempts (where `API_KEY=NOT_FOUND`) are still written. When reading the file, check the API_KEY value — if it's `NOT_FOUND`, that account is unusable. The file is append-only, so old failed entries remain unless manually cleaned.
44. **OpenRouter signup form field IDs** — The Clerk-based signup form uses `#emailAddress-field`, `#password-field`, and `#legalAccepted-field` (not generic names like `#email` or `#password`). The submit button is `get_by_role("button", name="Continue")`. Using wrong selectors causes timeout/not-found errors.
45. **TorBox login URL is `/login` (not `/sign-up`)** — The signup form is accessed by clicking the "Sign up" button on the login page (`https://torbox.app/login`). Selectors: `#email-input`, `#password-input`, `#consent-checkbox`, `button[type='submit']`. **Better: bypass the web form entirely** by calling the Supabase Auth API directly — see `references/torbox-signup-workflow.md` Approach A.
46. **TorBox requires free demo activation before API key** — After registration, the dashboard shows "Get your free demo now!" which must be activated before the API key appears in settings. If settings page has 0 `<input>` elements, activation failed — retry the cycle.
47. **TorBox Proton Mail search uses the signup email address** — Search Proton inbox for the actual signup email address (e.g. `some-words@duck.com`) using the `/` shortcut + `keyboard.type(SIGNUP_EMAIL, delay=20)`. Proton indexes the full recipient address even for Duck.com relay. Do NOT search by generic keyword like "torbox".
48. **TorBox Nuvio manifest URL** — `https://torrentio.strem.fun/sort=size|qualityfilter=cam,unknown,720p,480p,other,scr|torbox={api_key}/manifest.json` — built into the script, no need to reconstruct manually.
49. **TorBox fallback login uses `config.TORBOX_PASSWORD`** — The registration password is random, but if the session expires and the script needs to re-login (e.g. on settings page), it uses the static `TORBOX_PASSWORD` from config.
50. **Loading VPN extensions into Camoufox does NOT auto-connect** — Pass `addons=['/path/to/extracted-addon-dir']` to `Camoufox()`. The XPI must be extracted first (it's a ZIP). Passing the `.xpi` file directly raises `InvalidAddonPath`. But even loaded, extensions like SetupVPN, Windscribe, and Browsec **require user interaction** (clicking "Connect" in the popup) — they do NOT route traffic automatically. For zero-touch IP masking, use a free SOCKS5 proxy (`proxy={'server': 'socks5://IP:PORT'}`) instead.
51. **Replit workspace-local cache** — On Replit, the Camoufox binary may be at `/home/runner/workspace/.cache/camoufox/camoufox` (workspace-local) instead of `~/.cache/camoufox/`. Always verify with `python3 -m camoufox path` or check both locations.
52. **Tor bootstrap on Replit Nix** — Tor takes 2-3 minutes to bootstrap because directory fetches are throttled. Outbound connections to non-standard ports (9001, 9030) may be blocked; port 443 OR connections work. Wait for "Bootstrapped 100%" before testing. **Faster alternative:** free SOCKS5 proxies (e.g., from `https://api.proxyscrape.com/v2/?request=displayproxies&protocol=http&timeout=10000&country=all&ssl=all&anonymity=all`) — they're instant and zero-touch. Always pass `geoip=True` with any proxy.
53. **TargetClosedError with proxies** — When using SOCKS5 proxies, pages may hang or the browser may close unexpectedly (especially after Cloudflare challenges). Wrap Camoufox calls in try/except and retry with fresh credentials:
```python
try:
    with Camoufox(headless=False, persistent_context=True, user_data_dir=tmpdir, geoip=True, proxy={'server': 'socks5://IP:PORT'}) as browser:
        register(browser, email, password)
except Exception as e:
    print(f"Step failed: {e}")
    # Retry with fresh email/password
    continue
```
Also: move Cloudflare challenge handling to **after** form submit (not just before), as challenges often appear post-submit when using proxies.

## Proton Mail: Chromium Fallback Pattern

Camoufox's Firefox Juggler driver crashes on proton.me due to a JS error in the internal `coreBundle.js`. The fix is to use system Chromium for Proton Mail access while keeping camoufox for anti-fingerprint sites.

```python
from playwright.sync_api import sync_playwright

CHROMIUM_PATH = "/nix/store/<hash>-chromium-<version>/bin/chromium"

with sync_playwright() as p:
    ctx = p.chromium.launch_persistent_context(
        os.path.expanduser("~/proton_profile"),
        executable_path=CHROMIUM_PATH,
        headless=True,
        args=["--no-sandbox", "--disable-gpu"]
    )
    pg = ctx.new_page()

    # Login to Proton
    pg.goto("https://account.proton.me/login", timeout=60000)
    pg.wait_for_timeout(3000)
    already_logged_in = False
    try:
        if pg.locator("a:has-text('Mail')").is_visible(timeout=3000):
            already_logged_in = True
    except:
        pass
    if not already_logged_in:
        pg.locator("#username").fill(config.PROTON_USERNAME)
        pg.locator("#password").fill(config.PROTON_PASSWORD)
        pg.locator("button[type='submit']").click()
        pg.wait_for_timeout(10000)
        pg.locator("a:has-text('Mail')").first.click(timeout=0)
        pg.wait_for_timeout(5000)

    # ... rest of Proton Mail automation ...
```

**Note:** Playwright's own browser binaries may not be installed on Nix/Replit. Use the system Chromium path from `/nix/store/` instead of bare `p.chromium.launch()`. Also: `launch_persistent_context` returns a `BrowserContext` directly — use `ctx.new_page()` to get a page.

## Proton Mail: Login + Inbox Search Pattern

Login to Proton and search inbox for a specific email. **Always navigate to `account.proton.me/login` first** (not `mail.proton.me`) with a 60s timeout, then check if already logged in before entering credentials:

```python
# Login to Proton
page.goto("https://account.proton.me/login", timeout=60000)
page.wait_for_timeout(3000)

already_logged_in = False
try:
    mail_link = page.locator("a:has-text('Mail')")
    if mail_link.is_visible(timeout=3000):
        already_logged_in = True
except:
    pass

if already_logged_in:
    print("Already logged in to Proton — skipping credentials")
else:
    page.locator("#username").fill(config.PROTON_USERNAME)
    page.locator("#password").fill(config.PROTON_PASSWORD)
    page.locator("button[type='submit']").click()
    page.wait_for_timeout(10000)
    page.locator("a:has-text('Mail')").first.click(timeout=0)
    page.wait_for_timeout(5000)

# Navigate to inbox
page.goto("https://mail.proton.me/u/0/inbox", timeout=30000)
page.wait_for_timeout(2000)

# Search by the signup email address (works even for Duck.com relay)
for attempt in range(7):
    page.keyboard.press("/")          # open Proton search
    page.wait_for_timeout(800)
    page.keyboard.type(search_email, delay=20)  # the actual signup email
    page.keyboard.press("Enter")
    page.wait_for_timeout(4000)
    items = page.locator(".item-container,.message-item,[data-testid='message-item']")
    if items.count() > 0:
        items.first.click()
        page.wait_for_timeout(2000)
        break
    page.keyboard.press("Escape")
    page.wait_for_timeout(2000)
```

Key points:
- **Use the `/` keyboard shortcut** to open search (NOT `.fill()` — the input is readonly)
- **Search by the signup email address** — Proton indexes the full recipient address, even for Duck.com relay
- **Click the first matching result** directly
- `.fill()` silently fails on Proton's readonly search input

## Proton Mail: Encrypted Email Content Extraction

Proton Mail uses zero-access encryption. The email body is NOT accessible via `page.inner_text("body")` — it only shows metadata (From, To, Subject, Time). To extract links (e.g. verification links) from encrypted emails:

```python
# After clicking the email in inbox, search all frames for the link
verify_url = None
for frame in page.frames:
    try:
        html = frame.content()
        if "verify" in html.lower():
            matches = re.findall(
                r'https://service\.example\.com/verify[^\s"\'<>]+',
                html
            )
            if matches:
                verify_url = matches[0]
                break
    except:
        pass
```

The email body content lives in `page.frames[3].content()` (frame index may vary — iterate all frames).

## User Workflow Preference

When the user asks to execute a multi-step account-creation workflow (signup, verify email, signin, extract API key), consolidate into a single reusable script file rather than executing step-by-step interactively. The user said "write all you have done in one script" — they want a reusable artifact, not a live demo. This applies to any target site (Firecrawl, OpenRouter, etc.) — see the site-specific reference files for the per-site details.

**No throwaway helper scripts for routines** — When automating recurring agent behaviors (e.g. "always update notes on verification"), express them as in-agent memory rules, NOT as standalone bash/Python helper scripts. The user explicitly rejected `append-note.sh` / `verify-and-note.sh` in favor of a memory-stored rule that the agent follows directly. Helper scripts are acceptable for complex multi-step automation (like `email.sh` or `openrouter_signup.py`), but simple behavioral hooks belong in memory/skill rules, not the filesystem.

**Sensitive file lists: bare paths only** — When listing files containing secrets (e.g. in `sensitive.txt`), include ONLY bare file paths — no severity tiers, no labels, no descriptions, no comments. User explicitly rejected tiers. Files that merely *call* other sensitive scripts are NOT sensitive themselves; only files with hardcoded secret values qualify. Email addresses in code ARE sensitive. Session dumps and mail.txt are NOT sensitive. `sync.sh` reads `sensitive.txt` dynamically (not hardcoded) to sync to hermes-secrets repo, and auto-updates `.gitignore` from it.

**Session notes on verification** — When the system verification prompt fires, always append a timestamped entry to the Obsidian vault session notes (`## Timeline` section of `YYYY-MM-DD.md`) with: verification result (PASS/FAIL), what was checked, command ran, and output snippet. This is an in-agent rule, not a script.

**Keep automation scripts minimal** — When the user asks for a script, write only the essential logic: get input, do the thing, save output. No command-line arg parsing, no help flags, no multi-account numbering, no feature flags the user didn't ask for. The user has repeatedly rejected over-engineered scripts and asked to simplify: "make script short", "I don't need such functions", "generate password always" (remove the option to pass a password). When a script needs credentials, import from `~/config.py` (user's existing config) rather than creating new config/arg systems. Use append (`>>`) for credential output files, never overwrite (`>`).

**Supabase Auth API bypasses Cloudflare Turnstile** — Sites using Supabase Auth (e.g. `db.torbox.app`) can be signed up directly via `POST /auth/v1/signup` with the public anon key (embedded in the frontend JS bundle as a JWT with `role: "anon"`). This avoids Cloudflare Turnstile challenges entirely — no browser automation needed for the signup step. Extract the anon key from the JS bundle with regex `eyJhbG[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+`. Store in `.hermes_data/.env` as `SUPABASE_ANON_KEY`.
