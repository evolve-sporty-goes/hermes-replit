# Scanning for Sensitive Files

## Approach

Use `search_files` (ripgrep-backed) with regex patterns to find hardcoded secrets in `.py`, `.sh`, `.txt`, `.json`, `.yaml`, `.toml` files.

## Patterns that catch most secrets

```
# Hardcoded literals (NOT runtime config refs)
(?i)(?:password|passwd|pwd)\s*=\s*["\'][^"\']{4,}["\']
(?i)(?:api_key|apikey)\s*=\s*["\'][^"\']{10,}["\']
(?i)(?:access_token|auth_token)\s*=\s*["\'][^"\']{10,}["\']
(?i)(?:secret|client_secret)\s*=\s*["\'][^"\']{10,}["\']
(?i)(?:username|user|login)\s*=\s*["\'][^"\']{4,}["\']
-----BEGIN (?:RSA |DSA |EC |OPENSSH )?PRIVATE KEY-----
(?i)Bearer\s+[A-Za-z0-9\-._~+/]+=*
sk-or-v1-[a-zA-Z0-9]{20,}   # OpenRouter keys
ghp_[a-zA-Z0-9]{36}         # GitHub PATs
fc-[a-zA-Z0-9]{20,}         # Firecrawl keys
[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}  # Email addresses
```

## Exclusions (skip these paths)

- `node_modules/`, `__pycache__/`, `.hermes_data/lsp/`
- `.hermes_data/skills/` (templates, not actual secrets)
- `.hermes_data/cache/`, `.hermes_data/logs/`
- `.git/`

## Distinguishing sensitive vs non-sensitive

**Sensitive** — literal value assigned in code:
```python
PROTON_PASSWORD = "Satyana@1234"     # SENSITIVE
API_KEY = "sk-or-v1-abc123..."        # SENSITIVE
```

**NOT sensitive** — reads from config/module at runtime:
```python
PROTON_PASS = cfg.PROTON_PASSWORD     # NOT sensitive
import config; KEY = config.API_KEY   # NOT sensitive
```

**NOT sensitive** — indirect execution:
```python
subprocess.run(["bash", "email.sh"])  # NOT sensitive (email.sh itself is)
```

## File-name-based detection

Also search by filename for files that are sensitive by nature:
- `*.env`, `*credentials*`, `*secret*`, `*token*`, `*.key`, `*.pem`, `*.pat`

## What NOT to flag (ignore list)

- **Email addresses in documentation/markdown/skill references** — only flag emails hardcoded in executable code (`.py`, `.sh`) or stored in data/credential output files
- **`mail.txt`** — transient log of generated Duck emails, NOT account credentials. Do NOT add to sensitive.txt
- **Files outside workspace** — `~/config.py`, `~/duckmail.py`, etc. are excluded from scope

## Verification after adding to sensitive.txt

Run a quick ad-hoc script to verify:
1. All paths in sensitive.txt are absolute workspace paths
2. All referenced files exist on disk
3. No duplicate entries
4. No empty lines
5. sync.sh parsing logic handles all entries (basename extraction works)
