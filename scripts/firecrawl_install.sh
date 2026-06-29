#!/bin/bash
npm install -g firecrawl-cli@1.19.6
source /home/runner/workspace/.hermes_data/.env && firecrawl login --api-key "$FIRECRAWL_API_KEY"
echo "Done: $(firecrawl --version), credits: $(firecrawl --status 2>&1 | grep Credits)"
