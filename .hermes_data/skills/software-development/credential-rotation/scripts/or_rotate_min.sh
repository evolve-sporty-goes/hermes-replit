#!/usr/bin/env bash
# Minimal OpenRouter proactive rotation
# Usage: or_rotate_min.sh "prompt" [model]

CREDS_FILE="/home/runner/workspace/credentials/openrouter_credentials.txt"
STATE_FILE="/home/runner/.hermes_data/or_state.json"
MODEL="${2:-nvidia/nemotron-3-ultra-550b-a55b:free}"
THRESHOLD=0.80

mapfile -t KEYS < <(grep -o 'sk-or-[^ ]*' "$CREDS_FILE")
[[ ${#KEYS[@]} -eq 0 ]] && { echo "No keys found in $CREDS_FILE" >&2; exit 1; }

[[ -f "$STATE_FILE" ]] || echo '{"idx":0}' > "$STATE_FILE"
IDX=$(jq -r '.idx' < "$STATE_FILE")

for i in $(seq 0 $((${#KEYS[@]}-1))); do
  TRY=$(( (IDX + i) % ${#KEYS[@]} ))
  KEY="${KEYS[$TRY]}"
  
  AUTH=$(curl -s -H "Authorization: Bearer $KEY" https://openrouter.ai/api/v1/auth/key)
  LIMIT=$(jq -r '.data.limit // 0' <<<"$AUTH")
  USAGE=$(jq -r '.data.usage // 0' <<<"$AUTH")
  
  [[ $LIMIT -eq 0 ]] && continue
  awk -v u="$USAGE" -v l="$LIMIT" -v t="$THRESHOLD" 'BEGIN { exit (u/l >= t) }' }' && break
done

RESPONSE=$(curl -s -w "\n%{http_code}" \
  -H "Authorization: Bearer $KEY" \
  -H "Content-Type: application/json" \
  -d "{\"model\":\"$MODEL\",\"messages\":[{\"role\":\"user\",\"content\":\"$1\"}],\"stream\":false}" \
  "https://openrouter.ai/api/v1/chat/completions")

HTTP_CODE=$(tail -n1 <<<"$RESPONSE")
BODY=$(head -n-1 <<<"$RESPONSE")

if [[ "$HTTP_CODE" == "200" ]]; then
  NEW_IDX=$(( (TRY + 1) % ${#KEYS[@]} ))
  jq -n --argjson idx "$NEW_IDX" '{idx:$idx}' > "$STATE_FILE"
  echo "$BODY" | jq -r '.choices[0].message.content'
else
  echo "Error $HTTP_CODE: $BODY" >&2
  exit 1
fi