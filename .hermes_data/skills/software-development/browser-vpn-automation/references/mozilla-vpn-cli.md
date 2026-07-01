# Mozilla VPN CLI Reference

## Installation
```bash
# Linux (AppImage, deb, rpm, Arch AUR)
# See: https://github.com/mozilla-mobile/mozilla-vpn-client/releases

# Or build from source (Rust):
cargo install --git https://github.com/mozilla-mobile/mozilla-vpn-client mozillavpn
```

## Commands
```bash
mozillavpn -h
# usage: mozillavpn [-h | --help] [-v | --version] <commands> [<args>]

# Commands:
#   activate             Activate the VPN tunnel
#   deactivate           Deactivate the VPN tunnel
#   device               Remove a device by its id
#   login                Starts the authentication flow (opens browser)
#   logout               Logout the current user
#   select               Select a server
#   servers              Show the list of servers
#   status               Show the current VPN status
#   ui                   Start the UI
#   linuxdaemon          Starts the linux daemon
#   wgconf               Generate a wireguard configuration file
```

## Typical Workflow for Automation

### 1. One-time Authentication (requires browser)
```bash
mozillavpn login
# Opens default browser → Firefox Accounts OAuth → returns to CLI
```

### 2. Select Server
```bash
mozillavpn servers          # List all (cached)
mozillavpn servers -v       # Verbose: shows IPs, public keys, gateways
mozillavpn select us4-wireguard
```

### 3. Activate & Verify
```bash
mozillavpn activate
mozillavpn status
# User status: authenticated
# VPN state: on
# Server country: United States
# Server city: New York
```

### 4. Export WireGuard Config
```bash
mozillavpn wgconf > mullvad.conf
# Outputs standard WireGuard [Interface] + [Peer] config
```

### 5. Use in Container/Headless (no browser needed)
```bash
# On target machine:
apt update && apt install -y wireguard
wg-quick up mullvad.conf

# Verify:
wg show
curl https://api.ipify.org  # Shows Mullvad exit IP
```

## WireGuard Config Format
```ini
[Interface]
PrivateKey = <base64-private-key>
Address = 10.x.x.x/32, fc00:bbbb:bbbb:bb01::x:x/128
DNS = 10.64.0.1, fc00:bbbb:bbbb:bb01::1

[Peer]
PublicKey = <base64-public-key>
Endpoint = <server-ip>:3406
AllowedIPs = 0.0.0.0/0, ::/0  # Full tunnel (Mozilla VPN default)
# Or split tunnel (Firefox VPN default):
# AllowedIPs = 10.64.0.1/32, fc00:bbbb:bbbb:bb01::1/128, <Mullvad CIDRs>
```

## Server List Format
```bash
mozillavpn servers -v | head -30
- Country: United States (code: us)
  - City: New York (nyc)
    - Server: us4-wireguard
        ipv4 addr-in: 198.51.100.1
        ipv4 gateway: 10.64.0.1
        ipv6 addr-in: 2001:db8::1
        ipv6 gateway: fc00:bbbb:bbbb:bb01::1
        publicKey: <base64>
```

## Automation Notes
- **First run requires headed browser** for `mozillavpn login` (FxA OAuth)
- After login, config stored in `~/.config/mozilla-vpn/` (Linux)
- `wgconf` output is static — can be copied to any machine
- WireGuard config works **without Mozilla VPN client installed**
- Mullvad infrastructure = same exit IPs as Firefox built-in VPN
- No data cap on exported WireGuard (vs 50GB/mo on Firefox VPN)

## Headless/CI Considerations
```bash
# Option 1: Pre-generate config locally, commit to repo (rotate periodically)
# Option 2: Run mozillavpn login in CI with headed browser (Playwright can automate)
# Option 3: Use Mullvad directly (no Mozilla account needed)

# Mullvad direct:
wget -O mullvad.conf "https://api.mullvad.net/wg/config/<account-number>"
```

## Sources
- GitHub: mozilla-mobile/mozilla-vpn-client/wiki/Command-line-interface
- Mozilla VPN client source: github.com/mozilla-mobile/mozilla-vpn-client