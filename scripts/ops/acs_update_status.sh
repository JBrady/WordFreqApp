#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: scripts/ops/acs_update_status.sh <key> <value>" >&2
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
STATUS_FILE="$ROOT_DIR/.ops/status.json"
KEY="$1"
VALUE="$2"
NOW="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
TMP_FILE="$(mktemp "$ROOT_DIR/.ops/status.json.tmp.XXXXXX")"

if [[ ! -f "$STATUS_FILE" ]]; then
  echo "{}" > "$STATUS_FILE"
fi

if command -v jq >/dev/null 2>&1; then
  jq --arg key "$KEY" --arg value "$VALUE" --arg now "$NOW" '.[$key]=$value | .last_update=$now' "$STATUS_FILE" > "$TMP_FILE"
else
  python3 - "$STATUS_FILE" "$TMP_FILE" "$KEY" "$VALUE" "$NOW" <<'PY'
import json
import pathlib
import sys

status_path = pathlib.Path(sys.argv[1])
out_path = pathlib.Path(sys.argv[2])
key = sys.argv[3]
value = sys.argv[4]
now = sys.argv[5]

try:
    data = json.loads(status_path.read_text())
    if not isinstance(data, dict):
        data = {}
except Exception:
    data = {}

data[key] = value
data["last_update"] = now
out_path.write_text(json.dumps(data, indent=2) + "\n")
PY
fi

mv "$TMP_FILE" "$STATUS_FILE"
echo "Updated status: $KEY=$VALUE"
