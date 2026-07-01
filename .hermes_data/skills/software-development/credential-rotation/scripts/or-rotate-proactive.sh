#!/usr/bin/env bash
# Proactive OpenRouter rotation — checks quota at threshold (default 80%)
# Usage: or-rotate-proactive "prompt" [model] [threshold_pct]

KEYS_FILE="$HOME/.config/openrouter/keys.txt"
STATE_FILE="$HOME/.config/openrouter/state.json"
MODEL="${2:-nvidia/nemotron-3-ultra-550b-a55b:free}"
THRESHOLD="${3:-80}"

mkdir -p "$(dirname "$KEYS_FILE")" "$(dirname "$STATE_FILE")"
[[ -f "$KEYS_FILE" ]] || { echo "Create $KEYS_FILE with one key per line" >&2; exit 1; }
[[ -f "$STATE_FILE" ]] || echo '{"idx":0}' > "$STATE_FILE"

mapfile -t KEYS < "$KEYS_FILE"
IDX=$(jq -r '.idx // 0' "$STATE_FILE")

check_quota() {
  local key="$1"
  curl -s -H "Authorization: Bearer $key" https://openrouter.ai/api/v1/auth/key |
    jq -r '.data | "\(.usage) \(.limit)"'
}

for i in $(seq 0 $((${#KEYS[@]}-1))); do
  TRY=$(( (IDX + i) % ${#KEYS[@]} ))
  KEY="${KEYS[$TRY]}"
  read -r USAGE LIMIT <<<"$(check_quota "$KEY")"
  [[ -z "$USAGE" || -z "$LIMIT" || "$LIMIT" == "0" ]] && continue
  PCT=$(( USAGE * 100 / LIMIT ))
  (( PCT < THRESHOLD )) && break
done

RESPONSE=$(curl -s -w "\n%{http_code}" \
  -H "Authorization: Bearer $KEY" \
  -H "Content-Type: application/json" \
  -d "{\"model\":\"$MODEL\",\"messages\":[{\"role\":\"user\",\"content\":\"$1\"}],\"stream\":false}" \
  https://openrouter.ai/api/v1/chat/completions)

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