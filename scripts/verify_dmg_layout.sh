#!/usr/bin/env bash
set -euo pipefail

usage() {
  echo "Usage: $0 /path/to/WordFreqApp.dmg"
  echo "Default: .build/WordFreqApp.dmg"
}

if [[ $# -gt 1 ]]; then
  usage >&2
  exit 1
fi

if [[ $# -eq 1 ]]; then
  DMG_PATH="$1"
else
  DMG_PATH=".build/WordFreqApp.dmg"
  if [[ ! -f "$DMG_PATH" && -f "./WordFreqApp.dmg" ]]; then
    DMG_PATH="./WordFreqApp.dmg"
  fi
fi
if [[ ! -f "$DMG_PATH" ]]; then
  echo "ERROR: DMG not found: $DMG_PATH" >&2
  exit 1
fi

TMP_DIR="$(mktemp -d)"
MOUNT_POINT=""

cleanup() {
  if [[ -n "$MOUNT_POINT" ]]; then
    hdiutil detach "$MOUNT_POINT" -quiet 2>/dev/null || true
  fi
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

ATTACH_PLIST="$TMP_DIR/attach.plist"
hdiutil attach -plist -nobrowse -readonly "$DMG_PATH" >"$ATTACH_PLIST"
MOUNT_POINT="$(python3 - "$ATTACH_PLIST" <<'PY'
import plistlib
import sys

with open(sys.argv[1], "rb") as fp:
    data = plistlib.load(fp)
for entity in data.get("system-entities", []):
    mount_point = entity.get("mount-point")
    if mount_point:
        print(mount_point)
        break
PY
)"
if [[ -z "$MOUNT_POINT" ]]; then
  echo "ERROR: failed to determine mount point for DMG" >&2
  exit 1
fi

echo "Mounted DMG at: $MOUNT_POINT"

if [[ ! -d "$MOUNT_POINT/WordFreqApp.app" ]]; then
  echo "ERROR: missing WordFreqApp.app" >&2
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

if [[ "${DMG_VERIFY_SCREENSHOT:-0}" == "1" ]]; then
  SCREENSHOT_PATH="${DMG_VERIFY_SCREENSHOT_PATH:-$TMP_DIR/dmg-verify.png}"
  if command -v screencapture >/dev/null 2>&1; then
    if screencapture -x "$SCREENSHOT_PATH" >/dev/null 2>&1; then
      echo "Saved verify screenshot (best-effort): $SCREENSHOT_PATH"
    else
      echo "WARNING: screenshot capture failed (non-fatal)" >&2
    fi
  else
    echo "WARNING: screencapture not available; skipping screenshot (non-fatal)" >&2
  fi
fi

if [[ "${DMG_VERIFY_FILE_ICON:-0}" == "1" ]]; then
  set +e
  ICON_CHECK_OUTPUT="$(osascript - "$DMG_PATH" 2>&1 <<'APPLESCRIPT'
on run argv
  set dmgPath to item 1 of argv
  set dmgAlias to POSIX file dmgPath as alias
  tell application "Finder"
    set hasCustomIcon to has custom icon of (info for dmgAlias)
  end tell
  if hasCustomIcon then
    return "true"
  else
    return "false"
  end if
end run
APPLESCRIPT
)"
  ICON_CHECK_RC=$?
  set -e
  if [[ $ICON_CHECK_RC -ne 0 ]]; then
    echo "WARNING: Unable to verify DMG file custom icon (non-fatal). ${ICON_CHECK_OUTPUT}" >&2
  else
    ICON_CHECK_OUTPUT="$(printf '%s' "$ICON_CHECK_OUTPUT" | tr -d '\r' | xargs)"
    if [[ "$ICON_CHECK_OUTPUT" != "true" ]]; then
      echo "WARNING: DMG file does not report a custom icon (non-fatal)." >&2
    fi
  fi
fi

echo "DMG layout verification passed"
