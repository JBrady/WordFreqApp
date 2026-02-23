#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH="${1:-$ROOT_DIR/.build/release/WordFreqApp/WordFreqApp.app}"
OUT_DMG="${2:-$ROOT_DIR/.build/WordFreqApp.dmg}"
BACKGROUND_SRC="$ROOT_DIR/assets/dmg-background-source.png"
README_SRC="$ROOT_DIR/assets/README.txt"
VERIFY_SCRIPT="$ROOT_DIR/scripts/verify_dmg_layout.sh"

CANVAS_W="${DMG_CANVAS_W:-600}"
CANVAS_H="${DMG_CANVAS_H:-400}"
CHROME_W="${DMG_CHROME_W:-100}"
CHROME_H="${DMG_CHROME_H:-100}"
WIN_X="${DMG_WIN_X:-100}"
WIN_Y="${DMG_WIN_Y:-100}"
WIN_X2="${DMG_WIN_X2:-$((WIN_X + CANVAS_W + CHROME_W))}"
WIN_Y2="${DMG_WIN_Y2:-$((WIN_Y + CANVAS_H + CHROME_H))}"
ICON_SIZE="${DMG_ICON_SIZE:-128}"

APP_POS_X="${DMG_APP_POS_X:-$((CANVAS_W * 30 / 100))}"
APP_POS_Y="${DMG_APP_POS_Y:-$((CANVAS_H * 62 / 100))}"
APPS_POS_X="${DMG_APPS_POS_X:-$((CANVAS_W * 75 / 100))}"
APPS_POS_Y="${DMG_APPS_POS_Y:-$((CANVAS_H * 62 / 100))}"
README_POS_X="${DMG_README_POS_X:-$((CANVAS_W * 30 / 100))}"
README_POS_Y="${DMG_README_POS_Y:-$((CANVAS_H * 86 / 100))}"

if [[ ! -d "$APP_PATH" ]]; then
  echo "App not found: $APP_PATH" >&2
  exit 1
fi

if [[ ! -f "$BACKGROUND_SRC" ]]; then
  # Backward compatibility for previous asset path.
  LEGACY_BACKGROUND="$ROOT_DIR/assets/dmg-background.png"
  if [[ -f "$LEGACY_BACKGROUND" ]]; then
    BACKGROUND_SRC="$LEGACY_BACKGROUND"
  else
    echo "Missing DMG background source: $BACKGROUND_SRC" >&2
    echo "Add assets/dmg-background-source.png and rerun." >&2
    exit 1
  fi
fi

if ! [[ "$CANVAS_W" =~ ^[0-9]+$ && "$CANVAS_H" =~ ^[0-9]+$ ]]; then
  echo "Invalid DMG canvas size: DMG_CANVAS_W=$CANVAS_W DMG_CANVAS_H=$CANVAS_H" >&2
  exit 1
fi

if [[ ! -f "$README_SRC" ]]; then
  echo "Missing DMG README asset: $README_SRC" >&2
  echo "Add assets/README.txt and rerun." >&2
  exit 1
fi

if [[ ! -x "$VERIFY_SCRIPT" ]]; then
  echo "Missing DMG layout verifier: $VERIFY_SCRIPT" >&2
  echo "Ensure scripts/verify_dmg_layout.sh exists and is executable." >&2
  exit 1
fi

mkdir -p "$(dirname "$OUT_DMG")"
TMP_DIR="$(mktemp -d)"
RW_DMG="$TMP_DIR/WordFreqApp-rw.dmg"
MOUNT_POINT="$TMP_DIR/mount"
LAYOUT_MOUNT_POINT=""

if [[ -n "${DMG_VOL_NAME:-}" ]]; then
  VOL_NAME="$DMG_VOL_NAME"
else
  SHORT_VERSION=""
  BUILD_VERSION=""
  INFO_PLIST="$APP_PATH/Contents/Info.plist"
  if [[ -f "$INFO_PLIST" ]]; then
    SHORT_VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$INFO_PLIST" 2>/dev/null || true)"
    BUILD_VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$INFO_PLIST" 2>/dev/null || true)"
  fi
  if [[ -n "$SHORT_VERSION" && -n "$BUILD_VERSION" ]]; then
    VOL_NAME="WordFreqApp ${SHORT_VERSION}(${BUILD_VERSION})"
  else
    VOL_NAME="WordFreqApp $(date '+%Y%m%d-%H%M')"
  fi
fi

cleanup() {
  if [[ -n "$LAYOUT_MOUNT_POINT" ]]; then
    hdiutil detach "$LAYOUT_MOUNT_POINT" -quiet 2>/dev/null || true
  fi
  hdiutil detach "$MOUNT_POINT" -quiet 2>/dev/null || true
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

APP_SIZE_KB="$(du -sk "$APP_PATH" | awk '{print $1}')"
DMG_SIZE_MB="$(( (APP_SIZE_KB / 1024) + 80 ))"

echo "==> Creating writable DMG"
hdiutil create \
  -size "${DMG_SIZE_MB}m" \
  -fs HFS+ \
  -volname "$VOL_NAME" \
  "$RW_DMG" \
  -quiet

echo "==> Attaching DMG"
mkdir -p "$MOUNT_POINT"
hdiutil attach "$RW_DMG" -mountpoint "$MOUNT_POINT" -quiet

echo "==> Populating DMG"
ditto --rsrc --extattr "$APP_PATH" "$MOUNT_POINT/WordFreqApp.app"
ln -s /Applications "$MOUNT_POINT/Applications"
cp "$README_SRC" "$MOUNT_POINT/README.txt"

echo "==> Adding background"
mkdir -p "$MOUNT_POINT/.background"
sips -z "$CANVAS_H" "$CANVAS_W" "$BACKGROUND_SRC" --out "$MOUNT_POINT/.background/background.png" >/dev/null

echo "==> Verifying copied app code signature"
codesign -vvv --deep --strict "$MOUNT_POINT/WordFreqApp.app"

echo "==> Checking stapled ticket on copied app (non-fatal)"
xcrun stapler validate "$MOUNT_POINT/WordFreqApp.app" || true

sync
hdiutil detach "$MOUNT_POINT" -quiet

echo "==> Applying Finder layout"
while IFS= read -r existing_mount; do
  [[ -z "$existing_mount" ]] && continue
  if [[ "$existing_mount" == "/Volumes/$VOL_NAME" || "$existing_mount" == "/Volumes/$VOL_NAME "* ]]; then
    hdiutil detach "$existing_mount" -quiet 2>/dev/null || true
  fi
done < <(hdiutil info | awk -F '\t' '/Apple_HFS/ {print $NF}')

ATTACH_OUTPUT="$(hdiutil attach "$RW_DMG" -nobrowse)"
LAYOUT_MOUNT_POINT="$(printf '%s\n' "$ATTACH_OUTPUT" | awk -F '\t' '/Apple_HFS/ {print $NF}' | tail -n1)"
if [[ -z "$LAYOUT_MOUNT_POINT" ]]; then
  echo "WARNING: Could not determine layout mount point; skipping Finder layout." >&2
else
  echo "Layout mount point: $LAYOUT_MOUNT_POINT"
  LAYOUT_VOL_NAME="$(basename "$LAYOUT_MOUNT_POINT")"
  LAYOUT_VOL_NAME_ESCAPED="${LAYOUT_VOL_NAME//\"/\\\"}"
  APPLESCRIPT_LOG="$TMP_DIR/finder-layout.applescript.log"
  if ! BG_QUERY="$(osascript 2>"$APPLESCRIPT_LOG" <<EOF2
  tell application "Finder"
    tell disk "$LAYOUT_VOL_NAME_ESCAPED"
      open
      delay 0.5
      set cw to container window
      set current view of cw to icon view
      set toolbar visible of cw to false
      set statusbar visible of cw to false
      set bounds of cw to {$WIN_X, $WIN_Y, $WIN_X2, $WIN_Y2}
      set viewOptions to the icon view options of cw
      try
        set arrangement of viewOptions to not arranged
      end try
      try
        set icon size of viewOptions to $ICON_SIZE
      end try
      set background picture of viewOptions to file ".background:background.png"
      set position of item "WordFreqApp.app" of cw to {$APP_POS_X, $APP_POS_Y}
      set position of item "Applications" of cw to {$APPS_POS_X, $APPS_POS_Y}
      if exists item "README.txt" of cw then
        set position of item "README.txt" of cw to {$README_POS_X, $README_POS_Y}
      end if
      if exists item ".background" of cw then
        set position of item ".background" of cw to {900, 900}
      end if
      if exists item ".fseventsd" of cw then
        set position of item ".fseventsd" of cw to {960, 900}
      end if
      if exists item ".Trashes" of cw then
        set position of item ".Trashes" of cw to {1020, 900}
      end if
      try
        update without registering applications
      end try
      try
        set bgPicture to background picture of viewOptions as text
      on error
        set bgPicture to "<not set>"
      end try
      delay 1
      close
      return bgPicture
    end tell
  end tell
EOF2
  )"
  then
    echo "WARNING: Finder layout configuration failed; continuing without custom layout." >&2
    if [[ -s "$APPLESCRIPT_LOG" ]]; then
      echo "AppleScript stderr:" >&2
      cat "$APPLESCRIPT_LOG" >&2
    fi
  else
    echo "Finder background picture after set: $BG_QUERY"
  fi
  hdiutil detach "$LAYOUT_MOUNT_POINT" -quiet
  LAYOUT_MOUNT_POINT=""
fi

echo "==> Converting DMG"
rm -f "$OUT_DMG"
hdiutil convert "$RW_DMG" -format UDZO -o "$OUT_DMG" -quiet

echo "==> Verifying DMG layout payload"
"$VERIFY_SCRIPT" "$OUT_DMG"

echo "Created DMG: $OUT_DMG"
