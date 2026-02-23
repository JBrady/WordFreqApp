#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH="${1:-$ROOT_DIR/.build/release/WordFreqApp/WordFreqApp.app}"
OUT_DMG="${2:-$ROOT_DIR/.build/WordFreqApp.dmg}"
VERIFY_SCRIPT="$ROOT_DIR/scripts/verify_dmg_layout.sh"
SETTINGS_SCRIPT="$ROOT_DIR/scripts/dmgbuild_settings.py"

DMG_BACKGROUND_MODE="${DMG_BACKGROUND_MODE:-none}"

DMG_WIN_X="${DMG_WIN_X:-100}"
DMG_WIN_Y="${DMG_WIN_Y:-100}"
DMG_WIN_W="${DMG_WINDOW_W:-${DMG_WIN_W:-700}}"
DMG_WIN_H="${DMG_WINDOW_H:-${DMG_WIN_H:-440}}"
DMG_ICON_SIZE="${DMG_ICON_SIZE:-128}"
DMG_TEXT_SIZE="${DMG_TEXT_SIZE:-12}"
DMG_APP_X="${DMG_APP_X:-250}"
DMG_APP_Y="${DMG_APP_Y:-250}"
DMG_APPS_X="${DMG_APPS_X:-450}"
DMG_APPS_Y="${DMG_APPS_Y:-250}"

if [[ ! -d "$APP_PATH" ]]; then
  echo "App not found: $APP_PATH" >&2
  exit 1
fi

if [[ ! -x "$VERIFY_SCRIPT" ]]; then
  echo "Missing DMG layout verifier: $VERIFY_SCRIPT" >&2
  exit 1
fi

if [[ ! -f "$SETTINGS_SCRIPT" ]]; then
  echo "Missing dmgbuild settings file: $SETTINGS_SCRIPT" >&2
  exit 1
fi

if ! python3 -m dmgbuild --help >/dev/null 2>&1; then
  echo "ERROR: dmgbuild is not installed." >&2
  echo "Install it with: ./scripts/install_packaging_deps.sh" >&2
  echo "Or manually: python3 -m pip install --user dmgbuild" >&2
  exit 1
fi

if [[ "$DMG_BACKGROUND_MODE" != "none" ]]; then
  echo "Invalid DMG_BACKGROUND_MODE=$DMG_BACKGROUND_MODE (backgrounds are disabled; use DMG_BACKGROUND_MODE=none)" >&2
  exit 1
fi

for v in DMG_WIN_X DMG_WIN_Y DMG_WIN_W DMG_WIN_H DMG_ICON_SIZE DMG_TEXT_SIZE DMG_APP_X DMG_APP_Y DMG_APPS_X DMG_APPS_Y; do
  if ! [[ "${!v}" =~ ^[0-9]+$ ]]; then
    echo "Invalid numeric value: $v=${!v}" >&2
    exit 1
  fi
done

if (( DMG_WIN_W < 600 || DMG_WIN_H < 400 )); then
  echo "Window too small for reliable icon layout: ${DMG_WIN_W}x${DMG_WIN_H}" >&2
  exit 1
fi

if (( DMG_APP_X <= 0 || DMG_APP_X >= DMG_WIN_W || DMG_APPS_X <= 0 || DMG_APPS_X >= DMG_WIN_W || DMG_APP_Y <= 0 || DMG_APP_Y >= DMG_WIN_H || DMG_APPS_Y <= 0 || DMG_APPS_Y >= DMG_WIN_H )); then
  echo "Icon coordinates out of bounds for window ${DMG_WIN_W}x${DMG_WIN_H}: app=(${DMG_APP_X},${DMG_APP_Y}) apps=(${DMG_APPS_X},${DMG_APPS_Y})" >&2
  exit 1
fi

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

mkdir -p "$(dirname "$OUT_DMG")"
STAGE_DIR="$ROOT_DIR/.build/dmg-staging"
rm -rf "$STAGE_DIR"
mkdir -p "$STAGE_DIR"

STAGE_APP="$STAGE_DIR/WordFreqApp.app"
ditto --rsrc --extattr "$APP_PATH" "$STAGE_APP"

echo "==> Verifying copied app code signature"
codesign -vvv --deep --strict "$STAGE_APP"

echo "==> Checking stapled ticket on copied app (non-fatal)"
xcrun stapler validate "$STAGE_APP" || true

echo "==> Building DMG via dmgbuild"
echo "  volume=$VOL_NAME"
echo "  window=(("$DMG_WIN_X", "$DMG_WIN_Y"), ("$DMG_WIN_W", "$DMG_WIN_H"))"
echo "  icons: app=($DMG_APP_X,$DMG_APP_Y) applications=($DMG_APPS_X,$DMG_APPS_Y)"
echo "  background_mode=$DMG_BACKGROUND_MODE"

DMGBUILD_ARGS=(
  -s "$SETTINGS_SCRIPT"
  -D "volume_name=$VOL_NAME"
  -D "window_x=$DMG_WIN_X"
  -D "window_y=$DMG_WIN_Y"
  -D "window_w=$DMG_WIN_W"
  -D "window_h=$DMG_WIN_H"
  -D "icon_size=$DMG_ICON_SIZE"
  -D "text_size=$DMG_TEXT_SIZE"
  -D "app_x=$DMG_APP_X"
  -D "app_y=$DMG_APP_Y"
  -D "apps_x=$DMG_APPS_X"
  -D "apps_y=$DMG_APPS_Y"
)

rm -f "$OUT_DMG"
pushd "$STAGE_DIR" >/dev/null
DMGBUILD_LOG="$(mktemp)"
set +e
python3 -m dmgbuild --detach-retries 30 "${DMGBUILD_ARGS[@]}" "$VOL_NAME" "$OUT_DMG" >"$DMGBUILD_LOG" 2>&1
DMGBUILD_RC=$?
set -e
sed -E 's#^ERROR: File Not Found\. \(-43\).*\/\.DS_Store[[:space:]]*$#WARNING: benign dmgbuild DS_Store race (-43) (can ignore)#' "$DMGBUILD_LOG"
if [[ $DMGBUILD_RC -ne 0 ]]; then
  echo "ERROR: dmgbuild failed (exit $DMGBUILD_RC). Raw output follows:" >&2
  cat "$DMGBUILD_LOG" >&2
  rm -f "$DMGBUILD_LOG"
  popd >/dev/null
  exit "$DMGBUILD_RC"
fi
rm -f "$DMGBUILD_LOG"
popd >/dev/null

STAGED_APP="$STAGE_DIR/WordFreqApp.app"
ICNS_PATH="$STAGED_APP/Contents/Resources/AppIcon.icns"
if command -v fileicon >/dev/null 2>&1; then
  if [[ -f "$ICNS_PATH" ]]; then
    if ! fileicon set "$OUT_DMG" "$ICNS_PATH" >/dev/null 2>&1; then
      echo "WARNING: Unable to set DMG file icon (non-fatal)." >&2
    fi
  else
    echo "WARNING: Unable to set DMG file icon (non-fatal). Missing icon file: $ICNS_PATH" >&2
  fi
else
  echo "WARNING: Unable to set DMG file icon (non-fatal). fileicon is not installed." >&2
fi
killall Finder >/dev/null 2>&1 || true

echo "==> Verifying DMG layout payload"
"$VERIFY_SCRIPT" "$OUT_DMG"

echo "Created DMG: $OUT_DMG"
