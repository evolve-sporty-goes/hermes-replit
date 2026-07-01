#!/usr/bin/env bash
# Scan with betterleaks + auto-gitignore detected files
# Usage: betterleaks-gitignore.sh [repo_path]

REPO="${1:-.}"
betterleaks git "$REPO" --no-banner --report-format json |
  jq -r '.[] | .File' |
  sort -u |
  sed 's|^\./||' |
  xargs -r -I{} sh -c 'grep -qxF "{}" .gitignore || echo "{}" >> .gitignore' &&
  git add .gitignore