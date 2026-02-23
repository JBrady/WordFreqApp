#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH="${APP_PATH:-$ROOT_DIR/.build/release/WordFreqApp/WordFreqApp.app}"
DMG_PATH="${DMG_PATH:-$ROOT_DIR/.build/WordFreqApp.dmg}"

usage() {
  echo "Usage: $0 W H appX appY appsX appsY"
  echo "Example: $0 820 520 260 300 560 300"
}

if [[ $# -ne 6 ]]; then
  usage >&2
  exit 1
fi

W="$1"
H="$2"
APP_X="$3"
APP_Y="$4"
APPS_X="$5"
APPS_Y="$6"

for v in W H APP_X APP_Y APPS_X APPS_Y; do
  if ! [[ "${!v}" =~ ^[0-9]+$ ]]; then
    echo "Invalid numeric argument: $v=${!v}" >&2
    exit 1
  fi
done

export DMG_WINDOW_W="$W"
export DMG_WINDOW_H="$H"
export DMG_APP_X="$APP_X"
export DMG_APP_Y="$APP_Y"
export DMG_APPS_X="$APPS_X"
export DMG_APPS_Y="$APPS_Y"
export DMG_BACKGROUND_MODE=none

echo "Using DMG layout env:"
echo "  DMG_WINDOW_W=$DMG_WINDOW_W"
echo "  DMG_WINDOW_H=$DMG_WINDOW_H"
echo "  DMG_APP_X=$DMG_APP_X"
echo "  DMG_APP_Y=$DMG_APP_Y"
echo "  DMG_APPS_X=$DMG_APPS_X"
echo "  DMG_APPS_Y=$DMG_APPS_Y"
echo "  DMG_BACKGROUND_MODE=$DMG_BACKGROUND_MODE"
echo "Repro command:"
echo "  DMG_WINDOW_W=$DMG_WINDOW_W DMG_WINDOW_H=$DMG_WINDOW_H DMG_APP_X=$DMG_APP_X DMG_APP_Y=$DMG_APP_Y DMG_APPS_X=$DMG_APPS_X DMG_APPS_Y=$DMG_APPS_Y DMG_BACKGROUND_MODE=$DMG_BACKGROUND_MODE ./scripts/make_dmg.sh \"$APP_PATH\" \"$DMG_PATH\""

"$ROOT_DIR/scripts/make_dmg.sh" "$APP_PATH" "$DMG_PATH"
open "$DMG_PATH"
