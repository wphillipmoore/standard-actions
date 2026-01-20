#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

if command -v markdownlint >/dev/null 2>&1; then
  mapfile -t markdown_files < <(
    find "$root_dir" \( -path "$root_dir/.git" -o -path "$root_dir/.venv" \) -prune -o \
      -type f \( -path "$root_dir/docs/*.md" -o -path "$root_dir/docs/**/*.md" -o -path "$root_dir/README.md" \) -print
  )
  if [ "${#markdown_files[@]}" -gt 0 ]; then
    markdownlint "${markdown_files[@]}"
  fi
else
  echo "warning: markdownlint not found; skipping markdown lint" >&2
fi
