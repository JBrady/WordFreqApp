#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<USAGE
Usage:
  $0 --app /path/to/WordFreqApp.app --keychain-profile PROFILE [--dmg]

Required:
  --app               Path to signed .app bundle
  --keychain-profile  notarytool keychain profile name

Optional:
  --dmg               Build DMG after stapling app
USAGE
}

APP_PATH=""
PROFILE=""
BUILD_DMG="false"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --app)
      APP_PATH="$2"
      shift 2
      ;;
    --keychain-profile)
      PROFILE="$2"
      shift 2
      ;;
    --dmg)
      BUILD_DMG="true"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1"
      usage
      exit 1
      ;;
  esac
done

if [[ -z "$APP_PATH" || -z "$PROFILE" ]]; then
  usage
  exit 1
fi

if [[ ! -d "$APP_PATH" ]]; then
  echo "App not found: $APP_PATH"
  exit 1
fi

APP_BASENAME="$(basename "$APP_PATH" .app)"
WORK_DIR="$(mktemp -d)"
ZIP_PATH="$WORK_DIR/${APP_BASENAME}.zip"

cleanup() {
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

echo "Zipping app..."
ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"

echo "Submitting to notarization..."
xcrun notarytool submit "$ZIP_PATH" --keychain-profile "$PROFILE" --wait

echo "Stapling ticket to app..."
xcrun stapler staple "$APP_PATH"

echo "Notarization and stapling complete for: $APP_PATH"

if [[ "$BUILD_DMG" == "true" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  "$SCRIPT_DIR/dmg.sh" "$APP_PATH" "${APP_BASENAME}.dmg"
fi
