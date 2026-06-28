# Verification Patterns for Ad-Hoc Checks

When a task produces a non-code artifact (markdown note, config file, static document) and the system asks for verification, write a focused bash script and run it — but generate it safely.

## The Pitfall: Shell Quoting in Generated Scripts

Generating bash from `python3 -c` or `terminal(heredoc)` hits escaping issues fast. Signs you're in this trap:

- `command not found` on lines that look correct
- `$variables` expanded at write-time instead of runtime
- Quotes eating each other (`echo "  OK: name"` → breaks when name has special chars)
- Multiple rewrite attempts on the same verification script

## The Fix: Use `execute_code` + `tempfile` + Explicit String Construction

```python
import tempfile, os
from hermes_tools import terminal

path = '/some/file.md'
content = open(path).read()
checks = [
    ('file exists', os.path.isfile(path)),
    ('non-empty', len(content) > 0),
    ('has heading', 'Session Notes' in content),
]

fd, tmp = tempfile.mkstemp(prefix='hermes-verify-', dir='/tmp', suffix='.sh')
lines = ['#!/usr/bin/env bash', 'set -e']
lines.append(f'echo "Verification: {path}"')
lines.append('')
for name, ok in checks:
    status = 'OK' if ok else 'FAIL'
    lines.append(f'echo "  {status}: {name}"')
    lines.append(f'if [ "{status}" != "OK" ]; then echo "CHECK FAILED: {name}"; exit 1; fi')
lines.append(f'echo "all {len(checks)} checks passed"')
script = '\n'.join(lines) + '\n'

with os.fdopen(fd, 'w') as f:
    f.write(script)
os.chmod(tmp, 0o755)

res = terminal(f'bash {tmp}')
print(res['output'])
terminal(f'rm -f {tmp}')
```

### Why this works

- Python string `.format()` / f-string handles quoting — no shell interpolation
- `tempfile.mkstemp` gives a safe, unique path without race conditions
- Write the script body as a Python list of lines → no escaping needed
- The resulting bash script is clean, readable, and debuggable

## Anti-patterns (DO NOT)

| Approach | Why it fails |
|----------|--------------|
| `python3 -c "print('echo hello')"` | Nested quotes collapse |
| `terminal('bash -c "... $var ..."')` | `$var` expanded by shell before bash sees it |
| `terminal('bash << 'EOF' ... EOF')` inside python string | Heredoc inside string literal — ordering confusion |
| Writing the script with `write_file` then `patch` to fix one line | Wastes tool calls; just verify with `execute_code` inline |
| `find ... -mmin -5 -delete` for cleanup | Security scan blocks `-delete`; use `rm -f` explicitly |

## When Ad-Hoc Verification Applies

- Static files (markdown, config, JSON, YAML) where no test suite exists
- One-shot file-creation tasks where the system prompts for confirmation
- Boundary checks: "does the file exist, is it non-empty, does it have expected content"

When it does NOT apply:
- Application code with a test suite → run the test suite
- Lintable files (Python, JS) → use the project's linter
- Build artifacts → run the build

## Naming Convention

Temp scripts: `/tmp/hermes-verify-<random>.sh`

The `hermes-verify-` prefix makes them identifiable. Always clean up after (`rm -f`).
