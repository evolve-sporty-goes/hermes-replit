---
name: github-release-downloads
description: "Download and run binary releases from GitHub. Asset discovery via API, download, extraction, and launch."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [GitHub, Releases, Downloads, Binaries, Chromium]
    related_skills: [github-repo-management]
---

# GitHub Release Downloads

Download, extract, and run binary releases from GitHub repos. Covers the common pattern where you need to find the right asset, download it, and launch it — especially for Chromium-based browsers and other standalone binaries.

## Trigger

- User asks to download a GitHub release, get a release binary, or install a tool from GitHub releases
- User provides a GitHub releases URL or asks for "the latest release" of a repo
- User asks to download and run a browser (Brave, Chrome, Chromium, Electron apps) from GitHub

## Step 1: Find the Latest Release Tag

```bash
# Get latest release tag (no auth needed for public repos)
curl -s "https://api.github.com/repos/{owner}/{repo}/releases/latest" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['tag_name'])"
```

If the user provides a specific tag, use it directly.

## Step 2: Discover Release Asset URLs

**Critical: GitHub release web pages load assets lazily.** `web_extract` and browser snapshots often cannot see asset download links. The GitHub API is the reliable path.

```bash
# List ALL assets for a release tag with download URLs
curl -s "https://api.github.com/repos/{owner}/{repo}/releases/tags/{tag}" \
  | python3 -c "
import sys, json
data = json.load(sys.stdin)
for a in data.get('assets', []):
    print(f\"{a['name']}  ->  {a['browser_download_url']}\")
"
```

### Filter by platform/keyword

```bash
# Find Linux amd64 assets
curl -s "https://api.github.com/repos/{owner}/{repo}/releases/tags/{tag}" \
  | python3 -c "
import sys, json
for a in json.load(sys.stdin).get('assets', []):
    if 'linux' in a['name'].lower() and 'amd64' in a['name'].lower():
        print(a['browser_download_url'])
"
```

### Common asset naming patterns

| Publisher | Pattern | Example |
|-----------|---------|---------|
| Brave | `brave-browser-{ver}-linux-amd64.zip`, `brave-origin-{ver}-linux-amd64.zip` | `brave-origin-1.91.180-linux-amd64.zip` |
| Chromium | `chrome-linux.zip`, `chromium-{ver}-linux-64bit.zip` | Varies by publisher |
| Electron apps | `{app}-{ver}-linux-x64.zip`, `{app}-{ver}.AppImage` | Varies by app |
| Generic | `*-linux-amd64.tar.gz`, `*-linux-x64.zip` | Check assets list |

**Note:** "Brave Origin" is the open-source/unsigned build (no auto-update, no Brave Rewards). "Brave Browser" is the signed stable release with full features.

## Step 3: Download

```bash
mkdir -p ~/workspace/{app-name}
cd ~/workspace/{app-name}

# Download the asset (follow redirects with -L)
curl -L -o {filename} "{browser_download_url}"
```

For large files, show progress: `curl -L -# -o {filename} "{url}"`

### Verify (optional)

If `.sha256` files are available:

```bash
curl -L -o {filename}.sha256 "{sha256_url}"
sha256sum -c {filename}.sha256
```

## Step 4: Extract

```bash
# ZIP
unzip -q {filename}.zip -d {extract-dir}

# tar.gz
tar xzf {filename}.tar.gz -C {extract-dir}

# AppImage (no extraction needed)
chmod +x {filename}.AppImage
```

## Step 5: Launch

### Chromium-based browsers in headless/container Linux

Chromium-based browsers (Brave, Chrome, Chromium, Electron apps) need specific flags when running in containers, CI, or headless environments:

```bash
cd {extract-dir}
./brave --no-sandbox --disable-gpu
```

| Flag | Why |
|------|-----|
| `--no-sandbox` | Required when running as root or in containers without user namespaces |
| `--disable-gpu` | Avoids GPU errors in headless/VM environments with no GPU |

### Expected warnings (non-fatal)

In headless/container environments, these warnings are **expected and harmless**:

- `Failed to connect to the bus` (D-Bus) — no session bus available
- `g_settings_schema_source_lookup: assertion 'source' failed` (GSettings) — no schema files installed
- `Failed to call method: org.freedesktop.DBus.*` — no system D-Bus
- `Failed to call method: org.freedesktop.UPower.*` — no power management daemon

These do not prevent the browser from running. Only take action if the browser actually crashes or hangs.

### Launch as background process

```bash
# In Hermes: use terminal(background=true)
# Find the binary, cd to its directory, then:
./brave --no-sandbox --disable-gpu
```

### Verify it's running

```bash
./brave --no-sandbox --disable-gpu --version
# e.g. "Brave Origin 149.1.91.180 unknown"
```

## Pitfalls

- **Web tools can't see GitHub release asset links.** Assets load lazily on the GitHub releases page. Use the API endpoint `/repos/{owner}/{repo}/releases/tags/{tag}` to get `browser_download_url` values instead of scraping the page.
- **Missing `--no-sandbox`** will cause chromium-based browsers to crash immediately in containers. The error message usually says something about namespace sandboxing.
- **Missing `--disable-gpu`** causes hangs or GPU process crashes in VMs without GPU drivers.
- **Not using `curl -L`** fails on GitHub release downloads because they redirect through `objects.githubusercontent.com`.
- **Large downloads** — some browser zips are 150MB+. Use `curl -L -#` for progress or download in background.
