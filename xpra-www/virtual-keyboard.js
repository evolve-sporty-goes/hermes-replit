/**
 * Complete Virtual Keyboard Replacement for Xpra HTML5 Client
 * Uses simple-keyboard (modern version) with full modifier key support
 * Replaces the old keyboard implementation in index.html
 */

(function() {
    'use strict';

    // Wait for simple-keyboard to load from CDN
    function loadSimpleKeyboard() {
        return new Promise((resolve, reject) => {
            if (window.SimpleKeyboard) {
                resolve(window.SimpleKeyboard.default || window.SimpleKeyboard);
                return;
            }

            // Load CSS
            const cssLink = document.createElement('link');
            cssLink.rel = 'stylesheet';
            cssLink.href = 'https://unpkg.com/simple-keyboard@latest/build/css/index.css';
            document.head.appendChild(cssLink);

            // Load JS
            const script = document.createElement('script');
            script.src = 'https://unpkg.com/simple-keyboard@latest/build/index.js';
            script.onload = () => {
                const Keyboard = window.SimpleKeyboard.default || window.SimpleKeyboard;
                resolve(Keyboard);
            };
            script.onerror = reject;
            document.head.appendChild(script);
        });
    }

    // Custom keyboard layout with full modifier support
    const keyboardLayout = {
        default: [
            '` 1 2 3 4 5 6 7 8 9 0 - = {bksp}',
            '{tab} q w e r t y u i o p [ ] \\',
            '{lock} a s d f g h j k l ; \' {enter}',
            '{shift} z x c v b n m , . / {shift}',
            '{control} {alt} {meta} .com @ {space} {meta} {alt} {control} {pageup} {pagedown} {contextmenu}'
        ],
        shift: [
            '~ ! @ # $ % ^ & * ( ) _ + {bksp}',
            '{tab} Q W E R T Y U I O P { } |',
            '{lock} A S D F G H J K L : " {enter}',
            '{shift} Z X C V B N M < > ? {shift}',
            '{control} {alt} {meta} .com @ {space} {meta} {alt} {control} {pageup} {pagedown} {contextmenu}'
        ]
    };

    // Display names for special keys
    const keyDisplay = {
        '{bksp}': '⌫',
        '{tab}': '⇥',
        '{lock}': '⇪',
        '{enter}': '↵',
        '{shift}': '⇧',
        '{control}': 'Ctrl',
        '{alt}': 'Alt',
        '{meta}': '⌘',
        '{pageup}': 'PgUp',
        '{pagedown}': 'PgDn',
        '{contextmenu}': '☰',
        '{space}': 'Space',
        '.com': '.com',
        '@': '@'
    };

    // Track modifier state
    const modifierState = {
        shift: false,
        control: false,
        alt: false,
        meta: false
    };

    // Initialize the virtual keyboard
    async function initVirtualKeyboard(client) {
        try {
            const Keyboard = await loadSimpleKeyboard();
            console.log('[VK] simple-keyboard loaded:', Keyboard);

            // Create keyboard instance
            const keyboardContainer = document.querySelector('.simple-keyboard');
            if (!keyboardContainer) {
                console.error('[VK] .simple-keyboard container not found');
                return;
            }

            const kb = new Keyboard({
                layout: keyboardLayout,
                display: keyDisplay,
                theme: 'hg-theme-default hg-layout-default',
                onKeyPress: (button) => onKeyPress(client, button, true),
                onKeyReleased: (button) => onKeyReleased(client, button),
                onChange: (input) => onChange(input),
                mergeDisplay: true,
                preventMouseDownDefault: false,
                preventMouseUpDefault: false,
                useMouseEvents: true,
                useTouchEvents: true,
                autoUseTouchEvents: true,
                physicalKeyboardHighlight: false,
                disableButtonHold: false
            });

            window.virtualKeyboard = kb;
            window.virtualKeyboardClient = client;

            // Initialize modifier state
            modifierState.shift = false;
            modifierState.control = false;
            modifierState.alt = false;
            modifierState.meta = false;

            // Add custom styles for modifier keys
            addKeyboardStyles();

            // Update visual state
            updateModifierVisuals(kb);

            console.log('[VK] Virtual keyboard initialized');
            return kb;
        } catch (err) {
            console.error('[VK] Failed to initialize:', err);
        }
    }

    function addKeyboardStyles() {
        const style = document.createElement('style');
        style.textContent = `
            .hg-button.active-modifier {
                background-color: #4CAF50 !important;
                color: white !important;
                border-color: #45a049 !important;
                box-shadow: inset 0 2px 4px rgba(0,0,0,0.2) !important;
            }
            .hg-button.modifier-locked {
                background-color: #2196F3 !important;
                color: white !important;
                border-color: #1976D2 !important;
            }
            .hg-button[data-skbtn*="control"],
            .hg-button[data-skbtn*="alt"],
            .hg-button[data-skbtn*="meta"],
            .hg-button[data-skbtn*="shift"] {
                transition: all 0.15s ease;
            }
            .hg-button[data-skbtn="{contextmenu}"] {
                background-color: #FF9800 !important;
                color: white !important;
            }
            .hg-button[data-skbtn="{pageup}"],
            .hg-button[data-skbtn="{pagedown}"] {
                background-color: #607D8B !important;
                color: white !important;
            }
        `;
        document.head.appendChild(style);
    }

    function onKeyPress(client, button, pressed) {
        console.log('[VK] Key press:', button, 'pressed:', pressed);

        // Update modifier state for modifier keys
        if (pressed && isModifierKey(button)) {
            modifierState[getModifierName(button)] = true;
            updateModifierVisuals(window.virtualKeyboard);
        }

        // Build modifiers array from current state
        const modifiers = [];
        if (modifierState.shift) modifiers.push('shift');
        if (modifierState.control) modifiers.push('control');
        if (modifierState.alt) modifiers.push('alt');
        if (modifierState.meta) modifiers.push('meta');

        // Send key event to xpra server
        sendKeyEvent(client, button, true, modifiers);
    }

    function onKeyReleased(client, button) {
        console.log('[VK] Key released:', button);

        // Update modifier state for modifier keys
        if (isModifierKey(button)) {
            modifierState[getModifierName(button)] = false;
            updateModifierVisuals(window.virtualKeyboard);
        }

        // Build modifiers array from current state
        const modifiers = [];
        if (modifierState.shift) modifiers.push('shift');
        if (modifierState.control) modifiers.push('control');
        if (modifierState.alt) modifiers.push('alt');
        if (modifierState.meta) modifiers.push('meta');

        // Send key release to xpra server
        sendKeyEvent(client, button, false, modifiers);
    }

    function onChange(input) {
        console.log('[VK] Input changed:', input);
    }

    function isModifierKey(button) {
        return ['{shift}', '{control}', '{alt}', '{meta}'].includes(button);
    }

    function getModifierName(button) {
        const map = {
            '{shift}': 'shift',
            '{control}': 'control',
            '{alt}': 'alt',
            '{meta}': 'meta'
        };
        return map[button];
    }

    function getKeyName(button) {
        const keyMap = {
            '{bksp}': 'Backspace',
            '{enter}': 'Return',
            '{space}': 'Space',
            '{tab}': 'Tab',
            '{lock}': 'CapsLock',
            '{shift}': 'Shift',
            '{control}': 'Control',
            '{alt}': 'Alt',
            '{meta}': 'Meta',
            '{pageup}': 'PageUp',
            '{pagedown}': 'PageDown',
            '{contextmenu}': 'ContextMenu',
            '.com': '.com',
            '@': '@'
        };
        return keyMap[button] || button;
    }

    function sendKeyEvent(client, button, pressed, modifiers) {
        const keyName = getKeyName(button);
        const keyCode = keyName.charCodeAt(0) || 0;

        const packet = [
            'key-action',
            client.topwindow,  // window ID
            keyName,
            pressed,
            modifiers,
            keyCode,  // keyval
            keyName,  // keystr
            keyCode,  // client_keycode
            0  // group
        ];

        console.log('[VK] Sending key packet:', packet);
        client.send(packet);
    }

    function updateModifierVisuals(kb) {
        if (!kb || !kb.buttonElements) return;

        Object.entries(modifierState).forEach(([mod, active]) => {
            const button = `{${mod}}`;
            const btnEl = kb.buttonElements[button];
            if (btnEl && btnEl.length) {
                btnEl.forEach(el => {
                    if (active) {
                        el.classList.add('active-modifier');
                        el.classList.remove('modifier-locked');
                    } else {
                        el.classList.remove('active-modifier');
                        el.classList.remove('modifier-locked');
                    }
                });
            }
        });

        // Also handle Shift/CapsLock visual state
        const shiftBtn = kb.buttonElements['{shift}'];
        if (shiftBtn && shiftBtn.length) {
            shiftBtn.forEach(el => {
                if (modifierState.shift) {
                    el.classList.add('active-modifier');
                } else {
                    el.classList.remove('active-modifier');
                }
            });
        }

        const lockBtn = kb.buttonElements['{lock}'];
        if (lockBtn && lockBtn.length) {
            lockBtn.forEach(el => {
                if (window.keyboardShifted) {
                    el.classList.add('active-modifier');
                } else {
                    el.classList.remove('active-modifier');
                }
            });
        }
    }

    // Expose for debugging
    window.virtualKeyboardAPI = {
        getState: () => ({ ...modifierState }),
        setModifier: (mod, active) => {
            modifierState[mod] = active;
            updateModifierVisuals(window.virtualKeyboard);
        },
        sendTestKey: (client, key, pressed) => sendKeyEvent(client, key, pressed, [])
    };

    // Make initVirtualKeyboard globally available
    window.initVirtualKeyboard = initVirtualKeyboard;

})();