# Proton Mail Verification with cloakbrowser

## Overview

Extract magic-link / verify URLs from Proton Mail for any service (TorBox, etc.).

## Files

- `scripts/proton_verify.py` — Reusable Python module with `get_verify_url(email, search)` function
- `scripts/proton_verify.sh` — Bash wrapper for CLI usage

## Usage

### Bash (CLI)
```bash
bash /home/runner/workspace/scripts/proton_verify.sh <email> [search_query]

# Examples
bash proton_verify.sh "user@duck.com" "torbox"
bash proton_verify.sh "user@duck.com" "verify"
bash proton_verify.sh "user@duck.com" "confirm"
```

### Python (import)
```python
from scripts.proton_verify import get_verify_url

url = get_verify_url("user@duck.com", "torbox")
if url != "NOT_FOUND":
    print(f"Verify URL: {url}")
```

## Key Implementation Details

### Browser Setup
```python
os.environ["DISPLAY"] = ":1"
ctx = launch_persistent_context(
    PROFILE=os.path.expanduser("~/proton_profile"),
    headless=False,
    humanize=True
)
```

- `headless=False` + `DISPLAY=:1` — uses real X11 display (no xvfb)
- `humanize=True` — anti-detection (mouse movements, timing)
- Persistent profile (`~/proton_profile`) — saves Proton login session

### Login Flow
1. Navigate to `https://account.proton.me/login`
2. Check if already logged in (Mail link visible)
3. If not: fill username/password from `config.PROTON_USERNAME` / `config.PROTON_PASSWORD`
4. Click Mail link → wait for inbox load

### Search & Extract
- Uses `/` keyboard shortcut to focus search
- `keyboard.type(search, delay=20)` — input is readonly, `.fill()` fails
- Iterates up to 7 attempts with reload/wait
- Extracts verify URL via:
  1. `frame.eval_on_selector_all("a[href]", "els=>els.map(e=>e.href)")` — Playwright auto-decodes `&` → `&`
  2. Fallback: regex on raw HTML for `verify`|`confirm` in URL

### Matching Logic
```python
if ("verify" in href.lower() or "confirm" in href.lower()):
```
**Excludes** `awstrack.me` forgotpw links — only matches TorBox verify/confirm URLs.

## Dependencies

- `cloakbrowser` — wrapper around Playwright with humanization
- `config` module in `~` with `PROTON_USERNAME`, `PROTON_PASSWORD`

## Troubleshooting

| Issue | Fix |
|-------|-----|
| "Mail" link not found | Increase timeout, check selector |
| Search input readonly | Use `keyboard.type()` not `.fill()` |
| Turnstile challenge on Proton | `humanize=True` usually bypasses; if not, increase waits |
| Session expired | Delete `~/proton_profile` to force fresh login |
| NOT_FOUND | Check search query; try broader term like "torbox" |