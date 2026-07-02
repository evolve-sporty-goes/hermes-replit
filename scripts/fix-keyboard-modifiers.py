#!/usr/bin/env python3
# Fix modifier keys to be sticky (locking) like Shift, and add right-click for ContextMenu

INDEX_HTML = "/home/runner/workspace/xpra-www/index.html"

import re

with open(INDEX_HTML, 'r') as f:
    content = f.read()

# Update the onKeyPress function to handle modifier keys (control, alt, meta) as sticky/locking like Shift
old_onkeypress = '''        function onKeyPress(button) {
          forward_key(true, button);
          if (button == "{shift}" || button == "{lock}") {
            if (window.keyboardShifted) {
              window.kb.setOptions({
                layoutName: "default"
              });
            } else {
              window.kb.setOptions({
                layoutName: "shift"
              });
            }
            window.keyboardShifted = !window.keyboardShifted;
          }
        }'''

new_onkeypress = '''        function onKeyPress(button) {
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

content = content.replace(old_onkeypress, new_onkeypress)

with open(INDEX_HTML, 'w') as f:
    f.write(content)

print("Fixed modifier keys and context menu")