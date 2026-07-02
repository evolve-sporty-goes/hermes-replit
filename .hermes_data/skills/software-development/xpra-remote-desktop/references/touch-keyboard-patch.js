// Touch-to-keyboard patch for xpra HTML5 client
// Add this to index.html after init_tablet_input function

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

// In init_page(), add call after init_tablet_input():
// init_touch_keyboard(client);