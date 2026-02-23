#!/usr/bin/env bash
set -euo pipefail

if ! command -v python3 >/dev/null 2>&1; then
  echo "ERROR: python3 is required to install packaging dependencies." >&2
  exit 1
fi

echo "==> Installing packaging dependency: dmgbuild"
python3 -m pip install --user --upgrade dmgbuild

echo "Installed dmgbuild. If 'dmgbuild' is not on PATH, add user bin to PATH (commonly ~/Library/Python/*/bin)."
