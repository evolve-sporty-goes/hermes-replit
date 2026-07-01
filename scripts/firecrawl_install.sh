#!/usr/bin/env bash
export DISPLAY=:1
fKEY=$(grep -E '^API_KEY=fc-' /home/runner/workspace/credentials/firecrawl_credentials.txt | shuf -n 1 | sed 's/API_KEY=//')
sed -i "s|^FIRECRAWL_API_KEY=.*|FIRECRAWL_API_KEY=$fKEY|" /home/runner/workspace/.hermes_data/.env
echo "Updated to: $(grep FIRECRAWL_API_KEY /home/runner/workspace/.hermes_data/.env)"
oKEY=$(grep -E '^API_KEY=sk-or-v1-' /home/runner/workspace/credentials/openrouter_credentials.txt | shuf -n 1 | sed 's/API_KEY=//')
sed -i "s|^OPENROUTER_API_KEY=.*|OPENROUTER_API_KEY=$oKEY|" /home/runner/workspace/.hermes_data/.env
oAPI_KEY=$(grep OPENROUTER_API_KEY /home/runner/workspace/.hermes_data/.env | sed 's/OPENROUTER_API_KEY=//')
echo "Updated to: $(grep OPENROUTER_API_KEY /home/runner/workspace/.hermes_data/.env)"
curl -sS -H "Authorization: Bearer ${oAPI_KEY}" https://openrouter.ai/api/v1/auth/key | python3 -m json.tool
curl -sS -H "Authorization: Bearer ${oAPI_KEY}" https://openrouter.ai/api/v1/auth/key | python3 -c 'import sys,json; print(json.load(sys.stdin)["data"]["usage"])'
bash scripts/email.sh
openrouter_signup.sh
firecrawl_signup.sh
nvm install node
command -v firecrawl  >/dev/null 2>&1 ||sudo npm install -g firecrawl-cli
source /home/runner/workspace/.hermes_data/.env && firecrawl login --api-key "$FIRECRAWL_API_KEY"
echo "Done: $(firecrawl --version), credits: $(firecrawl --status 2>&1 | grep Credits)"
