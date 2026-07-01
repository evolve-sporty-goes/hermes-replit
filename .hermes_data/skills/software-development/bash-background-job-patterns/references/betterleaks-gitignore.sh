#!/usr/bin/env bash
# Secret scan + auto-gitignore pattern using betterleaks
# Usage: ./betterleaks-gitignore.sh

betterleaks git . --no-banner --report-format json \
  | jq -r '.[] | .File' \
  | sort -u \
  | sed 's|^\./||' \
  | xargs -r -I{} sh -c 'grep -qxF "{}" .gitignore || echo "{}" >> .gitignore' \
  && git add .gitignore