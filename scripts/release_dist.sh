#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BUILD_SCRIPT="$ROOT_DIR/scripts/build_release.sh"
DMG_SCRIPT="$ROOT_DIR/scripts/make_dmg.sh"
NOTARIZE_SCRIPT="$ROOT_DIR/scripts/notarize.sh"
APP_PATH="$ROOT_DIR/.build/release/WordFreqApp/WordFreqApp.app"
WORK_DMG="$ROOT_DIR/.build/WordFreqApp.dmg"
DIST_DIR="$ROOT_DIR/dist"
NOTARY_PROFILE="${NOTARY_PROFILE:-AC_PROFILE}"
MAKE_ZIP=1

usage() {
  cat <<USAGE
Usage: $0 [--profile <notarytool-profile>] [--no-zip]

Builds, signs, packages, notarizes, and staples WordFreqApp for distribution.
Outputs:
  dist/WordFreqApp-<version>.dmg
  dist/WordFreqApp-<version>.zip (unless --no-zip)
  dist/README.txt
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --profile)
      NOTARY_PROFILE="$2"
      shift 2
      ;;
    --no-zip)
      MAKE_ZIP=0
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

for required in "$BUILD_SCRIPT" "$DMG_SCRIPT" "$NOTARIZE_SCRIPT"; do
  if [[ ! -x "$required" ]]; then
    echo "Required script missing or not executable: $required" >&2
    exit 1
  fi
done

if ! xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1; then
  echo "Missing notarytool keychain profile: $NOTARY_PROFILE" >&2
  echo "Create it once with:" >&2
  echo "  xcrun notarytool store-credentials \"$NOTARY_PROFILE\" --apple-id \"<APPLE_ID>\" --team-id \"<TEAM_ID>\" --password \"<APP_SPECIFIC_PASSWORD>\"" >&2
  exit 1
fi

cd "$ROOT_DIR"

echo "==> Build release app"
"$BUILD_SCRIPT"

if [[ ! -d "$APP_PATH" ]]; then
  echo "Release app not found: $APP_PATH" >&2
  exit 1
fi

SHORT_VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP_PATH/Contents/Info.plist" 2>/dev/null || true)"
BUILD_VERSION="$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$APP_PATH/Contents/Info.plist" 2>/dev/null || true)"
if [[ -n "$SHORT_VERSION" ]]; then
  VERSION_TAG="$SHORT_VERSION"
elif [[ -n "$BUILD_VERSION" ]]; then
  VERSION_TAG="$BUILD_VERSION"
else
  VERSION_TAG="$(date -u '+%Y%m%d-%H%M%S')"
fi

DIST_DMG="$DIST_DIR/WordFreqApp-$VERSION_TAG.dmg"
DIST_ZIP="$DIST_DIR/WordFreqApp-$VERSION_TAG.zip"
README_PATH="$DIST_DIR/README.txt"

echo "==> Verify app signature before packaging"
codesign -vvv --deep --strict "$APP_PATH"

SIGNER_INFO="$(codesign -dvv "$APP_PATH" 2>&1 || true)"
SIGNER_LINE="$(printf "%s\n" "$SIGNER_INFO" | sed -n 's/^Authority=Developer ID Application: //p' | head -n 1)"
if [[ -z "$SIGNER_LINE" ]]; then
  echo "Unable to determine Developer ID signer from app signature" >&2
  exit 1
fi
SIGN_IDENTITY="Developer ID Application: $SIGNER_LINE"
echo "==> Using signing identity: $SIGN_IDENTITY"

echo "==> Build DMG"
"$DMG_SCRIPT" "$APP_PATH" "$WORK_DMG"

if [[ ! -f "$WORK_DMG" ]]; then
  echo "DMG not produced: $WORK_DMG" >&2
  exit 1
fi

echo "==> Sign DMG container"
codesign --force --sign "$SIGN_IDENTITY" --timestamp "$WORK_DMG"
codesign -vvv --strict "$WORK_DMG"

echo "==> Notarize + staple DMG"
"$NOTARIZE_SCRIPT" --file "$WORK_DMG" --profile "$NOTARY_PROFILE"

mkdir -p "$DIST_DIR"
cp -f "$WORK_DMG" "$DIST_DMG"

if [[ "$MAKE_ZIP" -eq 1 ]]; then
  echo "==> Build ZIP"
  rm -f "$DIST_ZIP"
  ditto -c -k --sequesterRsrc --keepParent "$APP_PATH" "$DIST_ZIP"
fi

VERIFY_LOG="$(mktemp)"
MOUNT_POINT=""
cleanup() {
  if [[ -n "$MOUNT_POINT" ]]; then
    hdiutil detach "$MOUNT_POINT" -quiet >/dev/null 2>&1 || true
  fi
  rm -f "$VERIFY_LOG"
}
trap cleanup EXIT

{
  echo "WordFreqApp distribution verification"
  echo "Generated at: $(date -u '+%Y-%m-%dT%H:%M:%SZ')"
  echo "Notary profile: $NOTARY_PROFILE"
  echo "Signing identity: $SIGN_IDENTITY"
  echo "Artifact version tag: $VERSION_TAG"
  echo "Artifacts:"
  echo "  $DIST_DMG"
  if [[ "$MAKE_ZIP" -eq 1 ]]; then
    echo "  $DIST_ZIP"
  fi
  echo
  echo "== codesign strict check on built app =="
  codesign -vvv --deep --strict "$APP_PATH" 2>&1
  echo
  echo "== spctl assessment on DMG =="
  spctl -a -vv "$DIST_DMG" 2>&1 || true
  echo
  echo "== spctl assessment on DMG (type open) =="
  spctl -a -vv -t open "$DIST_DMG" 2>&1 || true
  echo
  echo "== stapler validate DMG =="
  xcrun stapler validate "$DIST_DMG" 2>&1
} | tee "$VERIFY_LOG"

MOUNT_POINT="$(hdiutil attach "$DIST_DMG" -nobrowse -readonly | sed -n 's#^.*\t\(/Volumes/.*\)$#\1#p' | head -n 1)"
if [[ -z "$MOUNT_POINT" ]]; then
  echo "Unable to mount DMG for final app verification" >&2
  exit 1
fi

APP_IN_DMG="$MOUNT_POINT/WordFreqApp.app"
if [[ ! -d "$APP_IN_DMG" ]]; then
  echo "Mounted DMG does not contain WordFreqApp.app at expected path: $APP_IN_DMG" >&2
  exit 1
fi

{
  echo
  echo "== spctl assessment on app inside mounted DMG =="
  spctl -a -vv "$APP_IN_DMG" 2>&1
  echo
  echo "== codesign strict check on app inside mounted DMG =="
  codesign -vvv --deep --strict "$APP_IN_DMG" 2>&1
  echo
  echo "Friend install steps"
  echo "1) Open the DMG and drag WordFreqApp to Applications."
  echo "2) In Applications, Control-click WordFreqApp, choose Open, then confirm Open."
  echo "3) If blocked, go to System Settings > Privacy & Security and allow WordFreqApp."
} | tee -a "$VERIFY_LOG"

hdiutil detach "$MOUNT_POINT" -quiet
MOUNT_POINT=""

cp -f "$VERIFY_LOG" "$README_PATH"

echo
echo "Distribution complete:"
echo "  $DIST_DMG"
if [[ "$MAKE_ZIP" -eq 1 ]]; then
  echo "  $DIST_ZIP"
fi
echo "  $README_PATH"
