# Replit Headless Setup for camofox-browser

Session-tested setup on Replit (Nix-based, python-3.12, no sudo/apt-get).

## Environment Constraints

- No `sudo` or `apt-get` — use `nix-env -i <pkg> -f channel:stable-25_05`
- Node.js not pre-installed — install via nix-env
- npm registry proxy (`package-firewall.replit.local`) blocks many packages
- No Xvfb / virtual display available — browser cannot launch headless without one
- Camoufox binary bundle lives at `~/.cache/camoufox/browsers/official/<version>/`

## Step-by-Step Working Setup

```bash
# 1. Install Node.js
nix-env -i nodejs_22 -f channel:stable-25_05
export NODE=/nix/store/*nodejs-22*/bin/node
export NPM=/nix/store/*nodejs-22*/bin/npm

# 2. Clone camofox-browser
git clone https://github.com/jo-inc/camofox-browser.git
cd camofox-browser

# 3. Install deps (public registry, skip post-install scripts)
$NPM install --registry=https://registry.npmjs.org --ignore-scripts

# 4. Rebuild better-sqlite3 native binding
$NODE $NPM rebuild better-sqlite3

# 5. Fix camoufox-js version constraint (MAX_VERSION too low for browser 135.x)
# Edit node_modules/camoufox-js/dist/__version__.js:
#   static MAX_VERSION = "999";  // was "1"

# 6. Fix version.json format (camoufox-js expects "release", bundle has "build")
# At ~/.cache/camoufox/version.json, ensure:
#   {"version":"135.0.1","release":"135.0.1-beta.24",...}

# 7. Create fontconfig symlink in bundle
ln -sfn ~/.cache/camoufox/browsers/official/135.0.1-beta.24/fontconfigs \
        ~/.cache/camoufox/browsers/official/135.0.1-beta.24/fontconfig

# 8. Start server
export CAMOUFOX_EXECUTABLE=~/.cache/camoufox/browsers/official/135.0.1-beta.24/camoufox
export CAMOFOX_PORT=9377
export CAMOFOX_CRASH_REPORT_ENABLED=false
$NODE server.js
```

## Errors Encountered & Fixes

| Error | Root Cause | Fix |
|-------|-----------|-----|
| `npx: command not found` | Node not installed | `nix-env -i nodejs_22 -f channel:stable-25_05` |
| `E404 npm-run-path` | Replit proxy blocks package | `--registry=https://registry.npmjs.org` |
| `sh: 1: npx: not found` | Post-install script needs npx | `--ignore-scripts` |
| `External Camoufox bundle must include fontconfig/` | Directory named `fontconfigs/` | `ln -sfn .../fontconfigs .../fontconfig` |
| `Version information not found` | Cache missing version.json | Copy from bundle to `~/.cache/camoufox/` |
| `Cannot read properties of undefined (reading 'split')` | version.json uses `build` not `release` | Rewrite with `"release"` field |
| `Could not locate the bindings file (better-sqlite3)` | `--ignore-scripts` skipped native build | `npm rebuild better-sqlite3` |
| `cannot open display: [object Promise]` | No Xvfb in headless env | Run on machine with display or use Xvfb |
| `xvfb-run: command not found` | Xvfb not installed via nix-env | Not yet resolved on Replit |

## Current Blocker

The server starts and responds to `/health` and `/openapi.json`, but cannot launch the Camoufox browser process because there is no virtual display (Xvfb). The browser launch fails with:

```
Error: cannot open display: [object Promise]
```

Options:
1. Add `pkgs.xvfb` to `.replit` `[nix]` packages and restart
2. Use `nix-shell -p xvfb-run --run "xvfb-run -a node server.js"`
3. Deploy to a host with a display (e.g., VPS with Xvfb)
