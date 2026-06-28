---
name: hermes-webui
description: "Operate, configure, and extend Hermes WebUI — the browser-based interface for Hermes Agent."
version: 1.0.0
author: Hermes Agent community (nesquena/hermes-webui)
license: MIT
platforms: [linux, macos, wsl]
metadata:
  hermes:
    tags: [hermes, webui, web-interface, sse, chat-ui, workspace, browser, self-hosted, three-panel]
    homepage: https://github.com/nesquena/hermes-webui
    related_skills: [hermes-agent, claude-design, sketch]
---

# Hermes WebUI

Hermes WebUI is a lightweight, dark-themed browser interface for [Hermes Agent](https://hermes-agent.nousresearch.com/). Full parity with the CLI experience — streaming chat, session management, workspace file browser, cron/tasks, skills, memory, profiles, voice input, themes/skins. No build step, no framework, no bundler. Python stdlib HTTP server + vanilla JS.

## When to Use This Skill

Load this skill when:
- User asks about the WebUI, web interface, browser UI, or dashboard for Hermes
- User wants to start/stop/restart the web server on a self-hosted install (Replit, VPS, homelab)
- User wants to configure the WebUI: password, port, host, profiles, providers, workspace
- User reports a WebUI issue (won't start, blank page, can't connect, auth loop)
- User wants to extend or modify the WebUI (new panel, API route, theme, slash command)
- You're asked to pair-program or review code in the hermes-webui repo
- User mentions `8787`, `hermes-webui`, `ctl.sh`, `bootstrap.py`, or the three-panel layout

## Overview

| Aspect | Detail |
|--------|--------|
| Repo | `https://github.com/nesquena/hermes-webui` (community, ~288 contributors) |
| Entry | `server.py` (thin routing shell) → `api/` (~56 modules) → `static/` (vanilla JS) |
| Default port | `8787` (env: `HERMES_WEBUI_PORT`) |
| Default bind | `127.0.0.1` (env: `HERMES_WEBUI_HOST`) |
| Default state dir | `~/.hermes/webui/` (env: `HERMES_WEBUI_STATE_DIR`) |
| Default workspace | `~/workspace/` (env: `HERMES_WEBUI_DEFAULT_WORKSPACE`) |
| Agent source | auto-discovered: sibling `../hermes-agent`, or `$HERMES_HOME/hermes-agent`, or `HERMES_WEBUI_AGENT_DIR` |
| Python | 3.11–3.13 (CI matrix); hermes-agent venv preferred |
| Tests | ~7,150 pytest tests in `tests/`; run via `./scripts/test.sh` |
| Lint | ruff (E9, F, B rules) enforced as CI gate |

### Key Design Principle

**No build pipeline.** The WebUI serves `static/` directly and `api/` imports live against the hermes-agent source tree. This means:
- Edits to `*.js` or `*.py` take effect on server restart — no `npm run build`.
- The WebUI imports agent modules directly (`api/config.py`, `api/streaming.py`), so it must be paired with a compatible agent version. Upgrade both together.
- There is no `package.json` build step. CSS is one file (`style.css`), JS is a handful of `<script>`-loaded modules.

---

## Quick Start

```bash
# Clone next to hermes-agent (sibling discovery)
cd ~/hermes-agent
git clone https://github.com/nesquena/hermes-webui.git

cd hermes-webui
./start.sh                                    # foreground, opens browser
# OR
./ctl.sh start                                # background daemon
./ctl.sh status                               # PID, port, /health
./ctl.sh logs --lines 100                     # tail ~/.hermes/webui.log
./ctl.sh stop
```

### Manual launch (no start.sh)

```bash
cd /path/to/hermes-agent
HERMES_WEBUI_PORT=8787 venv/bin/python /path/to/hermes-webui/server.py
```

### Health check

```bash
curl http://127.0.0.1:8787/health
```

---

## Architecture

### Backend (`api/`)

| Module | Role | Lines |
|--------|------|-------|
| `server.py` (root) | ThreadingHTTPServer, auth middleware, SIGPIPE guard, CSRF, test-mode network block | ~725 |
| `routes.py` | ALL GET + POST handlers (`if/elif` dispatch, no decorators) | ~21,205 |
| `config.py` | Discovery, globals, model/provider detection, session LRU cache, env resolution, skill home patching | ~7,993 |
| `streaming.py` | SSE engine, `run_agent`, cancel flags, compression, HERMES_HOME save/restore, metering | ~9,650 |
| `models.py` | Session model + CRUD, per-session profile tracking, CLI/state.db bridge, Claude Code JSONL parse cache | ~6,322 |
| `workspace.py` | File ops: list/read/write/delete, git detection, symlink containment, path safety, upload | ~1,687 |
| `profiles.py` | Multi-profile state, `HERMES_HOME` switching, skill/cron module monkey-patch, thread-local profile context | ~2,450 |
| `auth.py` | Optional password auth, signed HMAC cookies, passkeys/WebAuthn, rate limiting, CSRF token issuance | ~751 |
| `upload.py` | Multipart parser, chunked upload handler | — |
| `onboarding.py` | First-run wizard, real provider config writes, OAuth linking, readiness detection | — |
| `updates.py` | Self-update check + release notes (GitHub releases API) | — |
| `helpers.py` | HTTP JSON helpers (`j()`, `bad()`, `require()`), security headers, path safety | — |
| `passkeys.py` | WebAuthn registration/authentication ceremony | — |
| `gateway_chat.py` / `gateway_watcher.py` | Optional chat-through-Gateway-backend mode | — |
| `state_sync.py` | `/insights` sync — writes message_count to agent's state.db | — |

Backend modules are big — `routes.py` alone is 21k lines. This is a flat dispatch file (`if path == "/api/sessions": ... elif ...`). Route handlers are inline, not decorator-registered.

### Frontend (`static/`)

| File | Role | Lines |
|------|------|-------|
| `index.html` | Template, theme/skin boot, CSRF fetch wrapper, PWA manifest | ~1,790 |
| `messages.js` | `send()`, SSE event handlers, approval/clarify, transcript rendering, streaming | ~6,999 |
| `ui.js` | DOM helpers, `renderMd`, tool call cards, context ring, file tree | — |
| `sessions.js` | Session CRUD, collapsible date groups, search, sidebar | — |
| `workspace.js` | File tree + preview, git badge, central `api()` fetch wrapper | — |
| `panels.js` | Cron, skills, memory, profiles, todos, settings (Control Center) | — |
| `commands.js` | Slash command registry, parser, autocomplete dropdown | — |
| `boot.js` | Event wiring, mobile nav, voice input, theme/skin boot, bfcache handler | — |
| `i18n.js` | Localization catalog (en, es, de, zh, zh-Hant, ru, vi, pt, fr, ja, ko, pl, hu, uk, ar, nl, it, th, id, hi, nb, da, sv, fi, ro, bg, hr, sk, sl, ca, et, lv, lt, cy, el, he, fil, bn, ta, te, ml, mr, ur, ...) | — |
| `style.css` | All CSS incl. themes/skins, mobile responsive, KaTeX | — |
| `sw.js` | Service worker: offline shell cache, version-pinned assets | — |
| `terminal.js` | xterm.js embedded terminal panel | — |
| `onboarding.js` | First-run overlay, provider setup flow | — |
| `outline.js` | Document outline for Markdown preview | — |

All frontend JS is vanilla ES modules / classic scripts — no React, no Vue, no bundler. Vendor assets are vendored (not CDN-only): KaTeX 0.16.22, streaming-markdown 0.2.15, js-yaml 4.1.0. CDN-only deps (Prism.js, xterm.js) use SRI integrity hashes.

---

## Configuration & Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `HERMES_WEBUI_HOST` | `127.0.0.1` | Bind address (`0.0.0.0` for all IPv4) |
| `HERMES_WEBUI_PORT` | `8787` | Port |
| `HERMES_WEBUI_AGENT_DIR` | auto | Path to hermes-agent checkout |
| `HERMES_WEBUI_PYTHON` | auto | Python executable (agent venv preferred) |
| `HERMES_WEBUI_STATE_DIR` | `~/.hermes/webui` | Sessions, settings, projects, last_workspace |
| `HERMES_WEBUI_DEFAULT_WORKSPACE` | `~/workspace` | Default workspace directory |
| `HERMES_WEBUI_DEFAULT_MODEL` | (provider default) | Optional model override |
| `HERMES_WEBUI_PASSWORD` | (unset) | Set to enable password authentication |
| `HERMES_WEBUI_SESSION_TTL` | `2592000` (30d) | Session cookie TTL in seconds |
| `HERMES_WEBUI_CHAT_BACKEND` | `in-process` | Set to `gateway` to route through Hermes Gateway |
| `HERMES_WEBUI_AGENT_CACHE_MAX` | `25` | Max live agent instances in LRU (RAM control) |
| `HERMES_WEBUI_SESSIONS_MAX` | `100` | Max compact Session objects in LRU |
| `HERMES_WEBUI_SSE_CHUNKED` | (unset) | Truthy → chunked Transfer-Encoding (for buffering reverse proxies) |
| `HERMES_WEBUI_EXTENSION_DIR` | (unset) | Local dir served at `/extensions/` |
| `HERMES_WEBUI_EXTENSION_MANIFEST` | (unset) | Relative JSON manifest listing scripts/styles |
| `HERMES_WEBUI_CSP_CONNECT_EXTRA` | (unset) | Extra `connect-src` origins for CSP |
| `HERMES_WEBUI_AUTO_INSTALL` | (unset) | Truthy → auto-install agent deps on bootstrap |
| `HERMES_WEBUI_ISOLATED_PROFILE` | (unset) | Truthy → per-profile `.env` secret isolation |
| `HERMES_HOME` | `~/.hermes` | Base dir for Hermes state |
| `HERMES_WEBUI_SERVER_CWD` | (unset) | Working dir for server process (when agent dir is read-only) |

Settings panels (saved in `~/.hermes/webui/settings.json`) include: `send_key`, `show_cli_sessions`, `show_usage`, `sync_to_insights`, `compact_mode`, `language`, `session_ttl_seconds`.

---

## Chat Backend Modes

1. **In-process (default):** WebUI imports Hermes Agent modules directly and runs the agent loop in the same process. Reads `HERMES_HOME/config.yaml` directly. Fastest, simplest — but version-coupling risk.

2. **Gateway-backed (`HERMES_WEBUI_CHAT_BACKEND=gateway`):** Routes chat through a running Hermes Gateway (OpenAI-compatible API). Useful for multi-container deploys where the agent runs in a separate container. See `docs/advanced-chat-setup.md`.

3. **Custom provider:** Any OpenAI-compatible endpoint (Ollama, LMStudio, vLLM) can be added under Settings → Providers with `base_url` + bearer token.

---

## Profiles

The WebUI supports per-profile isolation mirroring Hermes Agent's profile system:

- Each profile has its own `HERMES_HOME` (sessions, skills, cron, memory, config.yaml).
- Profile state lives in `{profile_home}/webui_state/` (workspaces.json, last_workspace.txt).
- Profile switch via `profiles.py`: updates `os.environ['HERMES_HOME']` and monkey-patches module-level cached paths in `skills_tool`, `skill_manager_tool`, `cron/jobs`.
- HTTP requests carry a `hermes_profile` cookie for per-client profile isolation (thread-local `_tls` in `profiles.py`).
- Isolated mode (`HERMES_WEBUI_ISOLATED_PROFILE`) scopes `.env` secrets per profile to prevent key leakage.

---

## Auth & Security

- **Password auth** (optional): `HERMES_WEBUI_PASSWORD` or set in Settings. HMAC-SHA256 signed cookies, 24h TTL (configurable).
- **Passkeys / WebAuthn**: Register from Settings → System after password login. Once registered, can go passwordless. Stored locally in WebUI state dir.
- **CSRF**: `X-Hermes-CSRF-Token` header on all same-origin unsafe fetch/POST. Token injected into `window.__HERMES_CONFIG__` and auto-attached by the fetch wrapper in `index.html`.
- **Security headers**: X-Content-Type-Options, X-Frame-Options, Referrer-Policy, CSP (with `REPORT-ONLY` collector endpoint).
- **POST body limit**: 20MB.
- **Rate limiting**: Thread-safe PBKDF2-based login rate limiter.
- **CDN**: All CDN resources (Prism, xterm, KaTeX fallback) use SRI integrity hashes.
- **Session TTL**: Clamped to [60s, 1y]; resolved via `HERMES_WEBUI_SESSION_TTL` → settings → default.

---

## Session Management

Sessions live in the WebUI state dir as JSON files + a SQLite index. Key behaviors:

- **Session LRU cache:** `SESSIONS_MAX` controls in-memory footprint; evicted sessions are reloaded from disk on next access.
- **Agent LRU cache:** `AGENT_CACHE_MAX` controls how many live AIAgent instances stay warm. Each pins a full transcript — this is the dominant RAM lever.
- **CLI session bridge:** Agent's `state.db` sessions appear in the sidebar with a gold "cli" badge. Click to import into WebUI with full history. Parsing Claude Code JSONL transcripts has a per-file mtime/size/ctime cache (`_CLAUDE_CODE_PARSE_CACHE`).
- **Compression:** Manual `/compress` or automatic when context nears `agent.compression.threshold`. Streaming turns can be compressed mid-stream on supported models.
- **Fork / lineage:** Sessions can be branched from any message point for exploration. Lineage is exposed via `/api/session/lineage-report/<sid>`.
- **Worktrees:** Sessions can be bound to git worktrees (`-w` mode).

---

## Deployment

### SSH tunnel (recommended for remote)

```bash
# On remote machine
HERMES_WEBUI_HOST=0.0.0.0 HERMES_WEBUI_PASSWORD=strongpass ./ctl.sh start

# On local machine
ssh -N -L 8787:127.0.0.1:8787 user@remote
# → open http://localhost:8787
```

### Tailscale

```bash
HERMES_WEBUI_HOST=0.0.0.0 HERMES_WEBUI_PASSWORD=strongpass ./ctl.sh start
# → http://<tailscale-ip>:8787
```

### Docker

```bash
docker compose up -d      # single container (agent in-process)
# OR
docker compose -f docker-compose.two-container.yml up -d  # separate agent + webui
```

Common failure modes (see `docs/docker.md`):
| Symptom | Fix |
|---------|-----|
| `PermissionError` at startup | Set `UID=$(id -u)` in `.env` |
| Workspace empty | UID mismatch on `/workspace` mount |
| `git: command not found` | Two-container architectural limit (#681) — use single container |
| `.env: permission denied` (#1389) | Set `HERMES_SKIP_CHMOD=1` |

#### Replit-specific (no sudo, Nix)

Per user memory:
- Node 24 + npx available; use `hermes-webui` at `~/hermes-agent/hermes-webui/`.
- Use `ctl.sh restart` (not systemd/supervisord — no init system on Replit Nix).
- Git push via HTTPS needs a `.pat` file workaround (Replit askpass bug): `git push "https://$(cat .pat | tr -d '\n')@github.com/org/repo.git" main`
- No `sudo`/`apt` on Replit Nix — install Python deps via `uv` or `pip install --user`.
- Camoufox (browser tool) needs `gtk3`, `dbus-glib`, `libXt`, `libX11` — available via Replit Nix channels.

---

## Testing

```bash
# Full suite (creates/uses .venv with Python 3.11–3.13)
./scripts/test.sh

# Focused run
./scripts/test.sh tests/test_regressions.py -v

# Override Python for venv creation
HERMES_WEBUI_TEST_PYTHON=/path/to/python3.12 ./scripts/test.sh tests/ -v
```

- Tests run against an isolated server with a separate state directory — production data and real cron jobs are never touched.
- CI runs on Python 3.11, 3.12, 3.13 (3 parallel shards each), plus ruff lint gate, headless browser smoke, and Docker smoke.
- `HERMES_WEBUI_TEST_NETWORK_BLOCK=1` (set by `conftest.py`) blocks outbound sockets to non-local addresses for hermetic tests.

---

## Common Operations

### Restart the server

```bash
cd ~/hermes-agent/hermes-webui
./ctl.sh restart
```

### Change port or bind address

```bash
HERMES_WEBUI_PORT=9000 ./ctl.sh start
HERMES_WEBUI_HOST=0.0.0.0 ./ctl.sh start    # bind all interfaces (needs password!)
```

### Enable password auth

```bash
HERMES_WEBUI_PASSWORD=yourpassword ./ctl.sh start
# OR set in Settings → System after first login
```

### View logs

```bash
./ctl.sh logs --lines 200
# or directly:
tail -f ~/.hermes/webui.log
```

### Reset/clear state

```bash
./ctl.sh stop
rm -rf ~/.hermes/webui/sessions/ ~/.hermes/webui/settings.json
./ctl.sh start
```

---

## Troubleshooting

| Symptom | Likely Cause | Fix |
|---------|-------------|-----|
| `Address already in use` on start | Old server still running | `./ctl.sh stop` or `lsof -i :8787` + `kill <PID>` |
| `AIAgent not available` / import errors | Agent source not found or incompatible version | Set `HERMES_WEBUI_AGENT_DIR` to hermes-agent checkout; upgrade both together |
| Blank page | Static assets not loading | Check `REPO_ROOT` resolution; verify `static/` dir exists |
| Auth loop (redirects back to `/login`) | Cookie rejected | Clear cookies; check `HERMES_WEBUI_SESSION_TTL`; ensure same-origin |
| SSE stream drops on network blip | SSH tunnel dropped | WebUI has auto-reconnect; check `HERMES_WEBUI_SSE_CHUNKED` behind buffering proxies |
| `PermissionError` on state write | UID mismatch (Docker) | Set `UID=$(id -u)` in `.env` |
| Models not appearing in dropdown | Provider not configured | Add provider in Settings → Providers, or set env var for default provider |
| `config.yaml (not found, using defaults)` | `HERMES_HOME` not mounted correctly (Docker) | Mount `~/.hermes` at the right path inside container |

---

## Extension Points

The WebUI is designed to be modified without a build step:

- **New API route:** Add `elif path == "/api/my/endpoint":` block in `api/routes.py`. Import helpers from `api/helpers.py`.
- **New frontend panel:** Add a tab in `static/index.html`, wire it in `static/panels.js`, style in `static/style.css`.
- **New slash command:** Register in `static/commands.js` autocomplete list.
- **New theme/skin:** Add CSS variables to `static/style.css` under `[data-skin="my-skin"]`, add option in Settings → Appearance.
- **New locale:** Add entry in `static/i18n.js` catalog.
- **WebUI Extensions (admin-injected):** Use `HERMES_WEBUI_EXTENSION_DIR` + manifest to inject custom JS/CSS without modifying source. See `docs/EXTENSIONS.md`.

---

## Relationship to hermes-agent

- **Tight coupling:** WebUI imports agent modules directly (`api/config.py` → `hermes_constants`, `api/streaming.py` → agent loop). There is no stable API boundary yet (tracked in issues #1925 / #2491).
- **Upgrade policy:** Always upgrade WebUI and hermes-agent together (same release train/version/date). Version skew causes import or behavior drift.
- **Source boundary (Docker multi-container):** The two-container compose mounts `hermes-agent-src` read-only into the WebUI. This prevents WebUI-side rewrites but is an implementation coupling, not a stable API boundary. See `docs/rfcs/agent-source-boundary.md`.

---

## Key Paths

| Path | Purpose |
|------|---------|
| `~/hermes-agent/hermes-webui/` | Repo root |
| `~/.hermes/webui/` | State dir (sessions, settings, projects, attachments) |
| `~/.hermes/webui/sessions/` | Session JSON files |
| `~/.hermes/webui/settings.json` | UI settings (theme, skin, language, toggles) |
| `~/.hermes/webui.log` | Server log (ctl.sh) |
| `~/.hermes/webui.pid` | PID file (ctl.sh) |
| `~/.hermes/config.yaml` | Hermes agent config (shared with CLI) |
| `~/.hermes/webui/attachments/<session_id>/` | Uploaded file attachments |

---

## Docs Index

| Doc | Content |
|-----|---------|
| `README.md` | Full feature list, quick start, Docker, remote access |
| `ARCHITECTURE.md` | System design, all API endpoints, implementation notes |
| `CONTRIBUTING.md` | Contribution style, PR expectations, local verification |
| `TESTING.md` | Manual browser test plan + automated coverage reference |
| `THEMES.md` | Theme + skin system, custom theme guide |
| `DESIGN.md` | Design tokens and direction |
| `docs/docker.md` | Docker compose setup, common failures, bind-mount migration |
| `docs/remote-access.md` | SSH tunnel, Tailscale, phone access |
| `docs/advanced-chat-setup.md` | Dynamic recall prefill + Gateway-backed chat |
| `docs/onboarding.md` | First-run wizard walkthrough |
| `docs/EXTENSIONS.md` | Admin-controlled extension injection |
| `docs/workspace-git.md` | Workspace Git controls |
| `docs/supervisor.md` | systemd/supervisord/runit/s6 setup |
| `CHANGELOG.md` | Release notes per version |
| `ROADMAP.md` | Feature roadmap |
| `SPRINTS.md` | Forward sprint plan |