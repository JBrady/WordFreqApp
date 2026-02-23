#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH="${1:-$ROOT_DIR/.build/release/WordFreqApp/WordFreqApp.app}"
OUT_DMG="${2:-$ROOT_DIR/.build/WordFreqApp.dmg}"
BACKGROUND_SRC="$ROOT_DIR/assets/dmg-background.png"
README_SRC="$ROOT_DIR/assets/README.txt"
VERIFY_SCRIPT="$ROOT_DIR/scripts/verify_dmg_layout.sh"

if [[ ! -d "$APP_PATH" ]]; then
  echo "App not found: $APP_PATH" >&2
  exit 1
fi

if [[ ! -f "$BACKGROUND_SRC" ]]; then
  echo "Missing DMG background: $BACKGROUND_SRC" >&2
  echo "Add assets/dmg-background.png (600x400) and rerun." >&2
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
cp "$BACKGROUND_SRC" "$MOUNT_POINT/.background/background.png"

echo "==> Configuring Finder layout"
if ! osascript <<EOF
tell application "Finder"
  set mountAlias to POSIX file "$MOUNT_POINT" as alias
  set mountDisk to disk of mountAlias
  open mountDisk
  delay 0.5
  tell container window of mountDisk
    set current view to icon view
    set toolbar visible to false
    set statusbar visible to false
    set bounds to {100, 100, 700, 500}
    set theViewOptions to the icon view options
    try
      set arrangement of theViewOptions to not arranged
    end try
    try
      set icon size of theViewOptions to 128
    end try
    try
      set background picture of theViewOptions to file ".background:background.png"
    end try
    set position of item "WordFreqApp.app" to {180, 250}
    set position of item "Applications" to {480, 250}
    set position of item "README.txt" to {180, 390}
    try
      update without registering applications
    end try
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

echo "==> Verifying DMG layout payload"
"$VERIFY_SCRIPT" "$OUT_DMG"

echo "Created DMG: $OUT_DMG"
