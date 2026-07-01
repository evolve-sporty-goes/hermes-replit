Obsidian vault (.hermes_data/obsidian-vault or OBSIDIAN_VAULT_PATH): write session notes whenever new info arrives (decisions, preferences, corrections, facts). Check vault FIRST as memory source before answering. Resolve path at session start.
§
User: file-based creds (~/config.py, workspace/credentials/). Terse bash scripts they run themselves — no preamble, no markdown. Unredacted output. Iterates scripts incrementally (counter → spinner). Background silent setup + foreground spinner pattern. Save to workspace/scripts/, chmod +x.
§
When the user asks to modify Hermes config.yaml, provide the shell commands for them to run rather than editing the file directly — the patch tool blocks writes to the agent's own config. Use heredoc append or hermes config set commands.
§
Hermes non-interactive model config: `hermes model` is TUI-only, cannot be scripted. Set config.yaml directly via `hermes config set model.provider/base_url/api_key/api_compat/default/display_name`. For active config use `hermes config show | grep Model` — config.yaml grep shows stale creds.
§
Browser: CloakBrowser, headless=False + DISPLAY=:1, no xvfb, humanize=True. Clerk forms: type() + React fiber onChange. Turnstile-solver FAILS on Clerk sitekeys — user clicks on screen. OpenRouter signup: scripts/email.sh → ~/or_signup_final.py
§
Dockerizing Rust: iterate linker errors by reading `-l<name>` → install `lib<name>-dev`. COPY paths relative to build context. Multi-binary repos need separate WORKDIR per cargo build.
§
OpenRouter Turnstile: iframe at ~(478,189) size 300x65 has NO visible checkbox. ONLY page.mouse.click(frame_x+30, frame_y+h/2) works (CDP-level). xdotool & frame.locator.click() FAIL.
§
User prefers betterleaks for secret scanning (installed at ~/.pythonlibs/bin/betterleaks). Wants install scripts fetching latest from GitHub API. Prefers 2-3 line usage examples. Scripts: terse bash, background silent setup + foreground spinner, all output to log file, chmod +x, run commands.