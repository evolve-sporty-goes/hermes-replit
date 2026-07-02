#!/usr/bin/env python3
# Replace the entire keyboard implementation with the new complete virtual keyboard

INDEX_HTML = "/home/runner/workspace/xpra-www/index.html"

import re

with open(INDEX_HTML, 'r') as f:
    content = f.read()

# 1. Add the virtual keyboard script before the closing </body> tag
# Find the closing body tag and insert our script before it
virtual_keyboard_script = '''
    <!-- Complete Virtual Keyboard Replacement -->
    <script src="/virtual-keyboard-complete.js"></script>
'''

content = content.replace('</body>', virtual_keyboard_script + '\n</body>')

# 2. Replace the init_keyboard function completely
# Find the init_keyboard function and replace it
old_init_keyboard_start = '      function init_keyboard(client) {'
old_init_keyboard_end = '      }'

# Find the function boundaries
start_idx = content.find(old_init_keyboard_start)
if start_idx == -1:
    print("ERROR: Could not find init_keyboard function")
    exit(1)

# Find the matching closing brace - count braces
brace_count = 0
end_idx = start_idx
in_function = False
for i, char in enumerate(content[start_idx:], start_idx):
    if char == '{':
        brace_count += 1
        in_function = True
    elif char == '}':
        brace_count -= 1
        if in_function and brace_count == 0:
            end_idx = i + 1
            break

if end_idx == start_idx:
    print("ERROR: Could not find end of init_keyboard function")
    exit(1)

# Replace the entire function
new_init_keyboard = '''      function init_keyboard(client) {
        // Load and initialize the complete virtual keyboard replacement
        if (window.initVirtualKeyboard) {
            window.initVirtualKeyboard(client);
        } else {
            console.error('[VK] initVirtualKeyboard not available, loading script...');
            // Fallback: load script dynamically
            var script = document.createElement('script');
            script.src = '/virtual-keyboard-complete.js';
            script.onload = function() {
                if (window.initVirtualKeyboard) {
                    window.initVirtualKeyboard(client);
                }
            };
            document.head.appendChild(script);
        }

        // Show/hide keyboard based on param
var keyboard = getboolparam("keyboard", Utilities.isMobile());
        if (!keyboard) {
          $(".simple-keyboard").hide();
          $("#keyboard_button").removeClass("icon-toggled");
        } else {
          $(".simple-keyboard").show();
          $("#keyboard_button").addClass("icon-toggled");
        }
      }'''

content = content[:start_idx] + new_init_keyboard + content[end_idx:]

# 3. Remove the old onKeyPress, onKeyReleased, forward_key functions (they're now in virtual-keyboard-complete.js)
# These are defined after init_keyboard, let's find and remove them
# We'll keep the functions that are still needed (toggle_keyboard, etc.)

with open(INDEX_HTML, 'w') as f:
    f.write(content)

print("Replaced keyboard implementation with complete virtual keyboard")