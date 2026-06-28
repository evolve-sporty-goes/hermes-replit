# Filtering Flagged Files for sensitive.txt

After running the grep/find commands, filter the raw output using this list of known false positives:

## System directories to exclude
- `.hermes_data/webui/` — session logs and request dumps
- `.hermes_data/skills/` — Hermes agent skills
- `.hermes_data/sessions/` — conversation transcripts
- `.hermes_data/lsp/` — LSP server packages
- `.hermes_data/memories/` — memory store
- `.hermes_data/logs/` — agent error/access logs
- `.hermes_data/obsidian-vault/` — Obsidian notes
- `.hermes_data/_run_journal/` — session run journals

## Filename patterns to exclude
- `*.jsonl`, `*_journal*`, `*_run_journal*`, `_turn_journal*` — conversation logs
- `request_dump*.json` — API request dumps
- `bootstrap-*.log` — startup logs
- `*auth.lock`, `*auth.json.corrupt` — lock/corrupt files
- `.hermes_history`, `.hermes_data/.hermes_history` — CLI history

## Content-based false positives matched by secret patterns
| Script | Why it matches | Is it a secret? |
|--------|---------------|-----------------|
| `scripts/backup.sh` | references `apikey` in curl | No — uses `$ANON_KEY` variable |
| `scripts/Signup` | references `apikey` in curl | No — uses `$ANON_KEY` variable |
| `scripts/tor_signup.sh` | references `apikey` in curl | No — uses variable |
| `scripts/torbox-*.sh` | references `api_key`, `password=` | Check: uses `$PASSWORD` var, not literal |
| `scripts/firecrawl_gen.py` | extracts `fc-` keys at runtime | No — browser automation script |
| `scripts/openrouter_signup.py` | extracts `sk-or-v1-` keys | No — browser automation script |
| `docs/*.md` | documents secret patterns | No — documentation |
| `freellmapi` | matches `*key*` pattern | **YES** — contains Cloudflare API Token + frellmapi key as literals |
| `.hermes_data/fc_search.mjs` | references API patterns | No — internal search script |

## True positive patterns (always include)
- `*_credentials.txt` — credential files with literal tokens
- `.pat` — GitHub Personal Access Token
- `.supabase_anon_key` — Supabase anonymous key
- `.env`, `.hermes_data/.env` — environment variables file
- `auth.json` — OAuth tokens
