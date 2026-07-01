# betterleaks Usage Reference

Installed at: `~/.local/bin/betterleaks` (v1.6.1)

## Quick Commands

```bash
# Scan repo (working dir + history)
betterleaks git --source .

# Scan staged changes only (pre-commit)
betterleaks git --source . --staged

# Scan with custom config
betterleaks git --source . --config .betterleaks.toml

# Validate config
betterleaks config validate --config .betterleaks.toml
```

## Comparison: gitleaks vs betterleaks

| Feature | gitleaks | betterleaks |
|---------|----------|-------------|
| Speed | Fast | Faster (Go + re2) |
| Validation | Live API validation | Live API validation |
| Rules | Built-in + custom | Built-in + custom (same format) |
| Ignore files | `.gitleaksignore` | `.betterleaksignore` |
| Config | `.gitleaks.toml` | `.betterleaks.toml` (or `.gitleaks.toml`) |
| GitHub/GitLab scanning | No | Yes (`betterleaks github`, `betterleaks gitlab`) |
| S3/HuggingFace scanning | No | Yes |
| SARIF output | Yes | Yes |
| Baseline/allowlist | Yes | Yes |

## Pre-commit Hook

```bash
# Install
betterleaks install

# Or manually add to .git/hooks/pre-commit
cat > .git/hooks/pre-commit << 'EOF'
#!/usr/bin/env bash
betterleaks protect --staged --config .betterleaks.toml
EOF
chmod +x .git/hooks/pre-commit
```

## CI/CD (GitHub Actions)

```yaml
name: Secret Scan
on: [push, pull_request]
jobs:
  betterleaks:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 0
      - name: Run betterleaks
        uses: betterleaks/betterleaks-action@v1
        with:
          config: .betterleaks.toml
          report: betterleaks.sarif
      - name: Upload SARIF
        uses: github/codeql-action/upload-sarif@v3
        if: always()
        with:
          sarif_file: betterleaks.sarif
```

## Custom Rules

Same format as gitleaks. Add to `.betterleaks.toml`:

```toml
[[rules]]
  id = "custom-openrouter-key"
  description = "OpenRouter API key"
  regex = '''sk-or-[a-zA-Z0-9\-_]{64,}'''
  tags = ["api", "openrouter"]
  entropy = 4.5
  secret_group = 0
```

## Allowlist (Baseline)

```bash
# Generate baseline from current findings
betterleaks git --source . --report-format json --report-path report.json

# Create .betterleaks.toml with allowlist section
# Review report.json, add false positives to allowlist
```

## Auto-gitignore (one-liner)

```bash
betterleaks git --source . --no-banner --report-format json | jq -r '.[] | .file' | sort -u | sed 's|^\./||' | xargs -r -I{} sh -c 'grep -qxF "{}" .gitignore || echo "{}" >> .gitignore' && git add .gitignore
```

## Install Latest (one-liner)

```bash
curl -sSfL "https://github.com/betterleaks/betterleaks/releases/download/$(curl -s https://api.github.com/repos/betterleaks/betterleaks/releases/latest | grep -o '"tag_name": *"[^"]*"' | cut -d'\"' -f4)/betterleaks_$(curl -s https://api.github.com/repos/betterleaks/betterleaks/releases/latest | grep -o '"tag_name": *"[^"]*"' | cut -d'\"' -f4 | cut -c2-)_linux_x64.tar.gz" | tar -xz -C ~/.local/bin/ betterleaks && chmod +x ~/.local/bin/betterleaks
```

## Notes

- Config precedence: `--config` > `BETTERLEAKS_CONFIG` > `.betterleaks.toml` > `.gitleaks.toml` > defaults
- Accepts gitleaks config files directly (no migration needed)
- Validation requires `--validation` flag + `--validation-env-vars` for env var access
- `--no-banner` suppresses the ASCII art banner in CI
- Use `--redact` (0-100) to control secret redaction in output