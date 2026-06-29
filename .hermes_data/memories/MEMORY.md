Obsidian vault (.hermes_data/obsidian-vault or OBSIDIAN_VAULT_PATH): write session notes whenever new info arrives (decisions, preferences, corrections, facts). Check vault FIRST as memory source before answering. Resolve path at session start.
§
User prefers file-based token/credential passing. Explicit commands/scripts they execute themselves (terse, no preamble). Firecrawl: prefer CLI over SDK/web_extract.
§
GitHub org: evolve-sporty-goes. Secrets in private repo hermes-secrets (simplest approach, no git-crypt/SOPS). HTTPS push fails on Replit (askpass bug).
§
Sensitive files: bare paths in sensitive.txt, no labels. Hardcoded secrets=sensitive, runtime refs=not, indirect callers=not, emails in code=sensitive, dumps=not. Workspace-only. sync.sh syncs all to hermes-secrets repo.
§
User prefers explicit scripts that they will execute themselves. Give file paths + chmod +x + run commands. Wants terse commands only, no preamble.
§
User prefers "edit only, don't execute" instructions. Likes comments explaining approach before running. TorBox signup workflow: Supabase auth at db.torbox.app, FlareSolverr for CF bypass via Tor SOCKS5, Proton Mail for verification.
§
When the user asks to modify Hermes config.yaml, provide the shell commands for them to run rather than editing the file directly — the patch tool blocks writes to the agent's own config. Use heredoc append or hermes config set commands.
§
Workspace organized: credentials/ docs/ scripts/ dirs created, system dirs (.hermes_data .git .cache .local .pythonlibs .config) must never be moved. subnet-proxy kept at root as standalone Go project.
§
Hermes non-interactive model config: `hermes model` is TUI-only, cannot be scripted. Set config.yaml directly via `hermes config set model.provider/base_url/api_key/api_compat/default/display_name`. For active config use `hermes config show | grep Model` — config.yaml grep shows stale creds.
§
scripts/sync derives workspace root from dirname of .gitignore path, never hardcodes /home/runner/workspace. User explicitly requested this.