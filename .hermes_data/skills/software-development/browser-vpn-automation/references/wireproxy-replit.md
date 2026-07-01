# wireproxy on Replit — Complete Setup Guide

## Why This Works on Replit

- **No `/dev/net/tun`** required — wireproxy uses gVisor netstack in userspace
- **No root/CAP_NET_ADMIN** — runs as regular user
- **SOCKS5/HTTP proxy output** — works with all automation tools
- **Single binary** — ~4MB, no dependencies

## Quick Start (30 seconds)

```bash
# 1. Get a free WireGuard config
# Option A: ProtonVPN Free (US/NL/JP, unlimited BW)
#   → protonvpn.com → free account → Downloads → WireGuard → pick US-FREE#XXX
# Option B: Cloudflare WARP (unlimited, datacenter IPs)
#   → wgcf register && wgcf generate

# 2. Install wireproxy
curl -sL "https://github.com/windtf/wireproxy/releases/latest/download/wireproxy_linux_amd64.tar.gz" | tar xz
chmod +x wireproxy

# 3. Create wireproxy.conf (add [Socks5] section to your .conf)
cat > wireproxy.conf <<'EOF'
[Interface]
PrivateKey = gOCDqyj4jMGJPnykTSjLoDAXjd6bD0XBPc+VwRwIE0w=
Address = 10.2.0.2/32
DNS = 10.2.0.1

[Peer]
PublicKey = VZghTYxgyeiYtJ8HcBRaOFRnRjqSoNYmHVSoOQLz3gA=
Endpoint = 149.88.18.238:51820
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25

[Socks5]
BindAddress = 127.0.0.1:40000
EOF

# 4. Run
./wireproxy -c wireproxy.conf &

# 5. Test
curl --socks5 127.0.0.1:40000 https://api.ipify.org
# → Shows ProtonVPN exit IP (e.g., 149.88.18.241)
```

## ProtonVPN Free Config Extraction

From your downloaded `wireguard-US-FREE-102.conf`:

```
[Interface]
PrivateKey = gOCDqyj4jMGJPnykTSjLoDAXjd6bD0XBPc+VwRwIE0w=
Address = 10.2.0.2/32, 2a07:b944::2:2/128
DNS = 10.2.0.1, 2a07:b944::2:1

[Peer]
PublicKey = VZghTYxgyeiYtJ8HcBRaOFRnRjqSoNYmHVSoOQLz3gA=
AllowedIPs = 0.0.0.0/0, ::/0
Endpoint = 149.88.18.238:51820
PersistentKeepalive = 25
```

**For wireproxy, use only IPv4:**
- `Address = 10.2.0.2/32` (drop IPv6)
- `DNS = 10.2.0.1` (drop IPv6)
- `AllowedIPs = 0.0.0.0/0` (drop ::/0 if not using IPv6)

## Available Free Servers (ProtonVPN Free Tier)

| Server | Country | Endpoint |
|--------|---------|----------|
| US-FREE#102 | US | 149.88.18.238:51820 |
| NL-FREE#XXX | Netherlands | (check dashboard) |
| JP-FREE#XXX | Japan | (check dashboard) |

All configs downloadable from dashboard after free signup.

## Cloudflare WARP Alternative

```bash
# One-time setup
curl -sL "https://github.com/ViRb3/wgcf/releases/latest/download/wgcf_2.2.31_linux_amd64" -o wgcf
chmod +x wgcf
./wgcf register
./wgcf generate
# → wgcf-profile.conf

# Convert to wireproxy format (same [Socks5] section)
```

**Note**: WARP IPs are Cloudflare datacenter ASN — some sites block them.

## Automation Integration

### Playwright
```python
browser = await playwright.chromium.launch(
    proxy={"server": "socks5://127.0.0.1:40000"}
)
```

### Selenium (selenium-wire)
```python
from seleniumwire import webdriver
options = {'proxy': {'http': 'socks5://127.0.0.1:40000', 'https': 'socks5://127.0.0.1:40000'}}
driver = webdriver.Chrome(seleniumwire_options=options)
```

### Python requests
```python
proxies = {"http": "socks5://127.0.0.1:40000", "https": "socks5://127.0.0.1:40000"}
requests.get("https://torbox.app", proxies=proxies)
```

### curl
```bash
curl --socks5 127.0.0.1:40000 https://torbox.app
```

## Persist Across Replit Restarts

### .replit
```toml
run = "bash -c './wireproxy -c wireproxy.conf & sleep 3 && python your_script.py'"
```

### Or with Nix (replit.nix)
```nix
{ pkgs }: {
  deps = [ pkgs.wireguard-tools pkgs.curl pkgs.gnugrep ];
}
```

## Troubleshooting

| Issue | Fix |
|-------|-----|
| `connection refused` on 40000 | Check wireproxy logs for handshake success; wait 5s after start |
| Handshake fails | Verify Endpoint IP:port reachable; check firewall |
| IPv6 errors | Use IPv4-only config (drop ::/0, IPv6 Address/DNS) |
| Slow speeds | Try different free server (US vs NL vs JP); WARP often faster |
| IP not changing | Ensure all traffic uses `--socks5` / proxy config |

## Logs Indicating Success

```
DEBUG: peer(VZgh…) - Received handshake response
DEBUG: Interface state was Down, requested Up, now Up
```

Then SOCKS5 on 127.0.0.1:40000 is ready.

## References

- wireproxy repo: https://github.com/windtf/wireproxy
- ProtonVPN free: https://protonvpn.com/free-vpn
- wgcf (WARP): https://github.com/ViRb3/wgcf
- gVisor netstack: https://github.com/google/gvisor