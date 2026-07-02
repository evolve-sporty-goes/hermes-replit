// Extended simple-keyboard configuration for xpra HTML5 client
// Add this to index.html in init_keyboard() function

var Keyboard = window.SimpleKeyboard.default;
var kb = new Keyboard({
  onKeyPress: (button) => onKeyPress(button),
  onKeyReleased: (button) => onKeyReleased(button),
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
  layout: {
    default: [
      "` 1 2 3 4 5 6 7 8 9 0 - = {bksp}",
      "{tab} q w e r t y u i o p [ ] \\",
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
  }
});
window.kb = kb;
window.keyboardShifted = false;

function onKeyPress(button) {
  forward_key(true, button);
  if (button == "{shift}" || button == "{lock}") {
    if (window.keyboardShifted) {
      window.kb.setOptions({ layoutName: "default" });
    } else {
      window.kb.setOptions({ layoutName: "shift" });
    }
    window.keyboardShifted = !window.keyboardShifted;
  }
}

function onKeyReleased(button) {
  forward_key(false, button);
}

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

  var e = {
    which: 0,
    keyCode: 0,
    key: key,
    code: key,
  };
  client._keyb_process(pressed, e);
}