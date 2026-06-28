# Proxy, VPN, and IP Masking Patterns for Camoufox

## Decision Matrix

| Approach | Auto-Connect | Zero-Touch | Reliability | Setup Complexity |
|----------|-------------|------------|-------------|------------------|
| Free SOCKS5 proxy | Yes | Yes | Medium (proxies die) | Low |
| Paid SOCKS5 proxy | Yes | Yes | High | Low |
| Tor | Yes (after bootstrap) | Yes | Medium (2-3 min bootstrap) | Medium |
| Browser VPN extension | **No** (needs click) | **No** | Low | Low |
| HTTP proxy | Yes | Yes | Low (leaks DNS) | Low |

## Free SOCKS5 Proxy (Recommended for Automation)

### Pattern
```python
from camoufox.sync_api import Camoufox

with Camoufox(
    headless=False,
    geoip=True,  # ALWAYS with proxies — matches timezone/locale to exit IP
    proxy={'server': 'socks5://IP:PORT'}
) as browser:
    ...
```

### Getting Proxies
```python
import urllib.request
req = urllib.request.Request(
    'https://api.proxyscrape.com/v2/?request=displayproxies&protocol=socks5&timeout=10000&country=all&ssl=all&anonymity=all',
    headers={'User-Agent':'Mozilla/5.0'}
)
proxies = urllib.request.urlopen(req, timeout=10).read().decode().strip().split('\n')
```

### Verification
```python
import json, urllib.request
real_ip = json.loads(urllib.request.urlopen('https://api.ipify.org?format=json', timeout=10).read())['ip']
# Navigate browser to https://api.ipify.org?format=json and compare
```

### Chromium Subprocess (Proton Mail)
```python
context = p.chromium.launch_persistent_context(
    PROFILE_DIR,
    executable_path=CHROMIUM,
    headless=False,
    no_viewport=True,
    proxy={"server": "socks5://IP:PORT"},
)
```

## Tor Proxy

### Starting Tor
```bash
mkdir -p /tmp/tor-data
tor --SocksPort 9050 --ControlPort 9051 --DataDirectory /tmp/tor-data --Log "info stdout"
```

### Bootstrap Time
- First run: 2-3 minutes to build circuits
- Check readiness: `curl --socks5 127.0.0.1:9050 https://check.torproject.org/`
- Port 443 OR connections usually work; ports 9001/9030 may be blocked in sandboxes

### Camoufox + Tor
```python
with Camoufox(headless=False, geoip=True, proxy={'server': 'socks5://127.0.0.1:9050'}) as browser:
    ...
```

**Limitation:** `geoip=True` spoofs timezone/locale/WebRTC to match the Tor exit IP's region, but it **cannot bypass Cloudflare's IP-level blocking** of Tor exit nodes. For Cloudflare-protected sites, Tor exits get JS challenges that require FlareSolverr to solve. Use Camoufox + `geoip=True` with **residential proxies** (not Tor) for CF-protected sites. See torbox-api skill's `references/tor-detection-bypass.md` for the full comparison.

## Browser VPN Extensions (NOT Recommended for Automation)

Extensions like SetupVPN, Windscribe, Browsec **require user interaction** — they show a popup that needs a "Connect" click. They do NOT auto-route traffic on Camoufox startup.

**Only use extensions for non-VPN purposes** (ad blockers, cookie consent bypass, etc.).

### Loading Extensions
1. Download `.xpi` from addons.mozilla.org
2. Extract: `zipfile.ZipFile('ext.xpi').extractall('ext-dir')`
3. Pass **extracted directory** (not .xpi): `Camoufox(addons=['/path/to/ext-dir'])`

## Error Handling with Proxies

### TargetClosedError / Timeout
When using proxies, pages may hang or close unexpectedly. Wrap Camoufox calls:
```python
try:
    with Camoufox(headless=False, persistent_context=True, user_data_dir=tmpdir, geoip=True, proxy={'server': 'socks5://IP:PORT'}) as browser:
        register(browser, email, password)
except Exception as e:
    print(f"Step failed: {e}")
    # Retry with fresh email/password
    continue
```

### Cloudflare Challenges Through Proxy
Cloudflare may show challenges more often through proxies. Handle post-submit:
```python
page.locator("button[type='submit']").click(force=True)
page.wait_for_timeout(8000)

# Re-check for Cloudflare after submit
for _ in range(3):
    for frame in page.frames:
        if "challenges.cloudflare.com" in frame.url or "cloudflare" in frame.name.lower():
            try:
                frame.locator("#challenge-stage, .ctp-checkbox, body").first.click()
                page.wait_for_timeout(5000)
            except:
                pass
            break
    page.wait_for_timeout(3000)
```

## Binary Path on Replit/Nix
Camoufox binary may be at `/home/runner/workspace/.cache/camoufox/camoufox` (workspace-local) instead of `~/.cache/camoufox/`. Verify with `python3 -m camoufox path`.
