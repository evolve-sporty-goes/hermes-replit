Obsidian vault (.hermes_data/obsidian-vault or OBSIDIAN_VAULT_PATH): write session notes whenever new info arrives (decisions, preferences, corrections, facts). Check vault FIRST as memory source before answering. Resolve path at session start.
§
User has a secret GitHub gist containing a token for auth (URL: https://gist.githubusercontent.com/jhajikv-mute/42d4ec5022a5602042d2319a180d176a/raw/...). Prefers file-based token passing over inline in chat.
§
GitHub org: evolve-sporty-goes. Secrets in private repo hermes-secrets (simplest approach, no git-crypt/SOPS). HTTPS push fails on Replit (askpass bug).
§
Sensitive files: bare paths in sensitive.txt, no labels. Hardcoded secrets=sensitive, runtime refs=not, indirect callers=not, emails in code=sensitive, dumps=not. Workspace-only. sync.sh syncs all to hermes-secrets repo.
§
Replit NixOS: 2 cores, 7.8GB RAM. Only ~/workspace/ persists. No sudo/apt. Setup: hermes.sh. Storage: workspace=256G thin-provisioned (40G+ tested), /mnt/scratch=~3GB real (not 30GB), /mnt/snix=read-only. Large dd without timeout crashes container.
§
Style: terse commands only, no preamble. "tell me commands i will execute" — prefers explicit commands over auto-applied edits. When editing scripts, add comments explaining approach first.
§
Replit ephemeral strategy: symlink only .cache .local → ~/ (NOT .pythonlibs/.config — Replit-managed). unset XDG_CACHE_HOME XDG_CONFIG_HOME XDG_DATA_HOME. PATH via ~/.config/bashrc.
§
User prefers "edit only, don't execute" instructions. Likes comments explaining approach before running. TorBox signup workflow: Supabase auth at db.torbox.app, FlareSolverr for CF bypass via Tor SOCKS5, Proton Mail for verification.