# BetterLeaks + Auto-Gitignore Pattern

## One-Liner: Scan + Auto-Gitignore + Stage

```bash
betterleaks git . --no-banner --report-format json |
  jq -r '.[] | .File' |
  sort -u |
  sed 's|^\./||' |
  xargs -r -I{} sh -c 'grep -qxF "{}" .gitignore || echo "{}" >> .gitignore' &&
  git add .gitignore
```

## Why BetterLeaks Over Gitleaks

- User preference: `betterleaks` (installed at `~/.pythonlibs/bin/betterleaks`)
- Faster, fewer false positives
- JSON output with `.File` field (capital F)
- `git` subcommand takes repo path as positional arg (`.`) not `--source .`

## Installation Script

```bash
#!/usr/bin/env bash
# scripts/betterleaks.sh — install latest + usage

VERSION=$(curl -s https://api.github.com/repos/betterleaks/betterleaks/releases/latest | jq -r .tag_name)
curl -L "https://github.com/betterleaks/betterleaks/releases/download/${VERSION}/betterleaks_${VERSION#v}_linux_amd64.tar.gz" |
  tar -xz -C ~/.pythonlibs/bin betterleaks
chmod +x ~/.pythonlibs/bin/betterleaks
```

## Pre-Commit Hook

```bash
echo 'betterleaks git . --no-banner --report-format json | jq -r ".[] | .File" | sort -u | sed "s|^\./||" | xargs -r -I{} sh -c "grep -qxF \"{}\" .gitignore || echo \"{}\" >> .gitignore" && git add .gitignore' > .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
```

## Allowlist Config (`.gitleaks.toml`)

```toml
[allowlist]
paths = [
  ".hermes_data/**",
  "credentials/**",
  "scripts/email.sh",
  "*.log",
  "*.shm",
  "*.wal",
]
```

## Files Created This Session

| File | Purpose |
|------|---------|
| `scripts/betterleaks.sh` | Install latest betterleaks |
| `scripts/betterleaks-gitignore.sh` | One-liner scan + auto-gitignore (executable) |
| `.gitleaks.toml` | Allowlist config for hermes/credentials dirs |