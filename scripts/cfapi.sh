#!/usr/bin/env bash
set -euo pipefail
CRED="${WORKSPACE:-$HOME/workspace}/credentials/cloudflare.txt"
mkdir -p "$(dirname "$CRED")"
touch "$CRED"
python3 -c "import re,random; text=open('$CRED').read(); blocks=[b.strip() for b in re.split(r'\n\s*\n', text) if b.strip()]; random.shuffle(blocks); open('$CRED','w').write('\n\n'.join(blocks)+'\n\n')"

[[ -f "$CRED" ]] || { echo "No $CRED"; exit 1; }

mapfile -t L < <(grep -v '^[[:space:]]*$' "$CRED")
N=$((${#L[@]} / 2))
I=$((RANDOM % N * 2))
A=$(echo "${L[$I]}" | cut -d= -f2)
K=$(echo "${L[$((I+1))]}" | cut -d= -f2)
U="https://api.cloudflare.com/client/v4/accounts/${A}/ai/v1"

echo "Using: ${A:0:8}..."
hermes config set model.provider custom
hermes config set model.base_url "$U"
hermes config set model.api_key "$K"
hermes config set model.api_compat openai
hermes config set model.default "@cf/moonshotai/kimi-k2.7-code"
hermes config set model.display_name "cloudflare"
cloudflare_signup.sh
sync
#hermes config set fallback_model.provider  openrouter
#hermes config set fallback_model.model nvidia/nemotron-3-ultra-550b-a55b:free
#hermes config set fallback_model.provider kilo-code
#hermes config set fallback_model.model kilo-auto/free
echo "Done."
