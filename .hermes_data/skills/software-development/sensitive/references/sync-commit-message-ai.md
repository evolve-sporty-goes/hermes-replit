# AI-Generated Commit Messages in Sync Script

The sync script can generate natural-language commit messages by calling an LLM via OpenRouter API instead of using static file lists.

## Motivation

Default `git commit -m "auto-sync: $(date)"` is uninformative. Shell-only approaches like listing filenames are robotic ("added foo.json, removed bar.db"). An LLM call produces natural summaries ("updated gateway session files, removed stale snapshot cache").

## Implementation Pattern

Add a shell function that tries an API call on every sync, with a shell fallback for offline scenarios:

```bash
ai_commit_msg() {
    local diffstat; diffstat=$(git diff --cached --stat | tail -1)
    local key; key=$(grep 'API_KEY' /path/to/credentials.txt 2>/dev/null | tail -1 | cut -d= -f2)
    [ -z "$key" ] && { /* fallback to awk-based verb+file list */; return; }
    local msg; msg=$(curl -s --max-time 8 https://openrouter.ai/api/v1/chat/completions \
        -H "Authorization: Bearer $key" -H "Content-Type: application/json" \
        -d "{\"model\":\"google/gemini-2.0-flash-001\",\"messages\":[{\"role\":\"user\",\"content\":\"Write a git commit message under 10 words for: $diffstat. Raw text only.\"}],\"max_tokens\":40}" \
        | python3 -c "import sys,json; print(json.load(sys.stdin)['choices'][0]['message']['content'].strip().strip('\"').strip('`'))" 2>/dev/null)
    [ -n "$msg" ] && echo "$msg" || echo "$diffstat"
}
```

Usage:
```bash
git commit -m "auto-sync: $(ai_commit_msg)"
```

## Design Decisions

| Choice | Rationale |
|--------|-----------|
| `google/gemini-2.0-flash-001` | Free tier on OpenRouter, fast enough for sync use |
| `--max-time 8` | Don't stall the sync script if API is slow |
| `--max_tokens 40` | Limits output to a short commit message |
| `tail -1` for diff stat | Summary line only ("15 files changed, 411 insertions...") — smaller prompt, still meaningful |
| Fallback to awk | If no API key exists or network fails, uses numstat-based "verb filename" list |
| `grep 'API_KEY' ... \| tail -1` | Reads the most recent key from credentials file |

## Fallback (no API key)

When no key is available, use `git diff --cached --numstat` to determine verbs:
```bash
git diff --cached --numstat | awk -F'\t' '{
    a="updated"; 
    if($1>0&&$2==0)a="added"; 
    else if($2>0&&$1==0)a="removed"; 
    printf "%s %s, ",a,$3
}' | sed 's/, $//'
```

Produces: `updated gateway.log, added kanban.db, removed stale_session.json`

## Pitfalls

- Do NOT use `$()` inside a heredoc — nesting breaks quoting
- The `curl` + inline `python3 -c` chain needs to be a function, not an inline expansion
- API failures should always fall back gracefully — never block the sync on an LLM call
