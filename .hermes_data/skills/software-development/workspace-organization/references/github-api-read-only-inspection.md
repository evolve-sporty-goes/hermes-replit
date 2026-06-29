# GitHub API Read-Only Inspection (No Auth Required)

When `gh auth` is unavailable or the token isn't set, you can still inspect public repos via the GitHub REST API without authentication. This is useful for understanding repo structure before writing documentation or making changes.

## Common Patterns

### Repo Metadata

```bash
curl -s https://api.github.com/repos/owner/repo | python3 -c "
import sys, json
r = json.load(sys.stdin)
print('name:', r.get('full_name'))
print('description:', r.get('description'))
print('language:', r.get('language'))
print('default_branch:', r.get('default_branch'))
print('topics:', r.get('topics'))
"
```

### List Directory Contents

```bash
curl -s https://api.github.com/repos/owner/repo/contents/path | python3 -c "
import sys, json
items = json.load(sys.stdin)
for i in items:
    print(f\"{i['type']:4} {i['name']}\")
"
```

### Read a File (Base64 Encoded)

```bash
curl -s https://api.github.com/repos/owner/repo/contents/path/to/file | python3 -c "
import sys, json, base64
r = json.load(sys.stdin)
print(base64.b64decode(r['content']).decode())
"
```

### Get Default Branch SHA

```bash
curl -s https://api.github.com/repos/owner/repo/git/refs/heads/main | python3 -c "
import sys, json
r = json.load(sys.stdin)
print(r['object']['sha'])
"
```

## When to Use This

- `gh` is installed but not authenticated (common in Replit, ephemeral envs)
- You need read-only access to understand repo structure
- You're writing a README or documentation and need to know what files exist
- You want to read `.replit`, `.gitignore`, or config files to understand the project

## Limitations

- Rate limit: 60 requests/hour without auth (vs 5000 with token)
- Private repos require authentication
- Cannot create/modify files (use git push or API with token for writes)
