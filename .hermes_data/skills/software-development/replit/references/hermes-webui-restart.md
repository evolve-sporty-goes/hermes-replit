# Hermes WebUI Restart Procedure (2026-06)

## Canonical restart command

The Hermes WebUI docs specify `./ctl.sh restart` from the webui directory. This is the ONLY supported restart path. Do NOT use `python server.py` directly or `nohup ... &` — these bypass the PID/state management and cause stale-lock failures.

```bash
cd ~/hermes-agent/hermes-webui
./ctl.sh restart
```

On success, output is:
```
[ctl] Hermes WebUI is stopped
[ctl] Started Hermes WebUI (PID <N>)
[ctl] Bound: 127.0.0.1:8787
[ctl] Log: /home/runner/workspace/.hermes_data/webui.log
```

## Common failure: "Another server is already responding"

**Symptom:** Server refuses to start with `[!!] FATAL: Another server is already responding on 127.0.0.1:8787` even though `fuser 8787/tcp` shows the port is free.

**Root cause:** A stale PID file at `~/.hermes/webui.pid` (or `$HERMES_HOME/webui.pid`) points to a dead process, while TIME_WAIT sockets from the old connection make the health probe (`GET /health`) return a response. The `python server.py` direct-launch path hits this every time.

**Fix:** Always use `./ctl.sh restart`, which:
1. Detects and removes stale PID files (`[ctl] Removed stale PID file: ...`)
2. Sends SIGTERM, waits, then SIGKILL if needed
3. Starts fresh via `bootstrap.py --no-browser`

**Do NOT** try to work around this with `fuser -k` + `python server.py` — it will fail again on the next restart cycle.

## Other ctl.sh commands

```bash
./ctl.sh start              # start (writes PID to ~/.hermes/webui.pid)
./ctl.sh stop               # graceful stop (SIGTERM → SIGKILL)
./ctl.sh status             # PID, uptime, bound host/port, log path
./ctl.sh logs --lines 100   # tail ~/.hermes/webui.log
```

## Verification

```bash
curl -s http://127.0.0.1:8787/health
```

Expected response includes `"status": "ok"`.

## Key paths

| Item | Path |
|------|------|
| WebUI source | `~/hermes-agent/hermes-webui/` |
| Start script | `~/hermes-agent/hermes-webui/ctl.sh` |
| Server entry | `~/hermes-agent/hermes-webui/server.py` |
| PID file | `~/.hermes/webui.pid` (i.e. `$HERMES_HOME/webui.pid`) |
| Log | `~/.hermes/webui.log` |
| State dir | `~/.hermes/webui/` |
| Default bind | `127.0.0.1:8787` |
| Config | `~/.hermes/config.yaml` |
