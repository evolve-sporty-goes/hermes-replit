Obsidian vault (.hermes_data/obsidian-vault or OBSIDIAN_VAULT_PATH): write session notes whenever new info arrives (decisions, preferences, corrections, facts). Check vault FIRST as memory source before answering. Resolve path at session start.
§
User: file-based creds (~/config.py, workspace/credentials/). Terse bash scripts they run themselves — no preamble, no markdown. Unredacted output. Iterates scripts incrementally (counter → spinner → one-liner). Background silent setup + foreground spinner pattern. Save to workspace/scripts/, chmod +x.
§
When the user asks to modify Hermes config.yaml, provide the shell commands for them to run rather than editing the file directly — the patch tool blocks writes to the agent's own config. Use heredoc append or hermes config set commands.
§
Browser: CloakBrowser, headless=False + DISPLAY=:1, no xvfb, humanize=True. Clerk forms: type() + React fiber onChange. Turnstile-solver FAILS on Clerk sitekeys — user clicks on screen. OpenRouter signup: scripts/email.sh → ~/or_signup_final.py
§
User prefers betterleaks for secret scanning (installed at ~/.pythonlibs/bin/betterleaks). Wants install scripts fetching latest from GitHub API. Prefers 2-3 line usage examples. Scripts: terse bash, background silent setup + foreground spinner, all output to log file, chmod +x, run commands.
§
On system verification runs, append timestamped entry to Obsidian vault notes (## Timeline) with result, check, command, snippet. Vault: OBSIDIAN_VAULT_PATH or .hermes_data/obsidian-vault, file YYYY-MM-DD.md.