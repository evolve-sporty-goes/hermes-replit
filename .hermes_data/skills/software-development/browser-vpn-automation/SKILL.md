---
name: browser-vpn-automation
category: software-development
description: |
  Automate browser VPN/proxy workflows: Firefox built-in VPN (MASQUE), Mozilla VPN CLI, Mullvad WireGuard.
  Covers headless/headed automation, profile management, system-wide tunnels, and CI/CD integration.
triggers:
  - "Firefox VPN automation"
  - "Mozilla VPN headless"
  - "Mullvad WireGuard container"
  - "Playwright proxy VPN"
  - "browser IP protection automation"
  - "Firefox built-in VPN profile"
tags:
  - firefox
  - vpn
  - mullvad
  - wireguard
  - playwright
  - selenium
  - automation
  - masque
  - ip-protection
---

# Browser VPN Automation Skill

Comprehensive guide for integrating VPN/proxy into browser automation (Playwright, Selenium, Puppeteer) and containerized workloads.

## Quick Decision Matrix

| Need | Use This |
|------|----------|
| Free, browser-only, <50GB/mo, headed OK | **Firefox built-in VPN** (profile-based) |
| Headless CI/CD, system-wide, unlimited | **Mullvad WireGuard** (€5/mo, no account) |
| Mozilla account OK, export WireGuard config | **Mozilla VPN CLI** → `wgconf` |
| Specific country exit nodes (40+) | **Mullvad WireGuard** |
| **Replit/container without `/dev/net/tun`** | **wireproxy + ProtonVPN Free / Cloudflare WARP** (userspace, SOCKS5) |
| Free, system-wide, headless, unlimited BW | **ProtonVPN Free** (3 countries, WireGuard configs) |
| Free, unlimited, no account, datacenter IPs | **Cloudflare WARP** (wgcf + wireproxy) |

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                    BROWSER AUTOMATION LAYER                     │
│  Playwright / Selenium / Puppeteer / Raw CDP                    │
└─────────────────────────────────────────────────────────────────┘
                              │
              ┌───────────────┼───────────────┐
              ▼               ▼               ▼
┌─────────────────────┐ ┌───────────────┐ ┌────────────────┐
│ Firefox Built-in VPN│ │ Mozilla VPN   │ │ Mullvad        │
│ (MASQUE/HTTP CONNECT)│ │ CLI → WireGuard│ │ WireGuard      │
│ Browser-only        │ │ System-wide   │ │ System-wide    │
│ 50GB/mo free        │ │ 50GB/mo free  │ │ Unlimited €5   │
│ Headed auth required│ │ Headless OK*  │ │ Headless native│
└─────────────────────┘ └───────────────┘ └────────────────┘
              │               │               │
              └───────────────┼───────────────┘
                              ▼
                    ┌─────────────────────┐
                    │   MULLVAD INFRA     │
                    │   (WireGuard mesh)  │
                    └─────────────────────┘
```

---

## Firefox Built-in VPN (Free, Browser-Only)

### Enable via about:config
```bash
browser.ipProtection.enabled = true
browser.vpn.enabled = true
```

### Automation Pattern
1. **Create persistent Firefox profile** (headed)
2. **Authenticate Mozilla account** in browser UI
3. **Enable VPN** via toolbar
4. **Use profile in automation** (headed recommended)

### Playwright Example
```python
context = await playwright.firefox.launch_persistent_context(
    user_data_dir="/path/to/vpn-profile",
    headless=False,  # Required for VPN auth
    firefox_user_prefs={
        "browser.ipProtection.enabled": True,
        "browser.vpn.enabled": True,
    }
)
```

### References
- `references/firefox-vpn-automation.md` — Full prefs, workflows, limitations
- `references/firefox-vpn-preferences.md` — about:config keys, MASQUE architecture
- `references/mozilla-vpn-cli.md` — CLI for WireGuard export

---

## Mozilla VPN CLI (WireGuard Export)

### Install
```bash
# Linux (AppImage, Flatpak, or build from source)
# github.com/mozilla-mobile/mozilla-vpn-client
```

### One-Time Setup (Headed)
```bash
mozillavpn login          # Opens browser for Mozilla OAuth
mozillavpn select us4-wireguard
mozillavpn activate
mozillavpn wgconf > mullvad.conf  # Export WireGuard config
```

### Use Exported Config Anywhere
```bash
# On any machine (no Mozilla VPN client needed)
wg-quick up mullvad.conf
# All traffic (Playwright, curl, requests) routes via Mullvad
```

### References
- `references/mozilla-vpn-cli.md` — Full CLI reference, automation notes

---

## Mullvad WireGuard (Recommended for Automation)

### Why Mullvad?
- **Same exit nodes** as Firefox VPN / Mozilla VPN
- **Anonymous account** (number only, no email)
- **Native WireGuard** — works in containers, headless, system-wide
- **Unlimited bandwidth** — €5/month
- **40+ countries** — vs 4 for Firefox VPN

### Quick Start
```bash
# 1. Get account number from mullvad.net (€5, crypto/card/cash)
# 2. Download config
wget -O mullvad.conf "https://api.mullvad.net/wg/config/<account-number>"

# 3. Bring up tunnel
apt install wireguard && wg-quick up mullvad.conf

# 4. Verify
curl https://api.ipify.org  # Shows Mullvad exit IP
```

### Container/Replit Notes
- Requires `/dev/net/tun` (kernel WireGuard)
- **Replit**: Often missing → use `wireguard-go` userspace or SOCKS5 proxy
- See `references/mullvad-wireguard.md` for workarounds

### Playwright/Selenium: Zero Config
```python
# Just launch — all traffic goes through WireGuard automatically
browser = await playwright.chromium.launch(headless=True)
# No proxy settings needed
```

### References
- `references/mullvad-wireguard.md` — Full guide, multi-region, Replit workarounds

---

## Common Pitfalls

| Pitfall | Symptom | Fix |
|---------|---------|-----|
| Headless Firefox VPN | VPN disconnects / no IP change | Use headed persistent profile OR Mullvad WireGuard |
| 50GB cap hit | VPN stops working mid-month | Switch to Mullvad (unlimited) |
| Replit no `/dev/net/tun` | `wg-quick` fails | **Use `wireproxy` userspace (SOCKS5) + ProtonVPN Free / Cloudflare WARP** |
| Profile VPN state lost | New automation session = no VPN | Use `launch_persistent_context` with same `user_data_dir` |
| Region mismatch | Wrong exit country | Mullvad: download region-specific config |

---

## Userspace WireGuard for Replit / Containers Without TUN

When `/dev/net/tun` is unavailable (Replit, some CI containers, unprivileged LXC), use **wireproxy** — a userspace WireGuard implementation that exposes a **SOCKS5/HTTP proxy** instead of a network interface.

### Why wireproxy?
- **No kernel module** — pure userspace (Go + gVisor netstack)
- **No CAP_NET_ADMIN** — runs as regular user
- **SOCKS5/HTTP proxy output** — works with Playwright, Selenium, requests, curl
- **Compatible with any WireGuard config** — Mullvad, ProtonVPN, Cloudflare WARP, custom

### Quick Setup (Replit-ready)

```bash
# 1. Get WireGuard config (any provider)
# ProtonVPN Free: dashboard → Downloads → WireGuard → US/NL/JP free server
# Cloudflare WARP: wgcf register && wgcf generate → wgcf-profile.conf
# Mullvad: wget -O mullvad.conf "https://api.mullvad.net/wg/config/<account>"

# 2. Install wireproxy (single binary)
curl -sL "https://github.com/windtf/wireproxy/releases/latest/download/wireproxy_linux_amd64.tar.gz" | tar xz
chmod +x wireproxy

# 3. Convert to wireproxy config (add [Socks5] section)
cat > wireproxy.conf <<'EOF'
[Interface]
PrivateKey = <from-your-wg-conf>
Address = <from-your-wg-conf>
DNS = <from-your-wg-conf>

[Peer]
PublicKey = <from-your-wg-conf>
Endpoint = <from-your-wg-conf>
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25

[Socks5]
BindAddress = 127.0.0.1:40000
EOF

# 4. Run
./wireproxy -c wireproxy.conf

# 5. Use in automation
curl --socks5 127.0.0.1:40000 https://api.ipify.org
```

### Provider-Specific Notes

| Provider | Free Tier | Countries | Bandwidth | Replit Notes |
|----------|-----------|-----------|-----------|--------------|
| **ProtonVPN Free** | ✅ Yes | US, NL, JP (3) | Unlimited | WireGuard configs downloadable, works great with wireproxy |
| **Cloudflare WARP** | ✅ Yes | ~100 (anycast) | Unlimited | `wgcf` generates config, datacenter IPs (may be blocked) |
| **Windscribe Free** | ✅ Yes | 10 | 10-15GB/mo | WireGuard configs in dashboard |
| **Mullvad** | ❌ Paid (€5) | 40+ | Unlimited | Best for production, same infra as Firefox VPN |

### Playwright / Selenium Integration

```python
# Playwright
browser = await playwright.chromium.launch(
    proxy={"server": "socks5://127.0.0.1:40000"}
)

# Selenium (with selenium-wire)
from seleniumwire import webdriver
options = {'proxy': {'http': 'socks5://127.0.0.1:40000', 'https': 'socks5://127.0.0.1:40000'}}
driver = webdriver.Chrome(seleniumwire_options=options)

# Python requests
import requests
proxies = {"http": "socks5://127.0.0.1:40000", "https": "socks5://127.0.0.1:40000"}
requests.get("https://example.com", proxies=proxies)
```

### Persist in Replit
Add to `.replit`:
```toml
run = "bash -c './wireproxy -c wireproxy.conf & sleep 3 && python your_script.py'"
```

### References
- `references/wireproxy-replit.md` — Complete Replit setup, ProtonVPN/Cloudflare configs, troubleshooting
- `references/wireproxy-config-examples.md` — Sample configs for each provider

---

## CI/CD Integration Patterns

### GitHub Actions (Mullvad)
```yaml
- name: Setup Mullvad WireGuard
  run: |
    echo "${{ secrets.MULLVAD_CONFIG }}" > mullvad.conf
    sudo apt install -y wireguard
    sudo wg-quick up mullvad.conf
```

### GitHub Actions (Firefox VPN)
```yaml
- name: Cache Firefox VPN Profile
  uses: actions/cache@v3
  with:
    path: ~/.mozilla/firefox/vpn-profile
    key: firefox-vpn-profile-${{ runner.os }}

- name: Run Tests with Firefox VPN
  run: |
    # Profile must be pre-authenticated (manual step or headed workflow)
    python -m pytest --browser firefox --headed
```

---

## Related Skills
- `playwright-automation` — Browser automation patterns
- `dockerizing-rust-projects` — container networking
- `systematic-debugging` — network/tunnel debugging

---

## Session References
- 2025-07-01: Firefox VPN automation research (Mozilla VPN CLI, Mullvad WireGuard, Firefox built-in VPN prefs)
- Key findings: Firefox VPN = MASQUE proxy (Fastly/Mullvad), browser-only, 50GB cap, headed auth required
- Mullvad WireGuard = best for automation (system-wide, headless, unlimited, same infra)

---

## Support Files

### References
- `references/firefox-vpn-preferences.md` — about:config keys, MASQUE architecture, WebRTC leak protection
- `references/firefox-vpn-automation.md` — Playwright/Selenium workflows, profile setup, limitations
- `references/mozilla-vpn-cli.md` — CLI commands, WireGuard export, automation workflow
- `references/mullvad-wireguard.md` — Config download, container setup, Replit workarounds, multi-region