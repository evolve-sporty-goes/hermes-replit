#!/bin/bash
# Enable Android virtual keyboard on touch for xpra HTML5 client
# Modifies index.html to focus the pasteboard textarea on canvas tap

set -euo pipefail

XPRA_WWW_DIR="/nix/store/jbi45gv4q60f4ynsqwjgda0c8m7vyimd-xpra-6.3/share/xpra/www"
INDEX_HTML="$XPRA_WWW_DIR/index.html"

# Backup
cp "$INDEX_HTML" "$INDEX_HTML.bak.$(date +%s)"

# Add touch handler to focus pasteboard on canvas tap
# This goes after the init_tablet_input function
cat > /tmp/touch_patch.js << 'EOF'

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

EOF

# Insert the new function after init_tablet_input
sed -i '/^      function init_tablet_input(client) {/,/^      function init_clipboard(client) {/ {
  /^      function init_clipboard(client) {/i\
      function init_touch_keyboard(client) {\
        var screen = $("#screen");\
        var pasteboard = $("#pasteboard");\
\
        screen.on("click touchstart", function(e) {\
          if ($(e.target).closest("#float_menu, .menu-content, #about, #sessioninfo, #window_preview").length) {\
            return;\
          }\
\
          pasteboard.focus();\
          pasteboard.prop("readonly", false);\
\
          setTimeout(function() {\
            pasteboard.prop("readonly", true);\
          }, 100);\
        });\
      }\

}' "$INDEX_HTML"

# Call the new function in init_page after init_tablet_input
sed -i '/init_tablet_input(client);/a\        init_touch_keyboard(client);' "$INDEX_HTML"

echo "Patched $INDEX_HTML - touch keyboard enabled"
echo "Backup saved as $INDEX_HTML.bak.*"
EOF
chmod +x /home/runner/workspace/scripts/enable-touch-keyboard.sh
/home/runner/workspace/scripts/enable-touch-keyboard.sh