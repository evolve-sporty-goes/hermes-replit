#!/usr/bin/env python3
# Add Control/Alt/Meta keys + Page Up/Down + Right-click/Menu to the on-screen keyboard

INDEX_HTML = "/home/runner/workspace/xpra-www/index.html"

import re

with open(INDEX_HTML, 'r') as f:
    content = f.read()

# Find the init_keyboard function and replace the layout definition
old_layout = '''        display: {
            ".com": "|",
            "{tab}": "tab",
            "{lock}": "lock",
            "{shift}": "shift",
            "{bksp}": "bksp",
            "{space}": "space",
            "{enter}": "return",
          },'''

new_layout = '''        display: {
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
          },'''

content = content.replace(old_layout, new_layout)

# Also update forward_key to handle the new keys
old_forward_key = '''        function forward_key(pressed, button) {
var key = {
            "{bksp}": "Backspace",
            "{enter}": "Return",
            "{space}": "Space",
            "{tab}": "Tab",
            "{lock}": "CapsLock",
            "{shift}": "Shift",
            ".com": "|",
          } [button] || button;'''

new_forward_key = '''        function forward_key(pressed, button) {
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
          } [button] || button;'''

content = content.replace(old_forward_key, new_forward_key)

with open(INDEX_HTML, 'w') as f:
    f.write(content)

print("Updated keyboard layout with Control/Alt/Meta + PageUp/Down + ContextMenu keys")