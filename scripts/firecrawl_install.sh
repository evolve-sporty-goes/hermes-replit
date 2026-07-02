#!/usr/bin/env bash
hermes config set model.provider openrouter
hermes config set model.default  nvidia/nemotron-3-ultra-550b-a55b:free
hermes config set fallback_model.provider kilo-code
hermes config set fallback_model.model kilo-auto/free
while : 
do fKEY=$(grep -E '^API_KEY=fc-' /home/runner/workspace/credentials/firecrawl_credentials.txt | shuf -n 1 | sed 's/API_KEY=//')
sed -i "s|^FIRECRAWL_API_KEY=.*|FIRECRAWL_API_KEY=$fKEY|" /home/runner/workspace/.hermes_data/.env
#echo "Updated to: $(grep FIRECRAWL_API_KEY /home/runner/workspace/.hermes_data/.env)"
oKEY=$(grep -E '^API_KEY=sk-or-v1-' /home/runner/workspace/credentials/openrouter_credentials.txt | shuf -n 1 | sed 's/API_KEY=//')
sed -i "s|^OPENROUTER_API_KEY=.*|OPENROUTER_API_KEY=$oKEY|" /home/runner/workspace/.hermes_data/.env
#echo "Updated to: $(grep OPENROUTER_API_KEY /home/runner/workspace/.hermes_data/.env)"
~/hermes-webui/ctl.sh restart
sync
sleep 500
done &
while :
do openrouter_signup.sh
sleep 300
firecrawl_signup.sh
sleep 300
done &
nvm install node
command -v firecrawl  >/dev/null 2>&1 ||sudo npm install -g firecrawl-cli
source /home/runner/workspace/.hermes_data/.env && firecrawl login --api-key "$FIRECRAWL_API_KEY"
echo "Done: $(firecrawl --version), credits: $(firecrawl --status 2>&1 | grep Credits)"

# pkill -f ~/workspace/firecrawl_install.sh