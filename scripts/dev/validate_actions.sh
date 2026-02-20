#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

if command -v actionlint >/dev/null 2>&1; then
  actionlint
else
  echo "warning: actionlint not found; skipping workflow validation" >&2
fi

if command -v shellcheck >/dev/null 2>&1; then
  shell_files=$(
    find "$root_dir" \( -path "$root_dir/.git" -o -path "$root_dir/.venv" \) -prune -o \
      -type f \( -path "$root_dir/actions/*/scripts/*.sh" -o -path "$root_dir/scripts/*.sh" \) -print
  )
  if [ -n "$shell_files" ]; then
    echo "$shell_files" | xargs shellcheck
  fi
else
  echo "warning: shellcheck not found; skipping shell lint" >&2
fi
