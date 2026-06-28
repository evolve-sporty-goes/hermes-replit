# Obsidian Vault Note Conventions

## Session notes

When a vault is used to store per-session notes, follow this convention:

- **Filename**: `YYYY-MM-DD.md` (matching the date of the session, e.g. `2026-06-25.md`)
- **Structure**: Start with a single H1 heading containing the date and purpose, e.g. `# 2026-06-25 Session Notes`
- **Content sections**: Include a "## What Happened" section that captures events chronologically. Add other sections as needed (Setup, Decisions, Open Items, etc.)
- **Update policy**: Keep notes updated constantly during the session as new info arrives. Don't batch at the end.
- **Memory source**: Treat the vault as a secondary persistent memory source. Read it at session start; refer back when context crosses sessions.

## Dated session notes rationale

Batching everything into one long-lived "daily notes" topic page is the native Obsidian pattern. Separate-per-session files have advantages when the session happens outside Obsidian (e.g. in Hermes) and Obsidian may never be opened — the agent owns the structure. Choose based on user preference.

## Vault placement reference

| Setup | Env file location | Vault path |
|-------|-------------------|------------|
| Hermes workspace (project) | `.hermes_data/.env` | `.hermes_data/obsidian-vault/` |
| Generic | `~/.hermes/.env` | `~/Documents/Obsidian Vault/` |

## When the agent writes to the vault

The agent (not the user) owns the file structure. Write notes during the session as decisions/infos surface — not in a batch at the end. Use the vault for:
- Decisions and their rationale
- User preferences discovered mid-session
- Environment quirks encountered
- Tool workarounds (e.g. credential-file protection)
- Open items to carry forward

Do NOT write to the vault:
- Secrets, tokens, passwords (use .env or private repos)
- Ephemeral debug logs that will be stale in a week (use .hermes_data/logs/)
- Full chat transcripts (use session_search for that)
