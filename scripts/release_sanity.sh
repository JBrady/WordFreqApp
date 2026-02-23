#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA_PATH="$ROOT_DIR/.build/release-sanity"
APP_PATH="$DERIVED_DATA_PATH/Build/Products/Release/WordFreqApp.app"
DEVELOPMENT_TEAM_ARG=()
CODE_SIGN_IDENTITY_ARG=()

if [[ -n "${DEVELOPMENT_TEAM:-}" ]]; then
  DEVELOPMENT_TEAM_ARG=("DEVELOPMENT_TEAM=${DEVELOPMENT_TEAM}")
fi

if [[ -n "${CODE_SIGN_IDENTITY:-}" ]]; then
  CODE_SIGN_IDENTITY_ARG=("CODE_SIGN_IDENTITY=${CODE_SIGN_IDENTITY}")
fi

cd "$ROOT_DIR"

echo "==> Building Release app"
xcodebuild \
  -project WordFreqApp.xcodeproj \
  -scheme WordFreqApp \
  -configuration Release \
  -destination 'platform=macOS' \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  "${DEVELOPMENT_TEAM_ARG[@]}" \
  "${CODE_SIGN_IDENTITY_ARG[@]}" \
  build || {
    echo >&2
    echo "Release build failed. If signing is not configured, retry with:" >&2
    echo "  DEVELOPMENT_TEAM=<TEAM_ID> CODE_SIGN_IDENTITY='Developer ID Application' scripts/release_sanity.sh" >&2
    exit 1
  }

if [[ ! -d "$APP_PATH" ]]; then
  echo "Release app not found at: $APP_PATH" >&2
  exit 1
fi

echo "\n==> Entitlements"
codesign -d --entitlements :- "$APP_PATH" 2>/dev/null | cat

echo "\n==> Signature details"
codesign -dv "$APP_PATH" 2>&1 | rg "Authority|TeamIdentifier|Runtime Version|Identifier"

echo "\n==> Quick checks"
if codesign -d --entitlements :- "$APP_PATH" 2>/dev/null | rg -q "com.apple.security.get-task-allow"; then
  if codesign -d --entitlements :- "$APP_PATH" 2>/dev/null | rg -q "<true/>"; then
    echo "WARNING: get-task-allow appears enabled in release entitlements" >&2
    exit 1
  fi
  echo "get-task-allow present but not true"
else
  echo "get-task-allow absent"
fi

if codesign -dv "$APP_PATH" 2>&1 | rg -q "Authority=Developer ID Application"; then
  echo "Developer ID Application authority detected"
else
  echo "WARNING: Developer ID Application authority not detected" >&2
fi

if codesign -dv "$APP_PATH" 2>&1 | rg -q "Runtime Version"; then
  echo "Hardened runtime detected"
else
  echo "WARNING: Hardened runtime not detected" >&2
fi
