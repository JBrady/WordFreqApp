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

if [[ ! -f "$MOUNT_POINT/README.txt" ]]; then
  echo "ERROR: missing README.txt" >&2
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
      return "<not set>"
    end try
    set appPos to position of item "WordFreqApp.app" of cw
    set appsPos to position of item "Applications" of cw
    set readmePos to "<missing>"
    if exists item "README.txt" of cw then
      set readmePos to (position of item "README.txt" of cw) as text
    end if
    return "view=" & currentViewName & ", bounds=" & windowBounds & ", background=" & bgPicture & ", app=" & appPos & ", applications=" & appsPos & ", readme=" & readmePos
  end tell
end tell
EOF
)"; then
  echo "Finder layout info: $FINDER_INFO"
else
  echo "WARNING: Unable to query Finder layout details (non-fatal)." >&2
fi

echo "DMG layout verification passed"
