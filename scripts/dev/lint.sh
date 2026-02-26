#!/usr/bin/env bash
set -euo pipefail
# Tier 1 — Lint

echo "--- actionlint ---"
actionlint

echo "--- shellcheck ---"
files=$(find ./scripts/bin -type f 2>/dev/null)
if [ -n "$files" ]; then
  echo "$files" | xargs shellcheck
else
  echo "No shell scripts found."
fi
