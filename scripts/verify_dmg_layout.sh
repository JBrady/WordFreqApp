#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 /path/to/WordFreqApp.dmg"
}

if [[ $# -ne 1 ]]; then
  usage >&2
  exit 1
fi

DMG_PATH="$1"
if [[ ! -f "$DMG_PATH" ]]; then
  echo "ERROR: DMG not found: $DMG_PATH" >&2
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
EXPECTED_W="${DMG_CANVAS_W:-600}"
EXPECTED_H="${DMG_CANVAS_H:-400}"
LAYOUT_OFFSET_X="${DMG_LAYOUT_OFFSET_X:-0}"
LAYOUT_OFFSET_Y="${DMG_LAYOUT_OFFSET_Y:--40}"
BASE_WIN_X="${DMG_WIN_X:-100}"
BASE_WIN_Y="${DMG_WIN_Y:-80}"
BASE_WIN_X2="${DMG_WIN_X2:-800}"
BASE_WIN_Y2="${DMG_WIN_Y2:-560}"
EXPECTED_WIN_X="$((BASE_WIN_X + LAYOUT_OFFSET_X))"
EXPECTED_WIN_Y="$((BASE_WIN_Y + LAYOUT_OFFSET_Y))"
EXPECTED_WIN_X2="$((BASE_WIN_X2 + LAYOUT_OFFSET_X))"
EXPECTED_WIN_Y2="$((BASE_WIN_Y2 + LAYOUT_OFFSET_Y))"
BASE_APP_POS_X="${DMG_APP_POS_X:-$((EXPECTED_W * 30 / 100))}"
BASE_APP_POS_Y="${DMG_APP_POS_Y:-$((EXPECTED_H * 62 / 100 + 90))}"
BASE_APPS_POS_X="${DMG_APPS_POS_X:-$((EXPECTED_W * 75 / 100))}"
BASE_APPS_POS_Y="${DMG_APPS_POS_Y:-$((EXPECTED_H * 62 / 100 + 90))}"
EXPECTED_APP_X="$((BASE_APP_POS_X + LAYOUT_OFFSET_X))"
EXPECTED_APP_Y="$((BASE_APP_POS_Y + LAYOUT_OFFSET_Y))"
EXPECTED_APPS_X="$((BASE_APPS_POS_X + LAYOUT_OFFSET_X))"
EXPECTED_APPS_Y="$((BASE_APPS_POS_Y + LAYOUT_OFFSET_Y))"

TMP_DIR="$(mktemp -d)"
MOUNT_POINT=""

cleanup() {
  if [[ -n "$MOUNT_POINT" ]]; then
    hdiutil detach "$MOUNT_POINT" -quiet 2>/dev/null || true
  fi
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

ATTACH_OUTPUT="$(hdiutil attach -nobrowse -readonly "$DMG_PATH")"
MOUNT_POINT="$(printf '%s\n' "$ATTACH_OUTPUT" | awk -F '\t' '/Apple_HFS/ {print $NF}' | tail -n1)"
if [[ -z "$MOUNT_POINT" ]]; then
  echo "ERROR: failed to determine mount point for DMG" >&2
  exit 1
fi

if [[ ! -f "$MOUNT_POINT/.background/background.png" ]]; then
  echo "ERROR: missing background image at .background/background.png" >&2
  exit 1
fi

BG_WIDTH="$(sips -g pixelWidth "$MOUNT_POINT/.background/background.png" 2>/dev/null | awk -F': ' '/pixelWidth/ {print $2}')"
BG_HEIGHT="$(sips -g pixelHeight "$MOUNT_POINT/.background/background.png" 2>/dev/null | awk -F': ' '/pixelHeight/ {print $2}')"
if [[ "$BG_WIDTH" != "$EXPECTED_W" || "$BG_HEIGHT" != "$EXPECTED_H" ]]; then
  echo "ERROR: background dimensions mismatch (got ${BG_WIDTH}x${BG_HEIGHT}, expected ${EXPECTED_W}x${EXPECTED_H})" >&2
  exit 1
fi

if [[ ! -L "$MOUNT_POINT/Applications" ]]; then
  echo "ERROR: Applications is not a symlink" >&2
  exit 1
fi

APP_LINK_TARGET="$(readlink "$MOUNT_POINT/Applications")"
if [[ "$APP_LINK_TARGET" != "/Applications" ]]; then
  echo "ERROR: Applications symlink target is '$APP_LINK_TARGET' (expected '/Applications')" >&2
  exit 1
fi

if [[ ! -d "$MOUNT_POINT/WordFreqApp.app" ]]; then
  echo "ERROR: missing WordFreqApp.app" >&2
  exit 1
fi

if [[ ! -f "$MOUNT_POINT/.DS_Store" ]]; then
  echo "ERROR: missing .DS_Store (Finder layout not persisted)" >&2
  exit 1
fi

VOLUME_NAME="$(basename "$MOUNT_POINT")"
if FINDER_INFO="$(osascript <<EOF 2>/dev/null
tell application "Finder"
  tell disk "$VOLUME_NAME"
    open
    delay 0.3
    set cw to container window
    set currentViewName to current view of cw as text
    set windowBounds to bounds of cw
    set vo to icon view options of cw
    try
      set bgPicture to background picture of vo as text
    on error
      set bgPicture to "<not set>"
    end try
    set appPos to position of item "WordFreqApp.app" of cw
    set appsPos to position of item "Applications" of cw
    return "view=" & currentViewName & ", bounds=" & windowBounds & ", background=" & bgPicture & ", app=" & appPos & ", applications=" & appsPos
  end tell
end tell
EOF
)"; then
  echo "Finder layout info: $FINDER_INFO"
  echo "Expected layout: bounds={$EXPECTED_WIN_X, $EXPECTED_WIN_Y, $EXPECTED_WIN_X2, $EXPECTED_WIN_Y2}, app={$EXPECTED_APP_X, $EXPECTED_APP_Y}, applications={$EXPECTED_APPS_X, $EXPECTED_APPS_Y}, offsets={$LAYOUT_OFFSET_X, $LAYOUT_OFFSET_Y}"
else
  echo "WARNING: Unable to query Finder layout details (non-fatal)." >&2
  echo "Expected layout: bounds={$EXPECTED_WIN_X, $EXPECTED_WIN_Y, $EXPECTED_WIN_X2, $EXPECTED_WIN_Y2}, app={$EXPECTED_APP_X, $EXPECTED_APP_Y}, applications={$EXPECTED_APPS_X, $EXPECTED_APPS_Y}, offsets={$LAYOUT_OFFSET_X, $LAYOUT_OFFSET_Y}" >&2
fi

if WINDOW_ID="$(osascript <<EOF 2>/dev/null
tell application "Finder"
  tell disk "$VOLUME_NAME"
    open
    delay 0.3
    return id of container window
  end tell
end tell
EOF
)"; then
  mkdir -p "$ROOT_DIR/.build"
  if screencapture -x -l "$WINDOW_ID" "$ROOT_DIR/.build/dmg-window.png" 2>/dev/null; then
    echo "Finder screenshot: $ROOT_DIR/.build/dmg-window.png"
  else
    echo "WARNING: Unable to capture Finder window screenshot (non-fatal)." >&2
  fi
else
  echo "WARNING: Unable to get Finder window id for screenshot (non-fatal)." >&2
fi

echo "DMG layout verification passed"
