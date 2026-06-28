# Browser Live View — Real-Time Visual Monitoring

When you need to literally *watch* the browser as the agent works (not just read snapshots), you need a VNC-capable setup.

## Options

### Camofox with Docker + VNC

```bash
docker run -d \
  --name camofox-browser \
  --restart unless-stopped \
  -p 9377:9377 \
  -p 6080:6080 \
  -p 5901:5900 \
  -e CAMOFOX_PORT=9377 \
  -e ENABLE_VNC=1 \
  -e VNC_BIND=0.0.0.0 \
  -e VNC_RESOLUTION=1920x1080 \
  -v ~/.camofox-docker:/root/.camofox \
  camofox-browser:latest
```

Then open `http://localhost:6080` (noVNC) to watch live. Native VNC clients connect to `localhost:5901`.

### Local Chromium via CDP

Launch Chrome with remote debugging:
```bash
google-chrome --remote-debugging-port=9222 --remote-debugging-address=0.0.0.0
```

Then use `/browser connect` or set `browser.cdp_url: 'http://localhost:9222'` in config.yaml. The agent uses this live connection for all browser tools, and you can watch the browser window directly.

## Config

- `browser.dialog_policy: must_respond` — agent must handle dialogs before continuing.
- `browser.dialog_timeout_s: 300` — max seconds to wait for dialog handling.
- `browser.command_timeout: 30` — per-command timeout for browser actions.

## Limitation

Cloud providers (Browserbase, Browser Use, Firecrawl) do NOT expose a live-view endpoint. The agent operates on their cloud sessions via API — you only see snapshots, not a live window.
