#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH="${1:-$ROOT_DIR/.build/release/WordFreqApp/WordFreqApp.app}"
DMG_PATH="${2:-$ROOT_DIR/.build/WordFreqApp.dmg}"
CANVAS_W="${DMG_CANVAS_W:-600}"
CANVAS_H="${DMG_CANVAS_H:-400}"
LAYOUT_OFFSET_X="${DMG_LAYOUT_OFFSET_X:-0}"
LAYOUT_OFFSET_Y="${DMG_LAYOUT_OFFSET_Y:--40}"
BASE_WIN_X="${DMG_WIN_X:-100}"
BASE_WIN_Y="${DMG_WIN_Y:-80}"
BASE_WIN_X2="${DMG_WIN_X2:-800}"
BASE_WIN_Y2="${DMG_WIN_Y2:-560}"
WIN_X="$((BASE_WIN_X + LAYOUT_OFFSET_X))"
WIN_Y="$((BASE_WIN_Y + LAYOUT_OFFSET_Y))"
WIN_X2="$((BASE_WIN_X2 + LAYOUT_OFFSET_X))"
WIN_Y2="$((BASE_WIN_Y2 + LAYOUT_OFFSET_Y))"
BASE_APP_POS_X="${DMG_APP_POS_X:-$((CANVAS_W * 30 / 100))}"
BASE_APP_POS_Y="${DMG_APP_POS_Y:-$((CANVAS_H * 62 / 100 + 90))}"
BASE_APPS_POS_X="${DMG_APPS_POS_X:-$((CANVAS_W * 75 / 100))}"
BASE_APPS_POS_Y="${DMG_APPS_POS_Y:-$((CANVAS_H * 62 / 100 + 90))}"
APP_POS_X="$((BASE_APP_POS_X + LAYOUT_OFFSET_X))"
APP_POS_Y="$((BASE_APP_POS_Y + LAYOUT_OFFSET_Y))"
APPS_POS_X="$((BASE_APPS_POS_X + LAYOUT_OFFSET_X))"
APPS_POS_Y="$((BASE_APPS_POS_Y + LAYOUT_OFFSET_Y))"

if [[ ! -d "$APP_PATH" ]]; then
  echo "App not found: $APP_PATH" >&2
  echo "Build it first: ./scripts/build_release.sh" >&2
  exit 1
fi

"$ROOT_DIR/scripts/make_dmg.sh" "$APP_PATH" "$DMG_PATH"

echo "Effective layout: bounds={$WIN_X, $WIN_Y, $WIN_X2, $WIN_Y2} app={$APP_POS_X, $APP_POS_Y} applications={$APPS_POS_X, $APPS_POS_Y} offsets={$LAYOUT_OFFSET_X, $LAYOUT_OFFSET_Y}"

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
     return "mount=" & "$MOUNT_POINT" & ", bg=" & bg & ", app=" & appPos & ", applications=" & appsPos
   end tell
 end tell
EOF2
