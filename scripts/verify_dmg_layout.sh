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
MOUNT_POINT="$TMP_DIR/mount"

cleanup() {
  hdiutil detach "$MOUNT_POINT" -quiet 2>/dev/null || true
  rm -rf "$TMP_DIR"
}
trap cleanup EXIT

mkdir -p "$MOUNT_POINT"
ATTACH_OUTPUT="$(hdiutil attach -nobrowse -readonly -mountpoint "$MOUNT_POINT" "$DMG_PATH")"
printf '%s\n' "$ATTACH_OUTPUT" >/dev/null

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

if BG_INFO="$(osascript <<EOF 2>/dev/null
tell application "Finder"
  set mountAlias to POSIX file "$MOUNT_POINT" as alias
  set mountDisk to disk of mountAlias
  open mountDisk
  delay 0.2
  tell container window of mountDisk
    try
      set bgPicture to background picture of icon view options
      return bgPicture as text
    on error
      return "<not set>"
    end try
  end tell
end tell
EOF
)"; then
  echo "Finder background picture: $BG_INFO"
else
  echo "INFO: Unable to query Finder background picture (non-fatal)." >&2
fi

echo "DMG layout verification passed"
