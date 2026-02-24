#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OPS_DIR="$ROOT_DIR/.ops"
ART_DIR="$ROOT_DIR/.artifacts"

mkdir -p "$OPS_DIR" "$OPS_DIR/templates" "$ART_DIR"

STATUS_FILE="$OPS_DIR/status.json"
if [[ ! -f "$STATUS_FILE" ]]; then
  ts="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  cat > "$STATUS_FILE" <<JSON
{
  "build_release": "unknown",
  "dmg_packaging": "unknown",
  "dmg_opens": "unknown",
  "app_launch_local": "unknown",
  "vm_boot_monterey": "unknown",
  "app_launch_on_vm": "unknown",
  "last_error": "",
  "last_update": "$ts"
}
JSON
  echo "Created $STATUS_FILE"
else
  echo "Exists  $STATUS_FILE"
fi

JOURNAL_FILE="$OPS_DIR/journal.md"
if [[ ! -f "$JOURNAL_FILE" ]]; then
  cat > "$JOURNAL_FILE" <<'MD'
# A.C.S. Journal
MD
  echo "Created $JOURNAL_FILE"
else
  echo "Exists  $JOURNAL_FILE"
fi

KEEP_FILE="$ART_DIR/.keep"
if [[ ! -f "$KEEP_FILE" ]]; then
  echo "# keep" > "$KEEP_FILE"
  echo "Created $KEEP_FILE"
else
  echo "Exists  $KEEP_FILE"
fi

echo "A.C.S init complete (non-destructive)."
