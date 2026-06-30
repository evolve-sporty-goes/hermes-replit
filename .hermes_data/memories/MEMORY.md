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
When the user asks to modify Hermes config.yaml, provide the shell commands for them to run rather than editing the file directly — the patch tool blocks writes to the agent's own config. Use heredoc append or hermes config set commands.
§
Workspace: credentials/ docs/ scripts/ dirs. System dirs never moved. Replit startup=.replit [startup] startOn + wrapper with auto-restart (rate-limited).
§
Hermes non-interactive model config: `hermes model` is TUI-only, cannot be scripted. Set config.yaml directly via `hermes config set model.provider/base_url/api_key/api_compat/default/display_name`. For active config use `hermes config show | grep Model` — config.yaml grep shows stale creds.
§
Browser automation: CloakBrowser (2026-07-01). headless=True CRASHES on Replit/NixOS — use headless=False + xvfb-run. humanize=True. proxy as string not dict. Clerk.js checkbox: JS dispatchEvent needed. Free tier=v146, Pro=v148+.
§
Dockerizing Rust: iterate linker errors by reading `-l<name>` → install `lib<name>-dev`. COPY paths relative to build context. Multi-binary repos need separate WORKDIR per cargo build.