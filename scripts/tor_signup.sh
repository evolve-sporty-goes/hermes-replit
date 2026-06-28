#!/usr/bin/env bash
set -euo pipefail
ANON_KEY=$(cat /home/runner/workspace/credentials/.supabase_anon_key)
curl --socks5-hostname 127.0.0.1:9050 -s -X POST \
  'https://db.torbox.app/auth/v1/signup' \
  -H 'Content-Type: application/json' \
  -H "apikey: $ANON_KEY" \
  -d '{"email":"bavmin+faltu2@proton.me","password":"Satyana@1234"}'
