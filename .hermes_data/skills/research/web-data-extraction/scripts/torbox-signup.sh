#!/usr/bin/env bash
# torbox-signup.sh — Create TorBox account. Uses email.sh for email, auto-generates password.
# Output: torbox_credentials.txt
set -euo pipefail

EMAIL=$(bash /home/runner/workspace/email.sh)
PW=$(python3 << 'PY'
import secrets,string as s
L,U,D=s.ascii_lowercase,s.ascii_uppercase,s.digits
Y='!@#$%^&*()_+-=[]{};<>?/`~'
pw=[secrets.choice(L),secrets.choice(U),secrets.choice(D),secrets.choice(Y)]
pw+=[secrets.choice(L+U+D+Y) for _ in range(16)]
secrets.SystemRandom().shuffle(pw);print(''.join(pw))
PY
)

echo "Signing up $EMAIL ..."
B=$(curl -s -X POST "https://db.torbox.app/auth/v1/signup" \
  -H 'Content-Type: application/json' \
  -H "apikey: $(grep SUPABASE_ANON_KEY /home/runner/workspace/.hermes_data/.env 2>/dev/null | tr -d '\r' | cut -d= -f2- || echo '')" \
  -d "{\"email\":\"$EMAIL\",\"password\":\"$PW\"}")
E=$(echo "$B"|python3 -c "import sys,json;d=json.load(sys.stdin);print(d.get('msg',d.get('error_description','')))" 2>/dev/null||true)
[[ -n "$E" ]] && { echo "✗ $E"; exit 1; }
ID=$(echo "$B"|python3 -c "import sys,json;print(json.load(sys.stdin).get('id','?'))" 2>/dev/null||echo "?")
echo "✓ $EMAIL | $PW | $ID"
echo "email=$EMAIL" > torbox_credentials.txt
echo "password=$PW" >> torbox_credentials.txt
echo "user_id=$ID" >> torbox_credentials.txt
