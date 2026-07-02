---
name: xpra-virtual-keyboard
description: |
  Complete virtual keyboard implementation for Xpra HTML5 client using simple-keyboard.
  Provides sticky modifier keys (Control, Alt, Meta), ContextMenu right-click key,
  PageUp/PageDown keys, and proper modifier state tracking for key combinations.
version: 1.0.0
platforms: [linux, replit]
metadata:
  hermes:
    tags: [xpra, virtual-keyboard, simple-keyboard, html5, touch, keyboard]
    category: software-development
    related_skills: [xpra-remote-desktop]
---

# Xpra Virtual Keyboard (Complete Replacement)

Replaces the default simple-keyboard implementation in Xpra's HTML5 client with
a full-featured virtual keyboard that supports sticky/locking modifier keys,
context menu right-click, and proper modifier state tracking.

## Features

- **Full modifier keys**: Control, Alt, Meta (⌘/Windows key)
- **Sticky/locking modifiers** - tap once to lock, tap again to release
- Visual feedback: green highlight when active, blue when locked
- **Page Up**, **Page Down** keys
- **Context Menu** (☰) key that triggers right-click on focused element
- Proper modifier state tracking included in all key events sent to xpra server (Ctrl+C works correctly)

## Installation

1. Copy the HTML5 client to a writable location:
```bash
mkdir -p /home/runner/workspace/xpra-www
cp -r /nix/store/<hash>-xpra-<version>/share/xpra/www/* /home/runner/workspace/xpra-www/
chmod -R u+w /home/runner/workspace/xpra-www/
```

2. Include the virtual keyboard in `index.html` before `</body>`:
```html
<script src="/virtual-keyboard-complete.js"></script>
```

3. Update `init_keyboard()` in `index.html` to use the new implementation:
```javascript
function init_keyboard(client) {
    if (window.initVirtualKeyboard) {
        window.initVirtualKeyboard(client);
    } else {
        var script = document.createElement('script');
        script.src = '/virtual-keyboard-complete.js';
        script.onload = function() {
            if (window.initVirtualKeyboard) {
                window.initVirtualKeyboard(client);
            }
        };
        document.head.appendChild(script);
    }
    // ... rest of existing keyboard show/hide logic
}
```

## Layout

The keyboard uses a custom layout with modifier keys in the bottom row:

```
Row 1: ` 1 2 3 4 5 6 7 8 9 0 - = ⌫
Row 2: ⇥ q w e r t y u i o p [ ] \
Row 3: ⇪ a s d f g h j k l ; ' ↵
Row 4: ⇧ z x c v b n m , . / ⇧
Row 5: Ctrl Alt ⌘ .com @ Space ⌘ Alt Ctrl PgUp PgDn ☰
```

## Modifier State Tracking

Modifier state is tracked globally and included in every key-action packet:

```javascript
const modifierState = {
    shift: false,
    control: false,
    alt: false,
    meta: false
};
```

When a modifier key is tapped, it locks (green highlight). When a non-modifier key is pressed, the modifiers are included in the packet and auto-released.

## Context Menu Key

The `{contextmenu}` key (displayed as ☰) sends a proper right-click event to both the focused element and the xpra server canvas.

## Files

- `scripts/virtual-keyboard-complete.js` — Complete implementation (loads simple-keyboard from CDN)