---
name: download-redirect-resolve
description: "Resolve redirect-based download URLs to final binary links and download/extract/run. Covers Mozilla product downloads, CDN redirect patterns, and any service that uses a redirect gateway for binary distribution."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux, macos]
metadata:
  hermes:
    tags: [download, curl, redirect, binary, install, mozilla]
    related_skills: [github-release-downloads, replit-nixos]
---

# Download Redirect Resolve

Resolve redirect-based download URLs (e.g., Mozilla, SourceForge, CDN gateways) into final binary download links, then download, extract, and run.

## Trigger

- User provides a download URL that redirects (e.g., `download.mozilla.org`, `sourceforge.net/download`, `downloads.apache.org`)
- User asks for "the latest" version of a product distributed via redirect
- `curl -sI` shows a `location:` header pointing to a versioned binary

## Core Technique: Resolve Redirect URL

Many download gateways don't serve the binary directly — they redirect to a CDN. Extract the real URL:

```bash
# Get the final download URL
URL=$(curl -sI -L "https://download-gateway.example.com/product?os=linux64" \
  | grep -i '^location:' \
  | sed 's/location: //i' \
  | tr -d '\r')
```

- `-s` silent, `-I` HEAD request only, `-L` follow redirects
- `grep -i '^location:'` extract the redirect target
- `sed 's/location: //i'` strip the header name (case-insensitive)
- `tr -d '\r'` clean Windows line endings

## Mozilla Product Pattern

Mozilla's download gateway uses query parameters:

| Product | URL Pattern |
|---------|-------------|
| Firefox Nightly | `https://download.mozilla.org/?product=firefox-nightly-latest-ssl&os=linux64&lang=en-US` |
| Firefox Stable | `https://download.mozilla.org/?product=firefox-latest-ssl&os=linux64&lang=en-US` |
| Firefox ESR | `https://download.mozilla.org/?product=firefire-esr-latest-ssl&os=linux64&lang=en-US` |
| Thunderbird | `https://download.mozilla.org/?product=thunderbird-latest-ssl&os=linux64&lang=en-US` |

Resolved URL format: `https://download-installer.cdn.mozilla.net/pub/firefox/releases/{version}/linux-x86_64/en-US/firefox-{version}.tar.xz`

## Full Pipeline (Download + Extract + Run)

```bash
# One-liner: resolve → download → extract → run
URL=$(curl -sI -L 'https://download.mozilla.org/?product=firefox-latest-ssl&os=linux64&lang=en-US' | grep -i '^location:' | sed 's/location: //i' | tr -d '\r') && curl -L -o /tmp/app.tar.xz "$URL" && tar -xf /tmp/app.tar.xz -C /tmp && /tmp/app-name/binary &

# Multi-line for readability
URL=$(curl -sI -L 'https://download.mozilla.org/?product=firefox-latest-ssl&os=linux64&lang=en-US' \
  | grep -i '^location:' | sed 's/location: //i' | tr -d '\r')
curl -L -o /tmp/app.tar.xz "$URL"
tar -xf /tmp/app.tar.xz -C /tmp
/tmp/firefox/firefox &
```

**Note:** The `&` at the end works in regular shells but NOT in Hermes `terminal` foreground mode. In Hermes, use `terminal(background=true)` for the launch step instead.

## Common Pitfalls

- **Forgetting `-L` flag** — without it, `curl -sI` shows the *first* redirect but doesn't follow the chain. Some services have multiple redirects (gateway → CDN → final).
- **Not stripping `\r`** — HTTP headers use CRLF; the trailing `\r` will break the URL in variable assignment.
- **Hardcoding URLs** — always resolve dynamically. The version in the URL changes with each release.
- **Using `curl -o` before resolving** — you'll save the redirect HTML/empty file, not the binary. Resolve first, then download.

## User Preferences

- **Always download latest** — never hardcode a version. Resolve the redirect URL each time to get whatever is currently the latest release.
- **Terse responses** — when user says "generate code" or "give me the command", provide just the code/command. No preamble, no explanation unless asked.
