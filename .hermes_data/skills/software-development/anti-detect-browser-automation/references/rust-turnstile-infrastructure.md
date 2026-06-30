# Rust Turnstile Solver Infrastructure

Located at `~/rust-cf-turnstile-bypass/rust-cf-turnstile-bypass/`.

## Components

### token-server (port 8080)
WebSocket server that routes Turnstile tokens from solver iframes to receiver clients.

**Binary:** `token-server/target/release/token_server`
**Protocol:** Binary WebSocket frames
- `[0, ...solver_idx, ...token]` — incoming token from solver → routed to receiver with least tokens
- `[1]` — register as receiver
- `[2]` — query total token count (returns 8 bytes LE u64)
- `[3]` — request solver idx (returns 4 bytes LE u32, increments counter)

**Start:**
```bash
cd ~/rust-cf-turnstile-bypass/rust-cf-turnstile-bypass/token-server
./target/release/token_server
# Or: cargo run --release
```

### turnstile-clicker (auto-clicker)
Screen-capture-based Turnstile checkbox detector and clicker.

**Binary:** `turnstile-clicker/target/release/turnstile-clicker`
**How it works:** Captures all screens, scans for grey checkbox borders (RGB ~74±30),
finds connected border rings, identifies interior rect, clicks random point inside.

**Controls:**
- Press `F8` to toggle active/paused
- Scans every 250ms when active
- Clicks with random offset within detected checkbox interior

**Start:**
```bash
cd ~/rust-cf-turnstile-bypass/rust-cf-turnstile-bypass/turnstile-clicker
DISPLAY=:0 cargo run --release
```

**Config constants** (in `src/main.rs`):
- `MIN_INTERIOR_AREA`: 200 px²
- `MAX_INTERIOR_AREA`: 200000 px²
- `BORDER_TARGET`: 74 (greyscale)
- `BORDER_TOLERANCE`: 30
- `MIN_BORDER_PIXELS`: 50

### token-harvester (iframe farm)
HTML page that spawns multiple Turnstile solver iframes.

**Files:**
- `token-harvester/index.html` — main farm page
- `token-harvester/solver_iframe.html` — individual solver iframe
- `token-harvester/index.js` — (referenced but may not exist in this version)

**Config** (set in `index.html`):
```javascript
const TOKEN_SERVER_HOST = "ws://localhost:8080";
const PRELOAD_IFRAMES = 12;
const SITEKEY = "0x4AAAAAAAWXJGBD7bONzLBd";  // Set to target sitekey
```

**Solver iframe** patches `turnstile.render()` to auto-reset on expiry/error,
creating a self-renewing token factory.

## Usage Pattern

1. Start token server: `./target/release/token_server &`
2. Start auto-clicker: `DISPLAY=:0 cargo run --release &`
3. Press F8 to activate clicker
4. Open harvester page in browser with target sitekey
5. Clicker detects and clicks Turnstile checkboxes on screen
6. Tokens flow: solver iframe → token_server → receiver client
7. Receiver client uses token in Clerk FAPI calls

## Important: Display Requirements

- The clicker uses `screenshots::Screen::all()` and `enigo` for mouse control
- Requires a real display (Xvfb works: `Xvfb :0 -screen 0 1280x720x24 &`)
- The browser showing the Turnstile widget MUST be on the same display
- Set `DISPLAY=:0` for both the clicker and the browser

## Cloudflare Origin Restrictions

- Turnstile **rejects** `data:` URIs and `localhost` origins (error 600010)
- Must serve the Turnstile page on a **public domain**
- Use `npx localtunnel --port 9999` to expose a local HTTP server publicly
- The bypass server also blocks private IPs (127.0.0.1, 172.x, etc.)
