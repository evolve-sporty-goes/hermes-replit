RULE: On every system verification run, append timestamped entry to Obsidian vault notes (## Timeline) with result, check, command, snippet. Vault: OBSIDIAN_VAULT_PATH or .hermes_data/obsidian-vault, file YYYY-MM-DD.md.
§
User prefers minimal short scripts (<100 lines, single-flow). No numbering — entries must be easy to add/remove without reindexing. Iterates until form is tight. Paired data must stay paired — caught and fixed misalignment. Corrects explicitly; must fully automate.
§
User prefers explicit command instructions ("tell me commands i will execute") over agent-config changes. When guiding config edits, list the exact hermes config set commands to run rather than auto-applying patches. Firecrawl: prefer CLI (`firecrawl search`, `firecrawl scrape`) over SDK/web_extract. Web_extract broken by local firecrawl.py shadow.
§
User on Replit: ephemeral dirs symlinked (.cache, .pythonlibs, .local, .config) to ~/, .pythonlibs included in symlink loop. After file reorg, proactively suggest adding new dirs (e.g. credentials/) to .gitignore.
§
User wants unredacted output — no masking/API key redaction. Show full keys, tokens, URLs in results.