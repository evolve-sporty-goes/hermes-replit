# Firefox Built-in VPN Preferences (about:config)

## Key Preference
| Preference | Type | Default | Description |
|------------|------|---------|-------------|
| `browser.ipProtection.enabled` | bool | `false` | **Master switch** — enables IP Protection/VPN feature |
| `browser.ipProtection.auth.enabled` | bool | `false` | Authenticated VPN (requires Mozilla account) |
| `browser.ipProtection.auth.server` | string | — | MASQUE proxy server endpoint |
| `network.proxy.type` | int | `5` (system) | Proxy mode: 0=direct, 1=manual, 2=PAC, 4=auto-detect, 5=system |
| `network.proxy.http` | string | — | HTTP proxy host (when type=1) |
| `network.proxy.http_port` | int | — | HTTP proxy port |
| `network.proxy.ssl` | string | — | HTTPS proxy host |
| `network.proxy.ssl_port` | int | — | HTTPS proxy port |
| `network.proxy.socks` | string | — | SOCKS proxy host |
| `network.proxy.socks_port` | int | — | SOCKS proxy port |
| `network.proxy.socks_version` | int | `5` | SOCKS version (4 or 5) |

## VPN-Specific Preferences (Firefox 149+)
| Preference | Type | Description |
|------------|------|-------------|
| `browser.ipProtection.enabled` | bool | **Enable IP Protection/VPN feature** |
| `browser.ipProtection.auth.enabled` | bool | Use authenticated VPN (Mozilla account) |
| `browser.ipProtection.auth.server` | string | MASQUE proxy hostname |
| `browser.ipProtection.auth.port` | int | MASQUE proxy port (typically 443) |
| `browser.ipProtection.auth.token` | string | Auth token (set after login) |
| `browser.ipProtection.quic.enabled` | bool | Enable QUIC/HTTP3 MASQUE (experimental) |
| `browser.ipProtection.bypass.list` | string | Comma-separated bypass domains |
| `browser.private.network.enabled` | bool | Private Network Access (PNA) API support |

## Enabling via user.js (for automation)
```javascript
// user.js in Firefox profile directory
user_pref("browser.ipProtection.enabled", true);
user_pref("browser.ipProtection.auth.enabled", true);
user_pref("network.proxy.type", 1);  // Manual proxy (if using explicit proxy)
```

## Architecture Notes
- **Protocol**: MASQUE (Multiplexed Application Substrate over QUIC Encryption)
- **Transport**: HTTP CONNECT over HTTP/2 (initial) → HTTP/3/QUIC (planned)
- **Proxy Operator**: Fastly (no logging, no DPI, neutral)
- **Backend**: Mullvad WireGuard infrastructure
- **Scope**: Browser HTTP/HTTPS traffic only (not system-wide, not WebRTC by default)
- **Auth**: Firefox Accounts (FxA) OAuth flow via browser UI

## WebRTC Leak Protection
Firefox VPN does **not** automatically route WebRTC through MASQUE tunnel.
```javascript
// Disable WebRTC to prevent IP leaks
user_pref("media.peerconnection.enabled", false);
user_pref("media.peerconnection.ice.default_address_only", true);
user_pref("media.peerconnection.ice.no_host", true);
```

## Sources
- Fastly blog: "We Built the Proxy Behind Firefox's New Built-In VPN"
- Winaero: "How to Enable the Built-in Firefox VPN"
- Mozilla Connect discussions on IP Protection rollout