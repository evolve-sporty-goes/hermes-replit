---
name: replit
description: "Use when configuring, debugging, or deploying projects on Replit. Covers .replit TOML config, Nix channels, workflows, secrets, deployment, and the Replit CLI/agent."
version: 1.0.0
author: Hermes Agent
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [replit, .replit, Nix, replit-cli, deployment, repl]
    related_skills: [hermes-agent, python-debug.py]
---

# Replit Platform Configuration

## Overview

Replit is a cloud IDE + hosting platform. Project behavior is controlled by a `.replit` TOML file in the repo root, plus optional `.replit/workflows` (TOML) for multi-step startup. Replit runs inside a Nix-managed container — `modules` select language runtimes, `[nix]` controls Nix packages and channel, and `run` / `entrypoint` control what executes on startup.

This skill covers the `.replit` config format, gotchas (Nix channel requirement, bash not sh, secrets handling), and common workflow patterns.

## User Style Notes (when working over CLI on this repo)

- Prefer plain-text output, not markdown tables or emoji. Terminal-renderable.
- Lead with the change or answer, no preamble. Be direct.
- Prefer bash over Python for utility scripts.
- **Keep scripts SHORT and crisp.** Merge export lines, use short-circuit `||`/`&&`, prefer full paths over `cd`, drop comments and blank lines. Target <30 lines for hermes.sh-style bootstraps.
- When editing shell scripts the user explicitly said "Make script short" / "Make script short" — compress aggressively (collapse redundant exports, inline `&&` chains, use `[ -d dir ] ||` instead of `if [ ! -d ]; then ... fi`).
- **Scripts must be renamed `hermes.sh`** (not `install.sh`) — user renamed per-project convention. The `.replit` workflow references `bash hermes.sh`.
- User values persistent auto-commit (local) without unattended push.
- When a push is requested via `.pat`, just run it — no questions about auth or identity. The `.pat` token at repo root is the canonical credential.
- **When user says "commit and push changes use .pat"**: add all changes, commit with a descriptive message, push using inline token from `.pat` in the URL: `git push "https://$(cat .pat | tr -d '\n')@github.com/<owner>/<repo>.git" main`.

## When to Use

Load when the user asks to:
- Configure `.replit` for a new project
- Add a startup workflow / run command to Replit
- Debug a Replit build or deployment
- Set up secrets/env vars on Replit
- Deploy from Replit (static, Always-on, autoscale)
- Ask about Replit-specific behavior (Nix, file persistence, networking)

## `.replit` Config Format (TOML)

Minimal structure:

```toml
modules = ["nodejs-24", "python-3.12"]

[agent]
expertMode = true

run = "bash install.sh"

[nix]
channel = "stable-24_05"
```

### Key Fields

| Field | Section | Required | Notes |
|-------|---------|----------|-------|
| `modules` | top-level | yes | Language runtimes. E.g. `"nodejs-24"`, `"python-3.12"`, `"rust-stable"` |
| `run` | top-level | no | Shell command executed on startup. Runs after Nix setup. |
| `entrypoint` | top-level | no | Path to a script that runs before `run`. Use for multi-step startup. |
| `expertMode` | `[agent]` | no | Enables agent features. Set `true` for AI pairing. |
| `channel` | `[nix]` | yes if `[nix]` present | Nix channel. `"stable-24_05"` is current as of 2026. |
| `packages` | `[nix]` | no | Nix packages to install. E.g. `["tor", "ffmpeg"]` |

### Critical Gotcha: Nix Channel

If you include an empty `[nix]` section without `channel`, Replit errors on startup. Always set `channel` when using `[nix]`:

```toml
# WRONG — errors on spin-up
[nix]
packages = ["tor"]

# CORRECT
[nix]
channel = "stable-24_05"
packages = ["tor"]
```

If you don't need Nix packages, omit `[nix]` entirely — don't leave it empty.

### `run` vs `entrypoint`

- `entrypoint` — runs first, used for setup scripts (install deps, clone repos, configure env)
- `run` — runs after entrypoint, used for the main process (server, watcher, CLI)

Both accept shell strings. Use `bash script.sh` not `sh script.sh` — Replit's default `sh` is dash, not bash, and bash-specific syntax (arrays, `[[ ]]`, `source`) will fail.

### Multi-Step Workflows

For complex startup sequences, chain commands in `run`:

```toml
run = "bash setup.sh && bash start.sh"
```

Or use `entrypoint` for setup and `run` for the main process:

```toml
entrypoint = "bash install.sh"
run = "python app.py"
```

Note: `hermes.sh` must be executable (`chmod +x hermes.sh`) and committed to the repo.

## Secrets & Environment Variables

Replit provides two mechanisms:

1. **Secrets tab** (Replit UI) — stored encrypted, injected as env vars at runtime. Use for API keys, tokens. Access via `$SECRET_NAME` in scripts.
2. **`.env` file** — committed (non-secret values only). Never commit real secrets.

In scripts, reference secrets as normal env vars:

```bash
curl -H "Authorization: Bearer $OPENAI_API_KEY" https://api.openai.com/v1/...
```

### Private repo for secrets (recommended for full .env files)

When the user wants `.env` backed up to GitHub but not committed to the project repo, use a separate private repo (e.g. `hermes-secrets`) and pull `.env` at entrypoint time. See `references/private-repo-secrets.md` for the full pattern (one-time push, pull script, auth handling, comparison with git-crypt/SOPS).

### Bidirectional sync pattern (2026-06)

For secrets that change at runtime (e.g. tokens rotated by the agent, `.pat` files updated by scripts), a single sync script detects divergence in both directions and acts accordingly. The token is read from `.pat` at the repo root — no argument or env var needed.

```bash
#!/bin/bash
# sync-secrets.sh — bidirectional .env/.pat sync with hermes-secrets
# Just run: ./sync-secrets.sh  (reads token from .pat automatically)
set -euo pipefail
TOKEN=*** /home/runner/workspace/.pat)
SECRETS_REPO="https://github.com/<owner>/hermes-secrets.git"
LOCAL_ENV="/home/runner/workspace/.hermes_data/.env"
LOCAL_PAT="/home/runner/workspace/.pat"
[ -z "$TOKEN" ] && { echo "ERROR: .pat empty"; exit 1; }
TMPDIR=$(mktemp -d); trap "rm -rf $TMPDIR" EXIT
ASKPASS="$TMPDIR/git-askpass"
printf '#!/bin/bash\necho %s\n' "$TOKEN" > "$ASKPASS"
chmod +x "$ASKPASS"; export GIT_ASKPASS="$ASKPASS"
git clone --depth 1 --branch main "$SECRETS_REPO" "$TMPDIR/s" 2>/dev/null || { echo "ERROR: clone failed"; exit 1; }
cd "$TMPDIR/s"
LOCAL_HEAD="$(git rev-parse HEAD 2>/dev/null || echo '')"
git fetch --unshallow origin main 2>/dev/null || true
git checkout main 2>/dev/null || true
REMOTE_HEAD="$(git rev-parse origin/main 2>/dev/null || echo '')"
if [ -n "$REMOTE_HEAD" ] && [ "$LOCAL_HEAD" != "$REMOTE_HEAD" ]; then
    echo "Remote ahead — pulling..."
    git pull origin main 2>/dev/null || true
    [ -f .env ] && cp .env "$LOCAL_ENV" && echo "OK: pulled .env"
    [ -f .pat ] && cp .pat "$LOCAL_PAT" && echo "OK: pulled .pat"
fi
git config user.email "hermes@replit"; git config user.name "hermes-replit"
changed=0
[ -f "$LOCAL_ENV" ] && ! diff -q "$LOCAL_ENV" .env >/dev/null 2>&1 && { cp "$LOCAL_ENV" .env; git add .env; changed=1; }
[ -f "$LOCAL_PAT" ] && ! diff -q "$LOCAL_PAT" .pat >/dev/null 2>&1 && { cp "$LOCAL_PAT" .pat; git add .pat; changed=1; }
if [ "$changed" -eq 1 ]; then
    git commit -m "auto: update secrets $(date -u +%Y-%m-%dT%H:%M:%SZ)" >/dev/null 2>&1
    git push origin main 2>/dev/null && echo "OK: pushed" || echo "WARN: push failed"
else
    echo "OK: no changes"
fi
```

Key design decisions:
- Token read automatically from `.pat` — user just runs `./sync-secrets.sh`
- Uses `git fetch --unshallow` + `rev-parse` to detect divergence (shallow clones have no merge-base)
- Uses `diff -q` for content comparison (avoids spurious commits when only timestamps change)
- Only commits/pushes when actual content differs (no empty commits)
- Handles multiple secret files (.env AND .pat) in one run
- Wraps push in `if ...; then` so push failure doesn't kill the script (retries next run)
- No arguments, no env vars — fully self-contained

Run on a schedule (cron or watcher loop) for continuous sync. See `references/private-repo-secrets.md` for the full sync script template.

## File Persistence

Replit's `/home/runner/workspace` persists across deploys. Everything outside it (`/tmp`, `/root`, `/nix` store) is ephemeral. Write logs, databases, and generated files to `~/workspace`.

## Deployment

Replit supports three deployment targets:

| Type | Use case | Config |
|------|----------|--------|
| **Static** | Frontend apps (HTML/CSS/JS, built SPA) | Set `run` to a static server or build command |
| **Always-on** | Bots, watchers, long-running scripts | Enable in deployment settings |
| **Autoscale** | APIs, web servers with traffic | Configure min/max instances |

Deploy from the Replit UI or via `replit deploy` CLI.

## Common Pitfalls

1. **Empty `[nix]` section without `channel`.** Always set `channel = "stable-24_05"` or omit `[nix]` entirely.

2. **Using `sh` instead of `bash`.** Replit's default shell is dash. Use `bash install.sh` in `run`/`entrypoint`, and write scripts with bash syntax.

3. **Script not executable.** `run = "bash install.sh"` works, but `run = "./install.sh"` requires `chmod +x install.sh` first.

4. **Writing outside `~/workspace`.** Files outside the workspace directory are lost on redeploy. Always write persistent data to `~/workspace`.

5. **Forgetting `modules`.** Without `modules`, Replit has no language runtime installed. Your `run` command will fail with "command not found".

6. **Assuming `pip` / `npm` are globally available.** They are available via `modules`, but the binary names differ. Use `python -m pip` or `npx` for reliability.

7. **Nix package names.** Nixpkgs names differ from apt/pip (e.g. `pkgs.ffmpeg`, not `ffmpeg`). Search search.nixos.org for exact package names.

8. **Browser automation on Nix.** Playwright's own browser binaries are NOT installed by default on Nix/Replit. Use the system Chromium binary via `executable_path`:
   ```python
   from playwright.sync_api import sync_playwright
   browser = p.chromium.launch(
       executable_path="/nix/store/<hash>-chromium-<version>/bin/chromium"
   )
   ```
   Find the path with `which chromium` or `ls /nix/store/ | grep chromium`. This is also the workaround for Camoufox crashes on specific sites (proton.me).

## Git Push Authentication

Replit injects a custom `replit-git-askpass` credential helper that intercepts all git credential prompts. This means HTTPS push fails non-interactively unless a PAT is available. The full landscape of working options (and why common workarounds fail on Replit) is documented in `references/github-push-auth-on-replit.md`.

| Approach | Works on Replit? |
|----------|-----------------|
| Plain `git://` remote (e.g. gitsafe-backup) | ✅ yes — no auth needed |
| Repl Secrets tab + `credential.helper store` | ✅ yes |
| SSH switch (`git remote set-url ... git@...`) | ✅ yes |
| `gh` CLI pre-authenticated | ✅ yes |
| `GIT_ASKPASS` env override (executable script that echoes token) | ✅ yes |
| Inline token in push URL (`https://<token>@github.com/...`) | ✅ yes |
| Pushing from local machine | ✅ yes (remove watcher) |

> **Setting `GIT_ASKPASS` DOES override `replit-git-askpass`** — earlier docs claimed it was always intercepted, but practice confirms it works when set to an executable script that echoes the token.

### Inline token push (shortest method, confirmed 2026-06)

The shortest working option — embed the token directly in the URL. Useful when you want a single `git push` line without temp files or `chmod`:

```bash
git push "https://$(cat .pat | tr -d '\n')@github.com/<owner>/<repo>.git" main
```

One-shot with remote slug auto-derived:
```bash
git push "https://$(cat .pat | tr -d '\n')@github.com/$(git remote get-url origin | sed 's/.*github.com[:/]//;s/\.git$//').git" main
```

Or chain commit + push (the "commit and push" user request pattern):
```bash
git add <files> && git commit -m "descriptive message" && git push "https://$(cat .pat | tr -d '\n')@github.com/evolve-sporty-goes/hermes-replit.git" main
```

This avoids the `GIT_ASKPASS` temp script entirely but exposes the token in the command line (visible in `ps`/shell history). Tradeoff: brevity vs. token exposure in process list.

You MUST override `replit-git-askpass` for ALL HTTPS push operations on Replit — a plain `git push` will always fail with `could not read Username for 'https://github.com'`. There is no "try default first" — go straight to `GIT_ASKPASS`. Non-negotiable workflow:

```bash
TOKEN=$(cat .pat | tr -d '\n') && \
  ASKPASS=$(mktemp) && \
  printf '#!/bin/bash\necho %s\n' "$TOKEN" > "$ASKPASS" && \
  chmod +x "$ASKPASS" && \
  GIT_ASKPASS="$ASKPASS" git push origin main && \
  rm -f "$ASKPASS"
```

Key points:
- **Always use this for HTTPS push.** Never attempt plain `git push` — it will always fail.
- The askpass script must be executable (`chmod +x`)
- The token must have no trailing newline (use `tr -d '\n'` if `.pat` has trailing newline)
- Clean up the askpass script immediately after push (`rm -f`)
- Works for both push and pull (clone) operations
- The `.pat` file pattern: user stores raw token in `.pat` file at repo root, reads from scripts, never embeds in code

> **Auto-commit + push pattern (common on this repo):** When the user says "commit and push", combine commit and push in one command chain so a failed push doesn't lose the commit but the commit still happens regardless. Use this pattern:

```bash
git add <files> && \
  git commit -m "descriptive message" && \
  TOKEN=$(cat .pat | tr -d '\n') && \
  ASKPASS=$(mktemp) && \
  printf '#!/bin/bash\necho %s\n' "$TOKEN" > "$ASKPASS" && \
  chmod +x "$ASKPASS" && \
  GIT_ASKPASS="$ASKPASS" git push origin main; \
  rm -f "$ASKPASS"
```

Note: semicolon before `rm` (not `&&`) so cleanup always runs.

> **Watch out:** An auto-push watcher (`git add && git commit && git push`) will fail infinitely if auth is absent. Either use Replit Secrets or push from a machine with credentials. Wrap `git push` inside `if git commit ...; then` so a failed push doesn't lose the commit or kill the cooldown.

### Handling divergent branches before push

When local and origin have diverged (ahead N, behind M), rebase before pushing:

1. `git stash` — save uncommitted work
2. `git pull origin main --rebase` — replay local commits on top of remote
3. Resolve conflicts if any:
   - `.hermes_data/logs/agent.log` and `errors.log` — safe to resolve with `git checkout --ours` since these are operational noise, not user work
   - `git add <resolved-files> && git rebase --continue`
4. `git stash pop` — restore work (may conflict with rebased state; resolve manually)
5. Push with temp askpass workaround above

If stash pop conflicts with rebased log files, `git checkout --ours .hermes_data/logs/...` to accept the rebased versions (they'll be regenerated immediately).

## Managing XDG Environment Variables on Replit

Replit generates environment files at `/home/runner/workspace/.cache/replit/env/` that set `XDG_CACHE_HOME`, `XDG_CONFIG_HOME`, and `XDG_DATA_HOME`. These control where tools following the XDG Base Directory Standard write their files.

**Key files:**
- `/home/runner/workspace/.cache/replit/env/latest` — shell `declare` statements (sourced by login shells)
- `/home/runner/workspace/.cache/replit/env/latest.json` — JSON blob (used by Replit runtime)

**Current defaults:**
```
XDG_CACHE_HOME=/home/runner/workspace/.cache
XDG_CONFIG_HOME=/home/runner/workspace/.config
XDG_DATA_HOME=/home/runner/workspace/.local/share
```

**Why this matters:** The workspace directory is the largest consumer of disk when tools cache inside it. Redirecting `XDG_CACHE_HOME` to `/home/runner/.cache` moves caches (camoufox, uv, pip, etc.) out of the workspace, reducing its footprint. This is safe because `/home/runner` is on the same 32G overlay filesystem and persists.

**Discovery flow — finding where an env var is set:**

When a tool behaves unexpectedly and you suspect an env var is overriding defaults:

1. Check current value: `echo $XDG_CACHE_HOME`
2. Find which file sets it: `grep -rl "VAR_NAME" /home/runner/workspace/.cache/replit/env/ 2>/dev/null`
3. Replit generates two formats:
   - `latest` — shell `declare -gx VAR=value` statements (sourced by login shells)
   - `latest.json` — single JSON line with `{"environment": {"VAR": "value", ...}}` (used by Replit runtime)
4. Both files must be updated for the change to be comprehensive.

**To redirect a tool's cache out of workspace:**

1. Move the existing cache directory to the new location:
   ```bash
   mkdir -p /home/runner/.cache
   mv /home/runner/workspace/.cache/<tool> /home/runner/.cache/<tool>
   ```

2. Update both env files:
   ```bash
   sed -i 's|XDG_CACHE_HOME=/home/runner/workspace/.cache|XDG_CACHE_HOME=/home/runner/.cache|' \
     /home/runner/workspace/.cache/replit/env/latest
   sed -i 's|XDG_CACHE_HOME":"/home/runner/workspace/.cache"|XDG_CACHE_HOME":"/home/runner/.cache"|' \
     /home/runner/workspace/.cache/replit/env/latest.json
   ```

3. Export in current session:
   ```bash
   export XDG_CACHE_HOME=/home/runner/.cache
   ```

The change takes effect for new shell sessions automatically. The current session needs the explicit `export`.

**Note:** Do NOT change `XDG_DATA_HOME` — the workspace `.local/share` is where Replit expects user data. Only redirect `XDG_CACHE_HOME` (caches) and optionally `XDG_CONFIG_HOME` if config files are bloating the workspace.

See `references/disk-space-investigation.md` for the full triage command set, common space hogs, and the disk layout reference.

## Making `hermes` available in fresh shells

Fresh Replit shells don't activate the venv — `PATH` won't include `~/hermes-agent/.venv/bin`, so `hermes` returns "command not found". A symlink does NOT work (the target depends on venv PATH entries). Fix with a wrapper script:

```bash
mkdir -p ~/.local/bin
cat > ~/.local/bin/hermes << 'EOF'
#!/bin/bash
exec /home/runner/hermes-agent/.venv/bin/python -m hermes_cli.main "$@"
EOF
chmod +x ~/.local/bin/hermes
```

After this, `hermes` (bare command) works in any shell. `~/.local/bin` is on Replit's default PATH. Python venv binaries have their own deps baked in — no activation needed.

**Important:** `.pythonlibs` is a real persistent directory in workspace (NOT symlinked). Scripts and wrapper heredocs should reference the workspace path (`$HOME/workspace/.pythonlibs/bin`) because that's where the packages actually live. Only `.cache`, `.local`, `.config` are symlinked to ephemeral `~/`.

**Fresh shell PATH fix:** Replit's `.bashrc` is read-only (Nix store) and does NOT source `.profile`. The only user-writable file sourced is `~/.config/bashrc`. Create it:
```bash
cat > ~/.config/bashrc << 'EOF'
[ -d "$HOME/.local/bin" ] && PATH="$HOME/.local/bin:$PATH"
[ -d "$HOME/workspace/.pythonlibs/bin" ] && PATH="$HOME/workspace/.pythonlibs/bin:$PATH"
export PATH
EOF
```
Without this, `hermes` in `.pythonlibs/bin/` won't be found in a fresh terminal.

**Pitfall: `.profile` does NOT work for Replit terminals.** Replit terminals are non-login interactive shells — they read `.bashrc`, not `.profile`. Adding PATH to `.profile` alone will NOT fix "command not found". Always use `~/.config/bashrc`.

**Wrapper script should NOT export PATH.** The wrapper inherits PATH from the shell (which sources `~/.config/bashrc`). Duplicating `export PATH=...` is redundant. The wrapper only needs: `export HERMES_HOME`, `mkdir -p`, `ln -s`, and `exec python -m hermes_cli.main`.

## Verification Checklist

- [ ] `.replit` is valid TOML (parse with `python -c "import tomllib; tomllib.load(open('.replit', 'rb'))"`)
- [ ] If `[nix]` is present, `channel` is set
- [ ] `run` / `entrypoint` scripts exist in repo and are committed
- [ ] Scripts use bash, not sh
- [ ] Persistent files written to `~/workspace`
- [ ] Secrets referenced as env vars, not hardcoded

## Templates

- `templates/replit-minimal.toml` — minimal working `.replit` for a Python project with `install.sh`. Copy and modify.
- `templates/install.sh` — parameterized bootstrap script (clone hermes-agent + webui, venv, wrapper, services). Environment variables override defaults.

## install.sh/hermes.sh Bootstrap Pattern

Projects on Replit typically use a single `hermes.sh` (historically `install.sh`) at repo root as the Replit entrypoint. This script reads `$HOME/workspace/.pat` for auth, clones the main repo into `~/hermes-agent`, creates a venv, builds a `~/hermes` wrapper that points into the workspace's `.hermes_data/`, and starts background services (hermes-webui, sync cron, VNC).

**Critical ordering in hermes.sh:**
1. Unset XDG vars + export PATH/env
2. Ensure `~/.config/bashrc` has PATH entries
3. Install uv (if missing)
4. Clone/pull hermes-agent + create venv + `uv pip install -e ".[all]"`
5. Symlink loop (AFTER venv setup — prevents `rm -rf` from deleting `.venv`)
6. Create wrapper script (minimal — no PATH export, just HERMES_HOME + exec)
7. Start background services (script.sh, sync.sh)
8. Launch hermes

**Never run script.sh/sync.sh before setup completes** — they may depend on tools not yet installed.

A complete working example is in `references/install-sh-bootstrap.md`.

## Hermes WebUI Lifecycle

The Hermes WebUI (`~/hermes-agent/hermes-webui/`) is a separate git repo managed via `ctl.sh`. Always use `./ctl.sh restart` to restart it — never `python server.py` directly. The canonical restart procedure and the "already serving" stale-lock pitfall are documented in `references/hermes-webui-restart.md`.

## One-Shot Recipes

### Bootstrap a Python project with install script

See `templates/replit-minimal.toml` — copy to repo root as `.replit`.

### Node.js project with build step

```toml
modules = ["nodejs-24"]

run = "npm install && npm run build && npm start"

[nix]
channel = "stable-24_05"
```

### Multi-step with entrypoint

```toml
modules = ["python-3.12"]

entrypoint = "bash setup.sh"
run = "python main.py"

[nix]
channel = "stable-24_05"
```

### Firecrawl CLI

Pre-installed on Replit via npm (v1.19.19 as of 2026-06). No install needed — just `firecrawl <command>`. API key lives in `.hermes_data/.env` (not repo-root `.env`). Login with:

    source .hermes_data/.env && firecrawl login --api-key "$FIRECRAWL_API_KEY"

See `references/firecrawl-cli.md` for full setup, commands, and pitfalls.
