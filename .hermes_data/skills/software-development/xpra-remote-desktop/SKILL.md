---
name: xpra-remote-desktop
description: |
  Set up and configure xpra for remote desktop access via HTML5 client.
  Covers installation on Replit/NixOS, HTML5 interface with touch/keyboard support,
  custom client patches for modifier keys, and daemon management.
version: 1.0.0
platforms: [linux, replit]
metadata:
  hermes:
    tags: [xpra, remote-desktop, html5, touch, keyboard, replit]
    category: software-development
    related_skills: [computer-use, browser-vpn-automation]
---

# Xpra Remote Desktop (HTML5)

Xpra (X Persistent Remote Applications) provides seamless remote X11 display
with an HTML5 client. This skill covers the full setup for running xpra on
Replit/NixOS with a patched HTML5 client that supports touch input and
extended on-screen keyboard keys.

## Quick Start

```bash
# Install xpra via nix
nix-env -iA nixpkgs.xpra

# Start server with HTML5 on port 14500 + unlimited viewport
export PATH="/nix/store/jbi45gv4q60f4ynsqwjgda0c8m7vyimd-xpra-6.3/bin:$PATH"
xpra start :100 \
  --bind-tcp=0.0.0.0:14500 \
  --html=/home/runner/workspace/xpra-www \
  --daemon=yes \
  --exit-with-children=no \
  --start-child=xterm \
  --min-size=1x1 \
  --max-size=16384x16384 \
  --desktop-scaling=no
```

## Installation on Replit/NixOS

Replit doesn't allow `apt`, use nix instead:

```bash
which nix && nix-env -iA nixpkgs.xpra
# Find the installed binary
find /nix/store -maxdepth 3 -name "xpra" -type f 2>/dev/null | head -1
export PATH="/nix/store/<hash>-xpra-<version>/bin:$PATH"
xpra --version  # verify
```

## Server Configuration

Key options for HTML5 client:
| Option | Purpose |
|---|---|
| `--bind-tcp=0.0.0.0:14500` | Listen on all interfaces |
| `--html=/path/to/www` | Serve custom HTML5 client |
| `--daemon=yes` | Run in background |
| `--exit-with-children=no` | Don't exit when child exits |
| `--start-child=xterm` | Launch app on start |
| `--input-devices=xtest` | Use XTest for input (uinput needs /dev/uinput) |

## HTML5 Client Customization

The default HTML5 client is at `/nix/store/<hash>-xpra-<version>/share/xpra/www/`.
Copy to a writable location for patching:

```bash
mkdir -p /home/runner/workspace/xpra-www
cp -r /nix/store/<hash>-xpra-<version>/share/xpra/www/* /home/runner/workspace/xpra-www/
chmod -R u+w /home/runner/workspace/xpra-www/
```

### Patch for Touch Keyboard (Android)

The HTML5 client uses a hidden `#pasteboard` textarea. To trigger the Android
virtual keyboard on canvas tap, add a touch handler in `index.html`:

```javascript
function init_touch_keyboard(client) {
  var screen = $("#screen");
  var pasteboard = $("#pasteboard");

  screen.on("click touchstart", function(e) {
    if ($(e.target).closest("#float_menu, .menu-content, #about, #sessioninfo, #window_preview").length) {
      return;
    }
    pasteboard.focus();
    pasteboard.prop("readonly", false);
    setTimeout(function() { pasteboard.prop("readonly", true); }, 100);
  });
}
## HTML5 Client Customization

The default HTML5 client is at `/nix/store/<hash>-xpra-<version>/share/xpra/www/`. Copy to a writable location for patching:

```bash
mkdir -p /home/runner/workspace/xpra-www
cp -r /nix/store/<hash>-xpra-<version>/share/xpra/www/* /home/runner/workspace/xpra-www/
chmod -R u+w /home/runner/workspace/xpra-www/
```

### Complete Virtual Keyboard Replacement

See the **xpra-virtual-keyboard** skill for a complete replacement of the default simple-keyboard implementation. This provides:

- **Full modifier keys**: **Control**, **Alt**, **Meta** (⌘/Windows key)
- **Sticky/locking modifiers** - tap once to lock, tap again to release
- Visual feedback: green highlight when active, blue when locked
- **Page Up**, **Page Down** keys
- **Context Menu** (☰) key that triggers right-click on focused element
- Proper modifier state tracking included in all key events sent to xpra server (Ctrl+C works correctly)

The replacement is done by:
1. Loading `simple-keyboard` from CDN (`unpkg.com/simple-keyboard@latest`)
2. Creating a custom layout with all modifier keys
3. Tracking modifier state globally, send in every key-action packet
4. Visual feedback via CSS classes (`.active-modifier`, `.modifier-locked`)

See `references/virtual-keyboard-complete.js` in the xpra-virtual-keyboard skill for the complete implementation.

### Unlimited Viewport / Screen

To enable unlimited vertical and horizontal viewport dimensions:

**Server-side (xpra start options):**
```bash
xpra start :100 \
  --min-size=1x1 \
  --max-size=16384x16384 \
  --desktop-scaling=no \
  ...
```

**Client-side (HTML5 viewport):**
Update `index.html` and `connect.html` viewport meta:
```html
<meta name="viewport" content="width=device-width, initial-scale=1, minimum-scale=0.1, maximum-scale=10, user-scalable=yes" />
```

**Client-side (CSS):**
Update `css/client.css`:
```css
html, body {
  overflow: auto;  /* was: overflow: hidden; */
}
```

This allows the virtual desktop to be scrolled infinitely in both directions.

## Server Management

```bash
# Stop server
xpra stop :100

# Check status
xpra info :100

# List windows
xpra control :100 list-windows

# Start child app
xpra control :100 start xterm

# Screenshot (if supported)
xpra control :100 screenshot /tmp/shot.png
```

## Troubleshooting

| Issue | Fix |
|---|---|
| `xpra: command not found` | Add nix store bin to PATH |
| uinput not available | Use `--input-devices=xtest` (default) |
| DBus errors | Ignore or use `--dbus=off --notifications=off` |
| Permission denied on socket dir | `chmod 700 /tmp/xpra` |
| HTML5 client not loading | Check `--html` path, ensure www dir readable |

## Files

- `references/xpra-install-replit.sh` — Install script for Replit
- `references/touch-keyboard-patch.js` — Touch handler for pasteboard focus
- `references/keyboard-layout-extended.js` — Extended simple-keyboard config
- `references/virtual-keyboard-complete.js` — Complete simple-keyboard CDN replacement with sticky modifiers
- `scripts/restart-xpra.sh` — Restart with custom HTML5 dir