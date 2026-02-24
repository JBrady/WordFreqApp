#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: scripts/ops/acs_log.sh \"message...\"" >&2
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
JOURNAL_FILE="$ROOT_DIR/.ops/journal.md"
TS="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
MSG="$*"

mkdir -p "$ROOT_DIR/.ops"
if [[ ! -f "$JOURNAL_FILE" ]]; then
  echo "# A.C.S. Journal" > "$JOURNAL_FILE"
fi

FIRST_LINE="${MSG%%$'\n'*}"
{
  echo "- [$TS] $FIRST_LINE"
  REMAINDER="${MSG#"$FIRST_LINE"}"
  if [[ "$REMAINDER" != "$MSG" ]]; then
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      echo "  $line"
    done <<< "$REMAINDER"
  fi
} >> "$JOURNAL_FILE"

echo "Journal appended."
