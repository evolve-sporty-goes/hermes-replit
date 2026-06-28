RULE: On every system verification run, append timestamped entry to Obsidian vault notes (## Timeline) with result, check, command, snippet. Vault: OBSIDIAN_VAULT_PATH or .hermes_data/obsidian-vault, file YYYY-MM-DD.md.
§
Scripts: crisp/short, <100 lines, single-flow, no flags/options/menus/helper fns. Password from ~/config.py. Email from email.sh. Credentials in service-specific .txt, APPEND never overwrite.
§
User prefers explicit command instructions ("tell me commands i will execute") over agent-config changes. When guiding config edits, list the exact hermes config set commands to run rather than auto-applying patches. Firecrawl: prefer CLI (`firecrawl search`, `firecrawl scrape`) over SDK/web_extract. Web_extract broken by local firecrawl.py shadow.
§
User corrects approach explicitly. Agent must do full automation (never ask user to paste links). TorBox magic link: sometimes "generate only, don't click" — output URL without browser_navigate.
§
User on Replit: ephemeral dirs symlinked (.cache, .pythonlibs, .local, .config) to ~/, .pythonlibs included in symlink loop. After file reorg, proactively suggest adding new dirs (e.g. credentials/) to .gitignore.
§
User wants unredacted output — no masking/API key redaction. Show full keys, tokens, URLs in results.