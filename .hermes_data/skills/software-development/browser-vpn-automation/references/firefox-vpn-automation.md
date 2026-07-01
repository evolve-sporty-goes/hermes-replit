# Firefox Built-in VPN Automation

## Key about:config Preferences

| Preference | Type | Default | Description |
|------------|------|---------|-------------|
| `browser.ipProtection.enabled` | bool | `false` | **Master switch** — enables IP Protection/VPN feature |
| `browser.vpn.enabled` | bool | `false` | Legacy/alias — may control toolbar button visibility |
| `network.proxy.type` | int | `5` (system) | Proxy mode: 0=direct, 1=manual, 2=PAC, 4=auto-detect, 5=system |
| `network.proxy.http` | string | `""` | Manual HTTP proxy host (when type=1) |
| `network.proxy.http_port` | int | `0` | Manual HTTP proxy port |
| `network.proxy.ssl` | string | `""` | Manual HTTPS proxy host |
| `network.proxy.ssl_port` | int | `0` | Manual HTTPS proxy port |
| `network.proxy.socks` | string | `""` | Manual SOCKS proxy host |
| `network.proxy.socks_port` | int | `0` | Manual SOCKS proxy port |
| `network.proxy.socks_version` | int | `5` | SOCKS version (4 or 5) |
| `network.proxy.no_proxies_on` | string | `"localhost, 127.0.0.1"` | Bypass list |

## Enabling Firefox Built-in VPN (Headed Required)

```javascript
// Firefox profile preferences for VPN
const prefs = {
  "browser.ipProtection.enabled": true,
  "browser.vpn.enabled": true,
  // Optional: auto-connect on startup (may not persist)
  "browser.vpn.autoConnect": true,
};
```

**Critical**: Firefox built-in VPN **requires headed mode** for initial authentication (Mozilla account OAuth). Headless mode cannot complete the login flow.

## Playwright Persistent Context (Recommended)

```python
# Python + Playwright
from playwright.async_api import async_playwright

async def main():
    # Create/use persistent profile with VPN enabled
    context = await playwright.firefox.launch_persistent_context(
        user_data_dir="/path/to/firefox-profile-vpn",
        headless=False,  # MUST be headed for VPN auth
        firefox_user_prefs={
            "browser.ipProtection.enabled": True,
            "browser.vpn.enabled": True,
        }
    )
    
    page = context.new_page()
    await page.goto("https://api.ipify.org")
    print(await page.text_content("body"))  # Should show VPN exit IP
    
    # Keep browser open for manual VPN login if needed
    # Once logged in, session persists in profile
    await context.close()
```

## Selenium Firefox Profile

```python
# Python + Selenium
from selenium import webdriver
from selenium.webdriver.firefox.options import Options

options = Options()
options.set_preference("browser.ipProtection.enabled", True)
options.set_preference("browser.vpn.enabled", True)
# Use existing profile that has VPN authenticated
options.profile = "/path/to/firefox-profile-vpn"

driver = webdriver.Firefox(options=options)
driver.get("https://api.ipify.org")
print(driver.find_element("tag name", "body").text)
```

## Profile Setup Workflow (One-time, Headed)

```bash
# 1. Create clean profile
firefox -CreateProfile vpn-profile /path/to/firefox-profile-vpn

# 2. Launch headed with VPN prefs
firefox -P vpn-profile -no-remote \
  -pref "browser.ipProtection.enabled=true" \
  -pref "browser.vpn.enabled=true"

# 3. In browser: Click VPN toolbar button → "Get started" → Sign in with Mozilla account
# 4. Click "Turn on VPN"
# 5. Verify at https://api.ipify.org — shows VPN IP
# 6. Close browser — profile now has authenticated VPN session

# 7. Use profile in automation (headed or headless*)
```

**Note**: Headless *may* work after initial auth if session tokens persist, but Firefox may drop VPN connection in headless. Test your specific version.

## VPN Bypass List (Split Tunneling)

```python
# Manage bypass list via preferences or UI
# UI: Settings → Privacy & Security → VPN → "Manage website settings"

# Programmatic (may require browser restart):
prefs = {
    "browser.vpn.bypassList": "example.com, localhost, 192.168.1.0/24",
}
```

## Limitations for Automation

| Limitation | Impact | Workaround |
|------------|--------|------------|
| 50 GB/month cap | Free tier only | Use Mullvad WireGuard (unlimited) |
| Browser-only traffic | Non-browser tools (curl, requests) bypass VPN | Use system WireGuard instead |
| Requires Mozilla account | OAuth flow needs headed browser | Pre-authenticate profile |
| Headless unreliable | VPN may disconnect in headless | Use headed or Mullvad WireGuard |
| Region selection limited | Few countries (US, DE, FR, UK) | Mullvad has 40+ countries |
| No static IP | Exit IP rotates | Mullvad: same (but more exits) |

## When to Use Firefox VPN vs Mullvad WireGuard

| Use Case | Recommendation |
|----------|----------------|
| Quick browser test, <50GB/mo | Firefox VPN (free) |
| Headless CI/CD, any volume | Mullvad WireGuard |
| System-wide tunnel (all tools) | Mullvad WireGuard |
| Specific country exit node | Mullvad WireGuard |
| No account/payment preferred | Firefox VPN (free, Mozilla account only) |
| Playwright/Selenium only, headed OK | Firefox VPN profile |

## Firefox Version Notes
- VPN feature introduced in **Firefox 149** (March 2024)
- Requires Firefox 149+ 
- `browser.ipProtection.enabled` is the canonical pref
- Gradual rollout — may not appear in all regions immediately
- Check `about:support` → "IP Protection" section for status

## Debugging VPN Connection
```bash
# Check VPN status in browser console (Ctrl+Shift+J):
# Look for: "IP Protection", "VPN", "MASQUE", "CONNECT-UDP"

# Network log (about:networking#logging):
# Filter: "masque", "connect-udp", "quic", "proxy"

# Verify MASQUE proxy:
# about:preferences#privacy-vpn → shows connection stats
```

## Sources
- Winaero: "How to Enable the Built-in Firefox VPN" (browser.ipProtection.enabled)
- Fastly Blog: "We Built the Proxy Behind Firefox's New Built-In VPN" (MASQUE architecture)
- Mozilla Connect: "Introducing Firefox's Built-in VPN: IP Protection"
- Firefox 149 Release Notes