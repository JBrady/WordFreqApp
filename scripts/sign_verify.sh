#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 /path/to/WordFreqApp.app"
}

if [[ $# -ne 1 ]]; then
  usage
  exit 1
fi

APP_PATH="$1"

if [[ ! -d "$APP_PATH" ]]; then
  echo "App not found: $APP_PATH" >&2
  exit 1
fi

echo "==> codesign --verify"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"

echo "\n==> codesign details"
codesign -dv --verbose=4 "$APP_PATH" 2>&1 | rg "Authority|TeamIdentifier|Runtime Version|Identifier"

echo "\n==> entitlements"
ENTITLEMENTS="$(codesign -d --entitlements :- "$APP_PATH" 2>/dev/null || true)"
echo "$ENTITLEMENTS"

if echo "$ENTITLEMENTS" | rg -q "com.apple.security.get-task-allow"; then
  NORMALIZED_ENTITLEMENTS="$(echo "$ENTITLEMENTS" | tr -d '[:space:]')"
  if echo "$NORMALIZED_ENTITLEMENTS" | rg -q "<key>com.apple.security.get-task-allow</key><true/>"; then
    echo "ERROR: get-task-allow is true" >&2
    exit 1
  fi
  echo "get-task-allow present but not true"
else
  echo "get-task-allow absent"
fi

echo "\n==> spctl assessment"
if spctl --assess --type execute --verbose=4 "$APP_PATH"; then
  echo "spctl assessment passed"
else
  echo "spctl assessment did not pass (expected before notarization/stapling)" >&2
fi
