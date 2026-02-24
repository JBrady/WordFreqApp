#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT_DIR="$ROOT_DIR/.build/ship"
SRC_DMG="$ROOT_DIR/.build/WordFreqApp.dmg"
DST_DMG="$OUT_DIR/WordFreqApp.dmg"
SUM_FILE="$OUT_DIR/WordFreqApp.dmg.sha256"
README_FILE="$OUT_DIR/README.txt"

cd "$ROOT_DIR"

./scripts/make_dmg.sh

if [[ ! -f "$SRC_DMG" ]]; then
  echo "ERROR: DMG not found at $SRC_DMG. Action: run ./scripts/make_dmg.sh and retry." >&2
  exit 1
fi

mkdir -p "$OUT_DIR"
cp -f "$SRC_DMG" "$DST_DMG"

shasum -a 256 "$DST_DMG" > "$SUM_FILE"

cat > "$README_FILE" <<'TXT'
Install: open WordFreqApp.dmg, then drag WordFreqApp to Applications.
If Gatekeeper blocks launch: right-click WordFreqApp in Applications, choose Open, then confirm Open.
If still blocked, open System Settings -> Privacy & Security and allow the app.
TXT

echo "Ship bundle created: $OUT_DIR"
echo "- $DST_DMG"
echo "- $SUM_FILE"
echo "- $README_FILE"
