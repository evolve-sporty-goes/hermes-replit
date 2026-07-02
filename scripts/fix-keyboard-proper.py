#!/usr/bin/env python3
# Properly fix modifier key handling - track state and include in all key events

INDEX_HTML = "/home/runner/workspace/xpra-www/index.html"

import re

with open(INDEX_HTML, 'r') as f:
    content = f.read()

# 1. Update the forward_key function to track modifier state and include modifiers in events
old_forward_key = '''        function forward_key(pressed, button) {
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
var e = {
            which: 0,
            keyCode: 0,
            key: key,
            code: key,
          };
          client._keyb_process(pressed, e);
        }'''

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
          } [button] || button;
          
          // Track modifier key state
          if (pressed && (button == "{shift}" || button == "{control}" || button == "{alt}" || button == "{meta}")) {
            window._modifierState = window._modifierState || {};
            window._modifierState[button] = true;
          } else if (!pressed && (button == "{shift}" || button == "{control}" || button == "{alt}" || button == "{meta}")) {
            window._modifierState = window._modifierState || {};
            window._modifierState[button] = false;
          }
          
          // Build modifiers array from current state
          var modifiers = [];
          if (window._modifierState) {
            if (window._modifierState["{shift}"]) modifiers.push("shift");
            if (window._modifierState["{control}"]) modifiers.push("control");
            if (window._modifierState["{alt}"]) modifiers.push("alt");
            if (window._modifierState["{meta}"]) modifiers.push("meta");
          }
          
var e = {
            which: 0,
            keyCode: 0,
            key: key,
            code: key,
            modifiers: modifiers
          };
          client._keyb_process(pressed, e);
        }'''

content = content.replace(old_forward_key, new_forward_key)

# 2. Update onKeyPress to handle modifier keys without duplicating state
old_onkeypress = '''        function onKeyPress(button) {
          forward_key(true, button);
          
          // Handle modifier keys as sticky/locking (like Shift)
          if (button == "{shift}" || button == "{lock}") {
            if (window.keyboardShifted) {
              window.kb.setOptions({ layoutName: "default" });
            } else {
              window.kb.setOptions({ layoutName: "shift" });
            }
            window.keyboardShifted = !window.keyboardShifted;
          }
          else if (button == "{control}" || button == "{alt}" || button == "{meta}") {
            // Toggle modifier key state - add/remove from pressed modifiers
            var attr = "data-" + button.substring(1, button.length - 1); // e.g., data-control
            var pressed = window.kb.buttonElements[button].getAttribute(attr) === "true";
            window.kb.buttonElements[button].setAttribute(attr, pressed ? "false" : "true");
            
            // Update visual state
            if (!pressed) {
              window.kb.buttonElements[button].classList.add("hg-active");
            } else {
              window.kb.buttonElements[button].classList.remove("hg-active");
            }
          }
          else if (button == "{contextmenu}") {
            // ContextMenu key: trigger right-click on focused element
            var e = {
              which: 3,
              button: 2,
              buttons: 2,
              clientX: 0,
              clientY: 0,
              type: "contextmenu"
            };
            var target = document.activeElement || document.body;
            target.dispatchEvent(new MouseEvent("contextmenu", {bubbles: true, cancelable: true, button: 2, buttons: 2}));
            // Also send right-click to server
            var canvas = document.querySelector("#screen canvas");
            if (canvas) {
              canvas.dispatchEvent(new MouseEvent("mousedown", {bubbles: true, cancelable: true, button: 2, buttons: 2, clientX: 0, clientY: 0}));
              canvas.dispatchEvent(new MouseEvent("mouseup", {bubbles: true, cancelable: true, button: 2, buttons: 0, clientX: 0, clientY: 0}));
            }
          }
        }'''

new_onkeypress = '''        function onKeyPress(button) {
          forward_key(true, button);
          
          // Handle Shift/CapsLock as before (layout toggle)
          if (button == "{shift}" || button == "{lock}") {
            if (window.keyboardShifted) {
              window.kb.setOptions({ layoutName: "default" });
            } else {
              window.kb.setOptions({ layoutName: "shift" });
            }
            window.keyboardShifted = !window.keyboardShifted;
          }
          else if (button == "{control}" || button == "{alt}" || button == "{meta}") {
            // Toggle modifier key visual state (sticky)
            var attr = "data-" + button.substring(1, button.length - 1); // e.g., data-control
            var pressed = window.kb.buttonElements[button].getAttribute(attr) === "true";
            window.kb.buttonElements[button].setAttribute(attr, pressed ? "false" : "true");
            
            // Update visual state
            if (!pressed) {
              window.kb.buttonElements[button].classList.add("hg-active");
            } else {
              window.kb.buttonElements[button].classList.remove("hg-active");
            }
          }
          else if (button == "{contextmenu}") {
            // ContextMenu key: trigger right-click on focused element
            var e = {
              which: 3,
              button: 2,
              buttons: 2,
              clientX: 0,
              clientY: 0,
              type: "contextmenu"
            };
            var target = document.activeElement || document.body;
            target.dispatchEvent(new MouseEvent("contextmenu", {bubbles: true, cancelable: true, button: 2, buttons: 2}));
            // Also send right-click to server via canvas
            var canvas = document.querySelector("#screen canvas");
            if (canvas) {
              canvas.dispatchEvent(new MouseEvent("mousedown", {bubbles: true, cancelable: true, button: 2, buttons: 2, clientX: 0, clientY: 0}));
              canvas.dispatchEvent(new MouseEvent("mouseup", {bubbles: true, cancelable: true, button: 2, buttons: 0, clientX: 0, clientY: 0}));
            }
          }
        }'''

content = content.replace(old_onkeypress, new_onkeypress)

# 3. Update forward_key to handle contextmenu key properly (it's a regular key, not a modifier)
old_contextmenu_in_forward = '"{contextmenu}": "ContextMenu",'
# This is already correct, just need to ensure it's handled as a regular key press

with open(INDEX_HTML, 'w') as f:
    f.write(content)

print("Fixed keyboard modifier handling properly")