# hermes-replit

Replit workspace for running [Hermes Agent](https://github.com/NousResearch/hermes-agent) with automated signup and credential management workflows.

## Overview

This repo is the live configuration and scripting layer for a Replit-hosted Hermes Agent instance. It includes:

- **Hermes Agent** — installed and launched via `scripts/hermes.sh` (clones `NousResearch/hermes-agent`, sets up a venv, installs dependencies, and starts the CLI)
- **Automated signup scripts** — browser-automated account creation for services like OpenRouter, TorBox, Brave, and Firefox, using Camoufox (anti-fingerprint Firefox) and Playwright
- **Credential management** — credentials stored in `credentials/`, synced to a private `hermes-secrets` repo via `scripts/sync`
- **FlareSolverr / Tor proxying** — scripts for bypassing Cloudflare challenges and rotating Tor exit nodes
- **Sensitive file tracking** — `sensitive.txt` lists files scanned by the sensitive skill; secrets are gitignored and never committed

## Structure

```
.
├── .replit              # Replit config (Nix env, workflows, ports)
├── .gitignore           # Ignores all except whitelisted paths; excludes secrets
├── scripts/
│   ├── hermes.sh        # Installs/launches Hermes Agent
│   ├── sync             # Syncs workspace to hermes-secrets repo
│   ├── setcfapi.sh      # Cloudflare API setup
│   ├── start-tor-flare.sh
│   ├── flaresolverr-*.sh / .py
│   ├── tor_signup.sh / torbox-*.sh
│   ├── openrouter_signup.py
│   ├── brave / firefox / torbrowser  # Browser launchers
│   └── ...
├── credentials/         # Service credentials (gitignored, synced to hermes-secrets)
├── docs/
│   ├── Instructions.txt # OpenRouter signup automation docs
│   └── torbox-info.md
├── sensitive.txt        # Files tracked by the sensitive skill
└── .hermes_data/        # Hermes Agent data dir (config, sessions, state)
```

## Getting Started

1. **Run Hermes** — The Replit run button executes `scripts/hermes.sh`, which:
   - Installs `uv` if missing
   - Clones/updates `hermes-agent` into `~/hermes-agent`
   - Creates a venv and installs Hermes with all extras
   - Sets up PATH and wrapper scripts
   - Launches `hermes`

2. **Manual launch:**
   ```bash
   bash ~/workspace/scripts/hermes.sh
   ```

## Ports

| Local | External | Purpose |
|-------|----------|---------|
| 3000–3003 | 3000–3003 | Web services |
| 3389 | 4200 | VNC (desktop) |
| 5000 | 5000 | Flask/app |
| 8787 | 80 | Hermes WebGUI |

## Security

- All credentials and secrets are gitignored — they live only in `credentials/` and `.hermes_data/`
- `scripts/sync` pushes sensitive files to the private `evolve-sporty-goes/hermes-secrets` repo
- `sensitive.txt` is maintained by the sensitive skill and lists all files that should never be committed in plaintext
