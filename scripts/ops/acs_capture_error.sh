#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "Usage: scripts/ops/acs_capture_error.sh <label> <command...>" >&2
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
LABEL_RAW="$1"
shift

SAFE_LABEL="$(echo "$LABEL_RAW" | tr -cs 'A-Za-z0-9._-' '_')"
LOG_FILE="$ROOT_DIR/.artifacts/${SAFE_LABEL}.log"
REL_LOG_FILE=".artifacts/${SAFE_LABEL}.log"
mkdir -p "$ROOT_DIR/.artifacts"

set +e
"$@" > "$LOG_FILE" 2>&1
RC=$?
set -e

if [[ "$RC" -ne 0 ]]; then
  "$ROOT_DIR/scripts/ops/acs_update_status.sh" last_error "$REL_LOG_FILE" >/dev/null
  echo "ERROR: command failed ($RC). Log: $LOG_FILE" >&2
else
  echo "OK: $LABEL_RAW (log: $LOG_FILE)"
fi

exit "$RC"
