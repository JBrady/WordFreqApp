#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<USAGE
Usage:
  $0 --file <path-to-app-or-dmg> [--profile AC_PROFILE]

Examples:
  $0 --file ./.build/release/WordFreqApp/WordFreqApp.app
  $0 --file ./.build/WordFreqApp.dmg --profile AC_PROFILE
USAGE
}

FILE_PATH=""
PROFILE="${NOTARY_PROFILE:-AC_PROFILE}"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --file)
      FILE_PATH="$2"
      shift 2
      ;;
    --profile)
      PROFILE="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -z "$FILE_PATH" ]]; then
  usage
  exit 1
fi

if [[ ! -e "$FILE_PATH" ]]; then
  echo "File not found: $FILE_PATH" >&2
  exit 1
fi

if ! xcrun notarytool history --keychain-profile "$PROFILE" >/dev/null 2>&1; then
  cat <<INSTRUCTIONS >&2
Missing notarytool keychain profile: $PROFILE
Create it with:
  xcrun notarytool store-credentials "$PROFILE" --apple-id "<APPLE_ID>" --team-id "<TEAM_ID>" --password "<APP_SPECIFIC_PASSWORD>"
INSTRUCTIONS
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP_DIR="$(mktemp -d)"
cleanup() {
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

SUBMIT_PATH="$FILE_PATH"
if [[ -d "$FILE_PATH" && "${FILE_PATH##*.}" == "app" ]]; then
  APP_BASENAME="$(basename "$FILE_PATH" .app)"
  SUBMIT_PATH="$TMP_DIR/${APP_BASENAME}.zip"
  echo "==> Zipping app for notarization"
  ditto -c -k --keepParent "$FILE_PATH" "$SUBMIT_PATH"
fi

echo "==> Submitting to notarytool"
xcrun notarytool submit "$SUBMIT_PATH" --keychain-profile "$PROFILE" --wait

echo "==> Stapling"
xcrun stapler staple "$FILE_PATH"

echo "==> Validating staple"
xcrun stapler validate "$FILE_PATH"

echo "Notarization complete: $FILE_PATH"
