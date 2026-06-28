---
name: replit-nixos
description: Use when working in a Replit NixOS environment. Knows storage model, persistence rules, available packages, and platform limitations.
version: 1.4.0
author: Hermes Agent
license: MIT
platforms: [linux]
metadata:
  hermes:
    tags: [replit, nixos, environment, storage, setup]
    related_skills: []
---

# Replit NixOS Environment Skill

Relevant reference: `references/filesystem-layout.md` (full `df -h` partition table, largest writable partition, no-root/no-sudo confirmation).
Relevant reference: `references/storage-investigation.md` (session disk usage snapshot, push workaround, binary wrapper pattern).
Relevant reference: `references/reset-recovery.md` (what survives a reset, recovery sequence, cache strategy).
Relevant reference: `references/ephemeral-symlinks.md` (symlink pattern to keep .cache/.pythonlibs/.local/.config out of workspace).
Relevant reference: `references/storage-symlinks.md` (full workspace lean strategy, reverse pattern, post-reset recovery).
Relevant reference: `references/storage-write-limits.md` (empirical write speed/cap tests per mount, safe large-write pattern, no-root confirmation).
Relevant reference: `references/terminal-tool-backgrounding.md` (Hermes terminal tool rejects `&` in foreground mode; use `background=true` + `process` tool).
Relevant reference: `references/hermes-sh-canonical.md` (setup script ordering, .pat push pattern, large file cleanup).
Relevant reference: `references/replit-shell-init.md` (why .bashrc is read-only, .config/bashrc as the only writable shell init, PATH chain).
Relevant reference: `references/docker-on-replit.md` (Docker is available, IPv6 nginx failure workaround, port mapping, example containers).
Relevant reference: `references/xrdp-on-replit.md` (xrdp runs natively via Nix, log path fix, auth, limitations).
Relevant reference: `references/vpn-containers-on-replit.md` (gluetun/WireGuard/OpenVPN fail — netlink blocked, no /dev/net/tun).

## Overview

This environment runs on Replit's NixOS-based container. Understanding its storage model, available packages, and limitations prevents wasted effort and data loss.

## When to Use

- Any task in this workspace (it's always a Replit NixOS env)
- Before installing packages or writing to disk
- When debugging "command not found" or missing dependency issues
- When deciding where to store files (persistent vs ephemeral)
- When setting up services or background processes

## Environment Facts

| Property | Value |
|---|---|
| **OS** | NixOS kernel, Ubuntu 24.04 userspace |
| **CPU** | Intel Xeon Platinum 8581C @ 2.30GHz (2 cores) |
| **RAM** | 7.8 GB (~5.2 GB available) |
| **Persistent disk** | `/mnt/nix` (256 GB, Nix store) |
| **No sudo / no root** | `sudo` unavailable, `/root` inaccessible, runs as unprivileged `runner` |
| **Largest writable partition** | `/home/runner/workspace` — 256GB total, ~252GB free (persistent), per-write cap ~48GB |
| **Ephemeral scratch** | `/mnt/scratch` — ~3GB real (30GB in df, shares device), writable |
## Storage Model

### Persistent (survives restart)
- `/home/runner/workspace/` — git-tracked workspace, the ONLY persistent user-writable directory
- `/mnt/nix/` — Nix store (writable but Nix-managed; do NOT write arbitrary files here)
- `~/.local/bin/` — persistent user binaries (on PATH)

### Large scratch (ephemeral, not guaranteed to survive restart)
- `/mnt/scratch/` — 30GB shown by `df`, but **real limit ~3GB** (shares `/dev/vdc` with `/home/runner`). Confirmed writable (86-138 MB/s). Use for small temporary files only. Do NOT rely on for persistence.
- `/mnt/snix/` — 1.8TB total, 129GB free per `df`, but **READ-ONLY** — cannot write despite reported space. Do not use.

### Ephemeral (wiped on restart)
- `/tmp/`, `/var/`, `/home/runner/.config/`
- `/home/runner/.cache/` — default cache location (unset `XDG_CACHE_HOME` to keep it here)
- `/home/runner/.local/` — symlinked into workspace but original is ephemeral
- Everything outside `/home/runner/workspace/`

### Persistent (stays in workspace)
- `/home/runner/workspace/.hermes_data/` — Hermes state DB, sessions, skills
- `/home/runner/workspace/.git/` — git history

**Rule:** All state, configs, credentials, data live under `/home/runner/workspace/` or `.hermes_data/`. **Exception:** `.cache` and `.local` are symlinked to ephemeral `~/` to save workspace storage. `.pythonlibs` and `.config` stay as real persistent dirs in workspace (Replit auto-installs Python/Node into them; symlinking breaks Replit's package management).

**PATH conventions:** Scripts in `hermes.sh` and the `hermes` wrapper should reference the **workspace symlink paths** (`$HOME/workspace/.pythonlibs/bin`, `$HOME/workspace/.local/bin`) because the symlinks resolve to the real ephemeral dirs. The symlink loop at the top of `hermes.sh` ensures they exist before any PATH-dependent command runs. This way, both the workspace path and the `~/` path resolve to the same location.

**Cache strategy:** By default Replit sets `XDG_CACHE_HOME`, `XDG_CONFIG_HOME`, and `XDG_DATA_HOME` to workspace paths (persistent), which wastes storage. To keep ephemeral data out of workspace, unset all three and symlink ephemeral dirs to `~/`:

```bash
unset XDG_CACHE_HOME XDG_CONFIG_HOME XDG_DATA_HOME
for d in .cache .local; do
  [ -L "$HOME/workspace/$d" ] && continue  # idempotent: skip if already symlinked
  [ -e "$HOME/$d" ] || mkdir -p "$HOME/$d"
  [ -e "$HOME/workspace/$d" ] && mv "$HOME/workspace/$d"/* "$HOME/$d/" 2>/dev/null || true  # migrate existing
  rm -rf "$HOME/workspace/$d" && ln -sf "$HOME/$d" "$HOME/workspace/$d"
done
```

**`.pythonlibs` and `.config` are NOT in the symlink loop** — Replit's `.replit` config auto-installs Python into `.pythonlibs` and Node/config into `.config` at startup. Symlinking these breaks Replit's package manager. They stay as real persistent dirs in workspace.

This makes BOTH paths (`~/.cache` and `$HOME/workspace/.cache`) resolve to the same ephemeral `~/` directory. Tools that respect `XDG_CACHE_HOME` and tools that hardcode `~/.cache` both write ephemeral.

**Workspace storage budget:** After symlinking `.cache`/`.local`/`.config`, workspace should be ~600 MB (`.hermes_data` + `.git` + `.pythonlibs` + working files). Check with `du -sh ~/workspace/`.

## Docker

Docker **is available** on Replit (v27.5.1, included in Nix path). The daemon runs, `docker info` works, and containers can be created with `overlay2` storage.

**Key constraints:**
- No IPv6 in containers — nginx and other services that default to `[::]:PORT` will fail with `Address family not supported by protocol`. Fix: pass `-e DISABLE_IPV6=true` to linuxserver images, or override the service config to bind `127.0.0.1` / `0.0.0.0` only.
- Ports must be declared in `.replit` under `[[ports]]` with `localPort`, `externalPort`, and `exposeLocalhost = true` to be accessible externally.
- `--restart unless-stopped` works (Docker daemon persists across Replit restarts, but not container state if the daemon restarts).
- `--shm-size` should be set (e.g., `1g`–`2g`) for browser containers.
- Config/data volumes should be under `~/workspace/` for persistence.
- **VPN containers (gluetun, WireGuard, OpenVPN) do NOT work** — netlink routing operations are blocked by the kernel. See `references/vpn-containers-on-replit.md`.

**Example — linuxserver/firefox:**
```bash
docker run -d \
  --name firefox \
  -e PUID=1000 -e PGID=1000 -e TZ=Etc/UTC \
  -e DISABLE_IPV6=true \
  -p 3000:3000 -p 3001:3001 \
  -v ~/workspace/firefox-config:/config \
  --shm-size 1g --restart unless-stopped \
  lscr.io/linuxserver/firefox:latest
```

Full reference: `references/docker-on-replit.md`

## xrdp (Native RDP Server)

xrdp **runs natively** on Replit via Nix packages (v0.9.25.1). No Docker needed.

**Critical:** xrdp fails immediately if it can't write logs. Copy configs to workspace first:
```bash
mkdir -p ~/workspace/xrdp-config
cp /nix/store/*-xrdp-*/etc/xrdp/*.ini ~/workspace/xrdp-config/
sed -i 's|LogFile=xrdp.log|LogFile=/home/runner/workspace/xrdp-config/xrdp.log|' ~/workspace/xrdp-config/xrdp.ini
sed -i 's|EnableSyslog=true|EnableSyslog=false|' ~/workspace/xrdp-config/xrdp.ini
```

**Run:**
```bash
xrdp-sesman -c ~/workspace/xrdp-config/sesman.ini &
xrdp --nodaemon -c ~/workspace/xrdp-config/xrdp.ini &
```

- Listens on port **3389** (standard RDP)
- Add `localPort = 3389` to `.replit` for external access
- No systemd, no GPU — software rendering only
- PAM auth works for `runner` user

Full reference: `references/xrdp-on-replit.md`

## Package Management

No `apt`, `sudo`, or traditional package managers. Packages come from:

1. **Nix** — declared in `.replit` under `[nix]packages`. Rebuild to add.
2. **pip/uv** — Python packages install to `workspace/.pythonlibs/bin` (symlinked to ephemeral `~/`; rebuilt by `hermes.sh` on reset)
3. **npm** — global installs to `node_modules/.bin` (ephemeral)
4. **Pre-installed binaries** — see `.replit` nix packages list
5. **Docker** — pull and run any image (see Docker section above)

### Key pre-installed tools
- Chromium 138, Ollama 0.9.5, Tor 0.4.8
- Python 3.12, Node 24, Bun 1.3.6
- git, uv, npx, pnpm, yarn
- Xvnc, fluxbox, noVNC (desktop/VNC)
- tigervnc, xterm, xdotool

## PATH Essentials

Replit auto-sets these env vars on shell startup. Do NOT prepend `$HOME/workspace` to PATH — it already includes `.local/bin` and `.pythonlibs/bin`.

- `~/.local/bin/` — persistent user binaries (on PATH). Use for wrappers.
- `~/.pythonlibs/bin/` — pip/uv installs (ephemeral, on PATH via Replit env)
- `/mnt/nix/store/...` — Nix packages (on PATH via Nix profile)

**To make a command available permanently:** place wrapper/script in `~/.local/bin/`

**Making `hermes` available as a command:** After `hermes-agent` is installed, `hermes` won't be on PATH in a fresh shell. Two steps required:

1. **Create the wrapper** in `~/.local/bin/hermes` (always on PATH):
```bash
mkdir -p ~/.local/bin
cat > ~/.local/bin/hermes << 'EOF'
#!/bin/bash
exec /home/runner/hermes-agent/.venv/bin/python -m hermes_cli.main "$@"
EOF
chmod +x ~/.local/bin/hermes
```

2. **Add `.pythonlibs/bin` to `~/.config/bashrc`** — Replit's `.bashrc` is read-only (Nix store) and does NOT source `.profile`. It only sources `~/.config/bashrc` if it exists. Without this, `hermes` (installed via `hermes.sh` into `.pythonlibs/bin/`) won't be found in a fresh terminal:
```bash
cat > ~/.config/bashrc << 'EOF'
[ -d "$HOME/.local/bin" ] && PATH="$HOME/.local/bin:$PATH"
[ -d "$HOME/workspace/.pythonlibs/bin" ] && PATH="$HOME/workspace/.pythonlibs/bin:$PATH"
export PATH
EOF
```
**Do NOT rely on `.profile` alone** — it's only sourced by login shells, and Replit terminals are non-login interactive shells that read `.bashrc` instead.

**Hermes WebUI:** The web interface runs on port 8787 via `hermes-webui/server.py`. In `hermes.sh`, the webui is cloned and started:
```bash
[ -d "$HOME/hermes-agent/hermes-webui" ] || git clone https://github.com/nesquena/hermes-webui.git "$HOME/hermes-agent/hermes-webui"
nohup "$HOME/hermes-agent/.venv/bin/python" "$HOME/hermes-agent/hermes-webui/server.py" >/tmp/hermes-webui.log 2>&1 &
```
The `.replit` config maps port 8787 → external port 80 for browser access.

**To create a working binary wrapper (e.g., `hermes`):** call the venv Python directly via `exec`, not a symlink. A symlink to `venv/bin/hermes` will fail because the venv is not activated in a fresh shell:
```bash
cat > ~/.local/bin/hermes << 'EOF'
#!/bin/bash
exec /path/to/venv/bin/python -m hermes_cli.main "$@"
EOF
chmod +x ~/.local/bin/hermes
```

## Git & Auth

- HTTPS push fails (askpass bug). Use token in `.pat` file:
  ```bash
  cd /home/runner/workspace
  git push "https://$(cat .pat | tr -d '\n')@github.com/org/repo.git" main
  ```
- This is the ONLY working push pattern on Replit. SSH does not work (no askpass support).
- If `git push` fails with "could not read Username", the `.pat` token pattern above is required.

## Machine Reset Recovery

On reset, all ephemeral storage is wiped. To restore a working environment:

1. **Run `hermes.sh`** — the canonical setup script handles:
   - uv install (if missing)
   - Clone/pull `hermes-agent` and `uv pip install -e ".[all]"`
   - `hermes-webui` clone + start
   - Binary wrapper in `~/.local/bin/hermes`
   - `sync.sh` (secret sync) + `script.sh` (VNC desktop)
2. **Reinstall Python deps** — `~/.pythonlibs` is ephemeral; `hermes.sh` runs `uv pip install -e ".[all]"` automatically
3. **Reinstall npm deps** — any `npm i -g` packages are lost; reinstall manually
4. **Git config** — if you had `user.email`/`user.name` set in `~/.config/git/config`, reconfigure:
   ```bash
   git config --global user.email "you@example.com"
   git config --global user.name "Your Name"
   ```
5. **Secrets** — `sync.sh` pulls from `hermes-secrets` repo; ensure `.pat` is in place

**What survives a reset:** everything in `/home/runner/workspace/` (git-tracked) minus symlinked dirs (`.cache`, `.pythonlibs`, `.local`, `.config` point to ephemeral `~/` which is wiped).
**What's lost:** `~/hermes-agent/.venv` (ephemeral — recreated by `hermes.sh`), `.config`, `~/.cache`, `/tmp`, any npm global packages, `~/.config/bashrc`, all pip packages in `~/.pythonlibs`.

## Common Pitfalls

1. **Writing outside workspace** — files lost on restart. Always use `~/workspace/`.
2. **Installing via apt** — fails silently. Use Nix (`.replit`) or pip/npm.
3. **Assuming ~/.hermes persists** — it's ephemeral; real data lives in `.hermes_data/`.
4. **Forgetting UV_PYTHON_DOWNLOADS=manual** — prevents uv from auto-downloading Python.
5. **Background processes die on restart** — use Replit workflows or cron for persistence.
6. **No sudo** — don't try to `chmod` system dirs or install system packages.
7. **Symlinking a venv binary** — a symlink to `venv/bin/hermes` fails in a fresh shell because the venv isn't activated. Always create a **wrapper script** that `exec` the venv python directly.
8. **Referencing `$HOME/.pythonlibs/bin` in scripts when user wants workspace paths** — the user prefers workspace paths (`$HOME/workspace/.pythonlibs/bin`) in hermes.sh and wrapper scripts because `.pythonlibs` is a real persistent directory in workspace (NOT symlinked). The symlink loop runs before any PATH-dependent command, so workspace paths resolve correctly for the other dirs.
9. **`rm -rf "$HOME/$d"` in symlink loop deletes real data** — never `rm -rf` the ephemeral target (`~/.cache`, etc.) in the setup loop. Only `rm -rf` the workspace path (which is about to become a symlink). Use `mv` to preserve existing workspace data before symlinking, and `[ -L ... ] && continue` for idempotency. Add `|| true` after `mv` to handle empty dirs with `set -e`.
10. **`.pythonlibs` and `.config` must NOT be in the symlink loop** — Replit's `.replit` config auto-manages these directories at startup. Symlinking them breaks Replit's Python/Node package installation. Only `.cache` and `.local` should be symlinked to ephemeral `~/`.
11. **Symlink loop must run AFTER venv setup** — if the symlink loop runs before `uv venv .venv`, the `rm -rf` can delete the venv. Always structure `hermes.sh` as: (1) clone + venv + pip install, (2) symlink loop, (3) wrapper + launch.
12. **Large binary files in git** — browsers, `.zip` archives, and other large binaries (>100 MB) will be rejected by GitHub on push. If accidentally committed, remove from history with `git filter-branch --force --index-filter 'git rm -r --cached --ignore-unmatch <dir>/' -- --all` then force-push. Add to `.gitignore` immediately.
13. **Assuming .cache location is fixed** — `.cache` location depends on `XDG_CACHE_HOME`. Replit may set it to workspace `.cache/` (persistent) which eats storage. Unset it if you want ephemeral cache to free workspace.
14. **Writing to /mnt/nix arbitrarily** — `/mnt/nix/` is writable but Nix-managed. Manual writes may corrupt the store or get wiped by GC. Keep data in workspace.
15. **Cache direction ambiguity** — when the user says "make sure cache isn't in workspace", they mean **ephemeral** (`~/.cache`), not symlinked to workspace. Always confirm cache direction before changing.
16. **Hermes `terminal` tool rejects `&` in foreground mode** — use `terminal(background=true)` instead, then manage via the `process` tool. **Do NOT retry with `&` — switch to `background=true` immediately.**
17. **`hermes` command not found in fresh terminal** — `.bashrc` is read-only (Nix store) and does NOT source `.profile`. The only user-writable file that Replit's `.bashrc` sources is `~/.config/bashrc`. Create it with PATH entries for `.pythonlibs/bin` and `.local/bin`. Do NOT rely on `.profile` alone — it's only read by login shells, and Replit terminals are non-login shells.
18. **Trying to edit `~/.bashrc`** — it's read-only (Nix store symlink). User-writable shell init goes in `~/.config/bashrc` (sourced by `.bashrc`) or `~/.profile` (login shells only).
19. **Only unsetting `XDG_CACHE_HOME`** — Replit also sets `XDG_CONFIG_HOME` and `XDG_DATA_HOME` to workspace paths. All three must be unset to fully redirect ephemeral data out of workspace: `unset XDG_CACHE_HOME XDG_CONFIG_HOME XDG_DATA_HOME`.
20. **Stale real `.pythonlibs` directory in workspace** — if `.pythonlibs` was ever a real directory before being excluded from the symlink loop, the old real directory can persist and waste 200-300 MB. Manually `rm -rf ~/workspace/.pythonlibs` and let `uv pip install` rebuild it fresh in the venv (`.pythonlibs/bin` just holds the wrapper script; actual packages live in the venv).
21. **Symlink loop must run AFTER venv + pip, not before** — if `for d in ...; do rm -rf "$HOME/workspace/$d"; ...` runs before `uv venv .venv`, it deletes nothing (`.venv` doesn't exist yet). But on re-runs, `.venv` already exists and `rm -rf` destroys it. Canonical ordering: (1) uv install, (2) clone + venv + pip install, (3) symlink loop, (4) wrapper + launch.
22. **Unnecessary PATH export in wrapper scripts** — the `hermes` wrapper script inherits PATH from `hermes.sh` (the parent process) and from `~/.config/bashrc` (sourced by the shell). Duplicating `export PATH=...` in the wrapper is redundant. The wrapper only needs: `export HERMES_HOME`, `mkdir -p`, `ln -s`, and `exec python -m hermes_cli.main`.
23. **`hermes.sh` ordering: script.sh and sync.sh should run AFTER setup, not before** — running them in background (`&`) at the top of `hermes.sh` means they get killed when the script exits. Run them in **foreground** after the venv + symlink + wrapper setup.
24. **Using `>>` to append to `~/.config/bashrc`** — if `hermes.sh` runs multiple times and the grep check fails, `>>` appends duplicate PATH entries. Use `cat >` (overwrite) with a heredoc instead of `echo >>`.
25. **Bare `hermes` at the end of `hermes.sh`** — runs whatever is on PATH, which may not be the wrapper just built. Use `$BIN/hermes` explicitly to launch the correct binary.
26. **No `set -euo pipefail` in hermes.sh** — without it, errors are silently ignored and the script continues. Always add `set -euo pipefail` at the top.
28. **Curl health check in wrapper** — a `curl` + remote install on every `hermes` invocation is unnecessary overhead and a security concern. Remove it from the wrapper; setup logic belongs in `hermes.sh` only.
29. **Assuming root access exists** — `/root` is inaccessible, `sudo` is not installed, and user passwords cannot be changed. This is an unprivileged container. Do not attempt privilege escalation or system-level modifications.
28. **Destructive `mkdir -p ... || rm -rf` pattern** — never chain `mkdir -p` with `|| rm -rf` as a fallback. If `mkdir` fails (e.g., symlink exists where dir should be), `rm -rf` destroys data. Use `mkdir -p` alone (it's idempotent).
29. **`/mnt/snix` is read-only despite `df` showing free space** — `df -h` reports 129GB available on `/mnt/snix`, but it's mounted read-only. Any write attempt fails with "Read-only file system". Always test writability with `touch "$mnt/.wtest"` before assuming a mount is usable. Use `/mnt/scratch` (~3GB real) for ephemeral writable scratch space.

30. **`/mnt/scratch` real limit is ~3GB, not 30GB** — `df` shows 30GB free because `/mnt/scratch` shares `/dev/vdc` with `/home/runner` (32GB device). A 10GB write test failed at ~3.1GB. The 30GB is the device size, not the per-mount quota. For large temporary data, use `/home/runner/workspace` instead.

31. **`/home/runner/workspace` is thin-provisioned** — deleted files may not reclaim space at the block level. After writing and deleting a 40GB file, `df` still showed 43GB used. This is phantom allocation; real writes still succeed up to 256GB. Don't panic if `df` shows high "used" after deleting large files.

32. **Large writes can crash the container** — writing >40GB in a single `dd` without a timeout caused a forced restart before cleanup could run. Always use `timeout` for large writes: `timeout 200 dd if=/dev/zero of=... bs=1M count=N`. This ensures the process stops cleanly before hitting any quota/OOM limit.

33. **Per-write cap at ~48-50GB** — even with `timeout`, a single `dd` process stops writing at ~48GB regardless of the requested count (tested with `count=12800` for 100GB target — only 48GB written). This is a per-process write limit, not a total space limit. The 256GB total is reachable across multiple writes, but not in one shot. Append (`>>`) does NOT work after the cap — file size stays fixed at ~48GB.

34. **Safe large-write pattern** — to write large files without crashing:
    - Use `bs=8M` (larger blocks = less overhead = more stable)
    - Wrap in `timeout` as safety net
    - Use `terminal(background=true)` for writes >60s (foreground max is 600s)
    - Example: `timeout 400 dd if=/dev/zero of=bigfile bs=8M count=12800` (attempts 100GB, caps at ~48GB cleanly)

35. **Thin-provisioned phantom space** — after writing and deleting a 40GB file, `df` may still show 43GB+ used. The storage backend doesn't reclaim blocks immediately (or ever). This is phantom allocation — no file owns the space, but `df` reports it as used. Real writes still succeed up to 256GB total. Don't trust `df` "Avail" after large deletions; test with `touch` + small write instead.

36. **Docker containers fail with IPv6 nginx errors** — Replit's container network doesn't support IPv6. Services binding `[::]:PORT` crash with `Address family not supported by protocol`. Fix: `-e DISABLE_IPV6=true` for linuxserver images, or override configs to bind IPv4 only. See `references/docker-on-replit.md`.
37. **Docker ports need `.replit` declaration** — a container publishing a port with `-p` is NOT externally accessible unless you also add a `[[ports]]` entry in `.replit` with `exposeLocalhost = true`.
38. **xrdp fails with "Could not start log"** — default xrdp configs use relative log paths and syslog, both unavailable on Replit. Copy configs to `~/workspace/` and set absolute `LogFile` path + `EnableSyslog=false`. See `references/xrdp-on-replit.md`.
39. **VPN containers (gluetun, WireGuard, OpenVPN) fail on Replit** — the kernel blocks netlink routing operations (`netlink receive: operation not supported`) even with `--cap-add=NET_ADMIN`. `/dev/net/tun` also doesn't exist and can't be created without root. VPN containers need a real VPS. See `references/vpn-containers-on-replit.md`.

## How Replit Shell PATH Works

Replit's `.bashrc` (read-only, Nix store) sources `$HOME/.config/bashrc` if it exists. This is the ONLY user-writable file that gets sourced in non-login interactive shells (which is what Replit terminals use). **`.profile` is only read by login shells and will NOT work.**

Create `~/.config/bashrc` with PATH additions:
```bash
[ -d "$HOME/.local/bin" ] && PATH="$HOME/.local/bin:$PATH"
[ -d "$HOME/workspace/.pythonlibs/bin" ] && PATH="$HOME/workspace/.pythonlibs/bin:$PATH"
export PATH
```

This is why wrappers placed in `~/.local/bin/` (like `hermes`) are available in fresh terminals — `.local/bin` is added to PATH by this file and by `.profile`.

## Session Persistence

Sessions are stored in `~/.hermes_data/state.db` (SQLite). Columns: id, source, model, title, started_at, message_count, etc.

**Important:** CLI sessions that exit before completing a conversation (e.g., background mode, `--version`, `--help`) show `message_count=0` in the database. This is normal — the count tracks messages in the separate `messages` table, which only gets populated during interactive conversations. WebUI session transcripts are stored separately in `.hermes_data/webui/sessions/` (JSON + journal files), not in the SQLite `messages` table.

To get persistent CLI sessions: run `hermes` interactively in a real terminal (not background). The WebUI is the primary interface for persistent conversation history.

## User Preferences

- **Short scripts:** Keep setup scripts crisp (< 30 lines). Merge exports into single lines, use short-circuit guards (`[ -d ... ] || clone`), avoid helper functions and flags.
- **Commands first:** Prefer telling the user commands to execute over making config changes themselves. Agent should describe exact `hermes config set` commands rather than auto-applying.
- **Active skill maintenance:** After sessions that produce a new technique, workaround, or workflow, proactively update the relevant skill file — don't wait for the user to ask. A session that produces zero skill updates is a missed learning opportunity.
- **Always latest:** When downloading software, always resolve the latest version dynamically (via redirect/API). Never hardcode version numbers in URLs.
- **Code only:** When user asks for "code" or "commands", give just the code — no preamble, no explanation. They want copy-pasteable snippets, not prose.

## Verification Checklist

- [ ] Files written to `/home/runner/workspace/` or `.hermes_data/`
- [ ] No `apt`/`sudo` in scripts; no attempts to access `/root` or escalate privileges
- [ ] Large temporary data directed to `/home/runner/workspace` (not `/mnt/scratch` which is limited to ~3GB, not `/mnt/snix` which is read-only)
- [ ] `.local/bin` used for permanent command wrappers (not symlinks to venv)
- [ ] Git auth uses `.pat` token pattern, not askpass
- [ ] Services use background `&` or Replit workflows, not systemd
- [ ] `XDG_CACHE_HOME`, `XDG_CONFIG_HOME`, `XDG_DATA_HOME` all handled intentionally (unset for ephemeral, set if persistence needed)
- [ ] No redundant PATH export in `hermes.sh` — PATH is handled by `~/.config/bashrc` for interactive shells and by Nix default PATH for the script itself
- [ ] `hermes.sh` has `set -euo pipefail`, correct ordering (uv → clone/venv → bashrc → wrapper → symlinks → script.sh/sync.sh → launch), and uses `$BIN/hermes` to launch
- [ ] Ephemeral dirs (`.cache`, `.local`) symlinked to `~/` to keep workspace lean; `.pythonlibs` and `.config` stay as real persistent dirs (Replit-managed)
- [ ] `~/.config/bashrc` exists with PATH entries (written with `cat >`, not `echo >>`)
