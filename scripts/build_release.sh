#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT_DIR="$ROOT_DIR/.build/release/WordFreqApp"
APP_PATH="$OUT_DIR/WordFreqApp.app"

cd "$ROOT_DIR"

echo "==> Generating Xcode project"
xcodegen generate

echo "==> Building Release app (universal)"
mkdir -p "$OUT_DIR"
xcodebuild \
  -project WordFreqApp.xcodeproj \
  -scheme WordFreqApp \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  ONLY_ACTIVE_ARCH=NO \
  ARCHS="arm64 x86_64" \
  CONFIGURATION_BUILD_DIR="$OUT_DIR" \
  build

if [[ ! -d "$APP_PATH" ]]; then
  echo "Release app not found at: $APP_PATH" >&2
  exit 1
fi

echo "Built app: $APP_PATH"
