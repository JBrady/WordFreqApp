#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH="${1:-$ROOT_DIR/.build/release/WordFreqApp/WordFreqApp.app}"
OUT_DMG="${2:-$ROOT_DIR/.build/WordFreqApp.dmg}"
BACKGROUND_SRC="$ROOT_DIR/assets/dmg-background.png"

if [[ ! -d "$APP_PATH" ]]; then
  echo "App not found: $APP_PATH" >&2
  exit 1
fi

mkdir -p "$ROOT_DIR/assets"
if [[ ! -f "$BACKGROUND_SRC" ]]; then
  echo "Missing DMG background: $BACKGROUND_SRC" >&2
  echo "Add assets/dmg-background.png (600x400) and rerun." >&2
  exit 1
fi

mkdir -p "$(dirname "$OUT_DMG")"
TMP_DIR="$(mktemp -d)"
RW_DMG="$TMP_DIR/WordFreqApp-rw.dmg"
VOL_NAME="WordFreqApp"
MOUNT_POINT="/Volumes/$VOL_NAME"

cleanup() {
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
if [[ -d "$MOUNT_POINT" ]]; then
  hdiutil detach "$MOUNT_POINT" -quiet 2>/dev/null || true
fi
hdiutil attach "$RW_DMG" -mountpoint "$MOUNT_POINT" -quiet

echo "==> Populating DMG"
ditto --rsrc --extattr "$APP_PATH" "$MOUNT_POINT/WordFreqApp.app"
ln -s /Applications "$MOUNT_POINT/Applications"

echo "==> Adding background"
mkdir -p "$MOUNT_POINT/.background"
cp "$BACKGROUND_SRC" "$MOUNT_POINT/.background/background.png"

echo "==> Configuring Finder layout"
if ! osascript <<EOF
tell application "Finder"
  tell disk "WordFreqApp"
    open
    tell container window
      set current view to icon view
      set toolbar visible to false
      set statusbar visible to false
      set bounds to {100, 100, 700, 500}
    end tell
    set theViewOptions to the icon view options of container window
    set arrangement of theViewOptions to not arranged
    set icon size of theViewOptions to 128
    set bgFile to POSIX file "$MOUNT_POINT/.background/background.png" as alias
    set background picture of theViewOptions to bgFile
    set position of item "WordFreqApp.app" of container window to {180, 250}
    set position of item "Applications" of container window to {480, 250}
    update without registering applications
    delay 1
    close
  end tell
end tell
EOF
then
  echo "WARNING: Finder layout configuration failed; continuing without custom layout." >&2
fi

echo "==> Verifying copied app code signature"
codesign -vvv --deep --strict "$MOUNT_POINT/WordFreqApp.app"

echo "==> Checking stapled ticket on copied app (non-fatal)"
xcrun stapler validate "$MOUNT_POINT/WordFreqApp.app" || true

sync
hdiutil detach "$MOUNT_POINT" -quiet

echo "==> Converting DMG"
rm -f "$OUT_DMG"
hdiutil convert "$RW_DMG" -format UDZO -o "$OUT_DMG" -quiet

echo "Created DMG: $OUT_DMG"
