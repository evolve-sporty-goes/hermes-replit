# Brave Browser: Download & Run from GitHub Releases

Session-validated procedure for downloading and running Brave Browser (stable and origin builds) from GitHub releases.

## Release Channels

Brave publishes multiple builds per release. The key distinction:

| Build | Asset name pattern | Notes |
|-------|-------------------|-------|
| **Brave Browser** (stable) | `brave-browser-{ver}-linux-amd64.zip` | Signed, auto-update, Rewards, full features |
| **Brave Origin** | `brave-origin-{ver}-linux-amd64.zip` | Unsigned, no auto-update, no Rewards. Open-source build. |
| Symbols | `brave-v{ver}-linux-x64-symbols.zip` | Debug symbols, not needed for normal use |
| SHA256 | `*.sha256` | Checksum for verification |
| GPG signature | `*.sha256.asc` | Signed by `brave-builds` (key `9483C53F505043F7`) |

## Linux Assets (v1.91.180 example)

```
brave-browser-1.91.180-linux-amd64.zip
brave-browser-1.91.180-linux-arm64.zip
brave-origin-1.91.180-linux-amd64.zip
brave-origin-1.91.180-linux-arm64.zip
brave-origin-v1.91.180-linux-arm64-symbols.zip
brave-origin-v1.91.180-linux-x64-symbols.zip
brave-v1.91.180-linux-arm64-symbols.zip
brave-v1.91.180-linux-x64-symbols.zip
```

Each has a `.sha256` and `.sha256.asc` companion file.

## Validated Commands

```bash
# 1. Get latest release tag
curl -s "https://api.github.com/repos/brave/brave-browser/releases/latest" \
  | python3 -c "import sys,json; print(json.load(sys.stdin)['tag_name'])"

# 2. Download origin build (Linux amd64)
mkdir -p ~/workspace/brave-browser && cd ~/workspace/brave-browser
TAG="v1.91.180"
curl -L -o brave-origin-${TAG#v}-linux-amd64.zip \
  "https://github.com/brave/brave-browser/releases/download/${TAG}/brave-origin-${TAG#v}-linux-amd64.zip"

# 3. Extract
unzip -q brave-origin-${TAG#v}-linux-amd64.zip -d brave-origin

# 4. Verify version
cd brave-origin && ./brave --no-sandbox --disable-gpu --version
# Output: Brave Origin 149.1.91.180 unknown

# 5. Launch
./brave --no-sandbox --disable-gpu
```

## Extracted Directory Structure

```
brave-origin/
├── brave                    # Main binary (~272MB)
├── brave-origin             # Launcher script
├── chrome_crashpad_handler
├── chrome-management-service
├── chrome-sandbox
├── *.pak                    # Resource bundles
├── libEGL.so, libGLESv2.so  # GPU libs
├── libvk_swiftshader.so     # Software Vulkan
├── libvulkan.so.1
├── locales/                 # Language packs
├── resources/               # App resources
├── MEIPreload/              # Media Engagement
└── apparmor.d/              # AppArmor profiles
```

## Container/Headless Runtime Notes

- **Required flags:** `--no-sandbox --disable-gpu`
- **DBus errors** (non-fatal): `Failed to connect to the bus`, `Failed to call method: org.freedesktop.DBus.*`
- **GSettings errors** (non-fatal): `g_settings_schema_source_lookup: assertion 'source' failed`
- **UPower errors** (non-fatal): `Failed to call method: org.freedesktop.UPower.devices.DisplayDevice`
- All above are cosmetic — the browser process runs fine despite these warnings
