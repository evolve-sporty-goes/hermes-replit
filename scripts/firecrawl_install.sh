#!/usr/bin/env bash
while : 
do fKEY=$(grep -E '^API_KEY=fc-' /home/runner/workspace/credentials/firecrawl_credentials.txt | shuf -n 1 | sed 's/API_KEY=//')
sed -i "s|^FIRECRAWL_API_KEY=.*|FIRECRAWL_API_KEY=$fKEY|" /home/runner/workspace/.hermes_data/.env
#echo "Updated to: $(grep FIRECRAWL_API_KEY /home/runner/workspace/.hermes_data/.env)"
oKEY=$(grep -E '^API_KEY=sk-or-v1-' /home/runner/workspace/credentials/openrouter_credentials.txt | shuf -n 1 | sed 's/API_KEY=//')
sed -i "s|^OPENROUTER_API_KEY=.*|OPENROUTER_API_KEY=$oKEY|" /home/runner/workspace/.hermes_data/.env
#echo "Updated to: $(grep OPENROUTER_API_KEY /home/runner/workspace/.hermes_data/.env)"
sleep 120
done &

export DISPLAY=:1
bash scripts/email.sh
openrouter_signup.sh
firecrawl_signup.sh
nvm install node
command -v firecrawl  >/dev/null 2>&1 ||sudo npm install -g firecrawl-cli
source /home/runner/workspace/.hermes_data/.env && firecrawl login --api-key "$FIRECRAWL_API_KEY"
echo "Done: $(firecrawl --version), credits: $(firecrawl --status 2>&1 | grep Credits)"
