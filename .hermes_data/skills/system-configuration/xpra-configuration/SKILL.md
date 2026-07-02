---
name: xpra-configuration
description: Configure and patch xpra remote display server on Replit/Nix environments
category: system-configuration
triggers:
  - User asks to setup, configure, or patch xpra
  - Remote display / HTML5 client customization needed
  - xpra build failures in Nix environment
---

# xpra Configuration on Replit/Nix

## Core Principle

**Use nix-installed xpra, do NOT build from source in Replit.**

Building from source fails due to missing C runtime files (`crti.o`), pkg-config dependencies, and system libraries unavailable in Replit's Nix environment.

```bash
# Use nix-installed version (works)
nix-env -iA nixpkgs.xpra
xpra --version  # v6.3

# Do NOT do this (fails)
git clone https://github.com/Xpra-org/xpra
python3 ./setup.py install  # Missing crti.o, xdmcp, sysprof-capture-4, etc.
```

## HTML5 Client Patching

The nix-installed xpra serves HTML5 client from read-only store. Copy to writable location for patches:

```bash
mkdir -p /home/runner/workspace/xpra-www
cp -r /nix/store/*xpra*/share/xpra/www/* /home/runner/workspace/xpra-www/
```

Start xpra with custom HTML5 dir:
```bash
xpra start :100 --bind-tcp=0.0.0.0:14500 --html=/home/runner/workspace/xpra-www --daemon=yes --start-child=xterm
```

## Common Patches

### On-Screen Keyboard with Modifier Keys

Edit `/home/runner/workspace/xpra-www/index.html` in `init_keyboard()`:

```javascript
// Add to display object
display: {
  ".com": "|",
  "{tab}": "tab", "{lock}": "lock", "{shift}": "shift",
  "{bksp}": "bksp", "{space}": "space", "{enter}": "return",
  "{control}": "ctrl", "{alt}": "alt", "{meta}": "meta",
  "{pageup}": "pgup", "{pagedown}": "pgdn", "{contextmenu}": "menu"
},

// Add layout with modifier row
layout: {
  default: [
    "` 1 2 3 4 5 6 7 8 9 0 - = {bksp}",
    "{tab} q w e r t y u i o p [ ] \\\\",
    "{lock} a s d f g h j k l ; ' {enter}",
    "{shift} z x c v b n m , . / {shift}",
    "{control} {alt} {meta} .com @ {space} {meta} {alt} {control} {pageup} {pagedown} {contextmenu}"
  ],
  shift: [ ... ]
},

// Add to forward_key mapping
var key = {
  "{control}": "Control", "{alt}": "Alt", "{meta": "{meta}": "Meta",
  "{pageup}": "PageUp", "{pagedown}": "PageDown",
  "{contextmenu}": "ContextMenu",
  ...
};
```

### Remove Touch Keyboard Trigger

The `init_touch_keyboard()` function focusing pasteboard on canvas tap doesn't work on Android. Remove it:

1. Delete the `init_touch_keyboard` function
2. Remove `init_touch_keyboard(client);` call in `init_page()`

## Restart Script

```bash
#!/usr/bin/env bash
# /home/runner/workspace/scripts/restart-xpra.sh
XPRA_BIN="/nix/store/jbi45gv4q60f4ynsqwjgda0c8m7vyimd-xpra-6.3/bin/xpra"
PATCHED_WWW="/home/runner/workspace/xpra-www"
$XPRA_BIN stop :100 2>/dev/null || true
sleep 1
$XPRA_BIN start :100 --bind-tcp=0.0.0.0:14500 --html=$PATCHED_WWW --daemon=yes --start-child=xterm
```

## Verification

```bash
export PATH="/nix/store/jbi45gv4q60f4ynsqwjgda0c8m7vyimd-xpra-6.3/bin:$PATH"
xpra info :100 | grep -E "html|www|xterm"
# Should show: network.www.dir=/home/runner/workspace/xpra-www
```

## Pitfalls

| Issue | Solution |
|-------|----------|
| Build from source fails | Use nix-installed xpra |
| HTML5 changes don't apply | Must copy www dir to writable location |
| Touch keyboard doesn't work on Android | Remove `init_touch_keyboard`, use on-screen keyboard button |
| Port conflicts | Use `--bind-tcp=0.0.0.0:14500` with Replit port forwarding |
| xterm not starting | Use `--start-child=xterm` not `--start=xterm` |

## References

- `references/xpra-patch-keyboard.md` — full keyboard patch diff
- `references/xpra-build-failures.md` — documented build failure reasons