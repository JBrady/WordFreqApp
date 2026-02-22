#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 || $# -gt 2 ]]; then
  echo "Usage: $0 /path/to/WordFreqApp.app [output.dmg]"
  exit 1
fi

APP_PATH="$1"
OUTPUT_DMG="${2:-WordFreqApp.dmg}"
APP_NAME="$(basename "$APP_PATH")"
VOLUME_NAME="WordFreqApp"
TMP_DIR="$(mktemp -d)"
STAGE_DIR="$TMP_DIR/dmg-root"

mkdir -p "$STAGE_DIR"
cp -R "$APP_PATH" "$STAGE_DIR/"
ln -s /Applications "$STAGE_DIR/Applications"

hdiutil create \
  -volname "$VOLUME_NAME" \
  -srcfolder "$STAGE_DIR" \
  -ov \
  -format UDZO \
  "$OUTPUT_DMG"

rm -rf "$TMP_DIR"

echo "Created DMG: $OUTPUT_DMG"
