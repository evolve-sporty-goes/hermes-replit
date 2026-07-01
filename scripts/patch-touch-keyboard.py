#!/usr/bin/env python3
# Enable Android virtual keyboard on touch for xpra HTML5 client

import re

INDEX_HTML = "/home/runner/workspace/xpra-www/index.html"

# Backup
import shutil, datetime
shutil.copy2(INDEX_HTML, INDEX_HTML + ".bak." + datetime.datetime.now().strftime("%s"))

with open(INDEX_HTML, 'r') as f:
    content = f.read()

# Add new function after init_tablet_input
new_function = '''

      // Touch-to-keyboard: focus pasteboard on canvas tap (triggers Android keyboard)
      function init_touch_keyboard(client) {
        var screen = $("#screen");
        var pasteboard = $("#pasteboard");

        screen.on("click touchstart", function(e) {
          // Don't interfere with menu/button clicks
          if ($(e.target).closest("#float_menu, .menu-content, #about, #sessioninfo, #window_preview").length) {
            return;
          }

          // Focus the pasteboard to trigger virtual keyboard
          pasteboard.focus();
          pasteboard.prop("readonly", false);

          // Re-enable readonly after a short delay to allow keyboard input
          setTimeout(function() {
            pasteboard.prop("readonly", true);
          }, 100);
        });
      }

'''

# Find init_tablet_input function and add our new function after it
pattern = r'(      function init_tablet_input\(client\) \{.*?^\n      function init_clipboard\(client\) \{)'
replacement = r'\1' + new_function
content = re.sub(pattern, replacement, content, flags=re.DOTALL | re.MULTILINE)

# Add call to init_touch_keyboard after init_tablet_input call
content = content.replace(
    'init_tablet_input(client);',
    'init_tablet_input(client);\n        init_touch_keyboard(client);'
)

with open(INDEX_HTML, 'w') as f:
    f.write(content)

print("Patched index.html successfully")