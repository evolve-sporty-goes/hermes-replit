# Hermes `terminal` Tool Backgrounding

The Hermes `terminal` tool (used by AI agents in WebUI and CLI) has specific rules for background processes that differ from a normal shell.

## The Rule

**Foreground mode** (`background=false`, the default) rejects any command containing shell backgrounding operators:
- `&` (background)
- `nohup ... &`
- `setsid ...`
- `disown`
- Subshells meant to background: `(cmd &)`

If you include these, the tool returns an error like:
```
"Foreground command uses '&' backgrounding. Use terminal(background=true) for long-lived processes..."
```

## The Fix

Use `background=true` parameter:

```
terminal(command="python server.py", background=true)
```

This returns a session_id (e.g., `proc_e8c8ed3f4cc8`). Manage the process with the `process` tool:

| Action | Purpose |
|--------|---------|
| `process(action="poll", session_id="...")` | Check status + get recent output |
| `process(action="wait", session_id="...", timeout=30)` | Block until done or timeout |
| `process(action="kill", session_id="...")` | Terminate the process |
| `process(action="log", session_id="...")` | Get full output with pagination |

## `notify_on_complete` Flag

- **Long-lived processes** (servers, watchers, daemons): `background=true` WITHOUT `notify_on_complete` — runs silently, you won't be notified when it exits.
- **Bounded tasks** (tests, builds, deploys, batch jobs): `background=true, notify_on_complete=true` — you get one notification when it finishes.

## Common Trap: Retry Loop

The most common failure pattern is retrying the same failing command with `&` multiple times:

```
# This FAILS 3 times in a row before the agent realizes the pattern is wrong:
terminal(command="cd /app && python server.py &")  # FAIL
terminal(command="cd /app && python server.py &")  # FAIL  
terminal(command="cd /app && python server.py &")  # FAIL
terminal(command="cd /app && python server.py", background=true)  # CORRECT
```

**If you see `&` in your command and it returned an error mentioning "backgrounding", switch to `background=true` immediately — do not retry the same pattern.**

## Downstream Implication for This Environment

On Replit NixOS, even with `background=true`, the process will still die when the Replit container restarts or the agent session ends. For truly persistent processes across restarts, use:
- Replit workflows (`.replit`)
- Cron jobs (`cronjob` tool)
- `nohup` inside a `background=true` command (e.g., `command="nohup python server.py > /tmp/server.log 2>&1"`)
