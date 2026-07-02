# xpra HTML5 Client Keyboard Patch

## Files Modified
- `/home/runner/workspace/xpra-www/index.html`

## Changes

### 1. Add Modifier Keys to Display Object (line ~1103)

```javascript
display: {
  ".com": "|",
  "{tab}": "tab",
  "{lock}": "lock",
  "{shift}": "shift",
  "{bksp}": "bksp",
  "{space}": "space",
  "{enter}": "return",
  "{control}": "ctrl",
  "{alt}": "alt",
  "{meta}": "meta",
  "{pageup}": "pgup",
  "{pagedown}": "pgdn",
  "{contextmenu}": "menu",
},
```

### 2. Add Custom Layouts (after display object)

```javascript
layout: {
  default: [
    "` 1 2 3 4 5 6 7 8 9 0 - = {bksp}",
    "{tab} q w e r t y u i o p [ ] \\\\",
    "{lock} a s d f g h j k l ; ' {enter}",
    "{shift} z x c v b n m , . / {shift}",
    "{control} {alt} {meta} .com @ {space} {meta} {alt} {control} {pageup} {pagedown} {contextmenu}"
  ],
  shift: [
    "~ ! @ # $ % ^ & * ( ) _ + {bksp}",
    "{tab} Q W E R T Y U I O P { } |",
    '{lock} A S D F G H J K L : " {enter}',
    "{shift} Z X C V B N M < > ? {shift}",
    "{control} {alt} {meta} .com @ {space} {meta} {alt} {control} {pageup} {pagedown} {contextmenu}"
  ]
},
```

### 3. Update forward_key Mapping (line ~1141)

```javascript
function forward_key(pressed, button) {
var key = {
  "{bksp}": "Backspace",
  "{enter}": "Return",
  "{space}": "Space",
  "{tab}": "Tab",
  "{lock}": "CapsLock",
  "{shift}": "Shift",
  "{control}": "Control",
  "{alt}": "Alt",
  "{meta}": "Meta",
  "{pageup}": "PageUp",
  "{pagedown}": "PageDown",
  "{contextmenu}": "ContextMenu",
  ".com": "|",
} [button] || button;
```

## Keyboard Layout

```
┌─────────────────────────────────────────────────────────────┐
│ `  1  2  3  4  5  6  7  8  9  0  -  =  ← Backspace          │
├─────────────────────────────────────────────────────────────┤
│ Tab    Q  W  E  R  T  Y  U  I  O  P  [  ]  \                │
├─────────────────────────────────────────────────────────────┤
│ Caps   A  S  D  F  G  H  J  K  L  ;  '     Enter            │
├─────────────────────────────────────────────────────────────┤
│ Shift        Z  X  C  V  B  N  M  ,  .  /       Shift       │
├─────────────────────────────────────────────────────────────┤
│ Ctrl  Alt  Meta  |  Space  |  Meta  Alt  Ctrl  PgUp PgDn ☰  │
└─────────────────────────────────────────────────────────────┘
```

## Removed: Touch Keyboard Trigger

Deleted `init_touch_keyboard()` function and its call in `init_page()` because it didn't trigger Android keyboard on tap.