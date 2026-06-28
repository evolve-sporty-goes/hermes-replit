# Verifying sensitive.txt Integrity

## When to use

After any edit to `sensitive.txt` (adding/removing entries), run a quick ad-hoc verification before committing. No canonical test suite exists for this file, so use a temporary script.

## Verification checklist

Create a temp script under `/tmp` with a `hermes-verify-` prefix, run it, then delete it:

```bash
cat > /tmp/hermes-verify-sensitive.sh << 'EOF'
#!/bin/bash
# 1. mail.txt must NOT be present
grep -q "mail.txt" /home/runner/workspace/sensitive.txt && { echo "FAIL: mail.txt present"; exit 1; }
# 2. All entries are absolute workspace paths
fail=0; while IFS= read -r p; do
    [ -z "$p" ] && continue
    [[ "$p" == /home/runner/workspace/* ]] || { echo "FAIL: $p"; fail=1; }
done < /home/runner/workspace/sensitive.txt
[ "$fail" -eq 0 ] || exit 1
# 3. All referenced files exist on disk
fail=0; while IFS= read -r p; do
    [ -z "$p" ] && continue
    [ -f "$p" ] || { echo "FAIL: missing $p"; fail=1; }
done < /home/runner/workspace/sensitive.txt
[ "$fail" -eq 0 ] || exit 1
# 4. No duplicates
[ -z "$(sort /home/runner/workspace/sensitive.txt | uniq -d)" ] || { echo "FAIL: duplicates"; exit 1; }
# 5. No empty lines
[ "$(grep -c '^$' /home/runner/workspace/sensitive.txt)" -eq 0 ] || { echo "FAIL: empty lines"; exit 1; }
# 6. sync.sh can parse all entries (basename extraction)
fail=0; while IFS= read -r p; do
    [ -z "$p" ] && continue
    bf=$(basename "$p"); [ -z "$bf" ] && { echo "FAIL: empty basename for $p"; fail=1; }
done < /home/runner/workspace/sensitive.txt
[ "$fail" -eq 0 ] || exit 1
echo "ALL PASSED"
EOF
bash /tmp/hermes-verify-sensitive.sh
rm -f /tmp/hermes-verify-sensitive.sh
```

## Why ad-hoc?

`sensitive.txt` is a simple path list — no linter or build tool validates it. The verification is mechanical (existence, format, uniqueness) so a throwaway bash script is the right tool. Don't over-engineer this into a permanent test suite.
