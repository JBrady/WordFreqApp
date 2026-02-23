#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH="${1:-$ROOT_DIR/.build/release/WordFreqApp/WordFreqApp.app}"
DMG_PATH="${2:-$ROOT_DIR/.build/WordFreqApp.dmg}"

if [[ ! -d "$APP_PATH" ]]; then
  echo "App not found: $APP_PATH" >&2
  echo "Build it first: ./scripts/build_release.sh" >&2
  exit 1
fi

"$ROOT_DIR/scripts/make_dmg.sh" "$APP_PATH" "$DMG_PATH"

ATTACH_OUTPUT="$(hdiutil attach -nobrowse -readonly "$DMG_PATH")"
MOUNT_POINT="$(printf '%s\n' "$ATTACH_OUTPUT" | awk -F '\t' '/Apple_HFS/ {print $NF}' | tail -n1)"
if [[ -z "$MOUNT_POINT" ]]; then
  echo "Failed to determine mount point" >&2
  exit 1
fi

cleanup() {
  hdiutil detach "$MOUNT_POINT" -quiet 2>/dev/null || true
}
trap cleanup EXIT

VOLUME_NAME="$(basename "$MOUNT_POINT")"

osascript <<EOF2
 tell application "Finder"
   tell disk "$VOLUME_NAME"
     open
     delay 0.4
     set cw to container window
     set vo to icon view options of cw
     try
       set bg to background picture of vo as text
     on error
       set bg to "<not set>"
     end try
     set appPos to position of item "WordFreqApp.app" of cw
     set appsPos to position of item "Applications" of cw
     set readmePos to "<missing>"
     if exists item "README.txt" of cw then
       set readmePos to (position of item "README.txt" of cw) as text
     end if
     return "mount=" & "$MOUNT_POINT" & ", bg=" & bg & ", app=" & appPos & ", applications=" & appsPos & ", readme=" & readmePos
   end tell
 end tell
EOF2
