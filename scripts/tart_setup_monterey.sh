#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ./scripts/tart_setup_monterey.sh [--recreate]

Behavior:
  - Creates local VM "monterey" from Cirrus Labs Monterey base image.
  - Starts VM in VNC mode for copy/paste-friendly testing.
EOF
}

if ! command -v tart >/dev/null 2>&1; then
  echo "ERROR: tart is not installed or not on PATH. Action: install Tart, then re-run this script." >&2
  exit 1
fi

RECREATE=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --recreate)
      RECREATE=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: unknown argument '$1'. Action: use --recreate or --help." >&2
      exit 1
      ;;
  esac
done

VM_NAME="monterey"
BASE_IMAGE="ghcr.io/cirruslabs/macos-monterey-base:latest"

if tart get "$VM_NAME" >/dev/null 2>&1; then
  if [[ "$RECREATE" -eq 1 ]]; then
    echo "==> Recreate requested. Deleting existing VM: $VM_NAME"
    tart delete "$VM_NAME"
  else
    echo "VM '$VM_NAME' already exists. Nothing to do."
    echo "Action: run './scripts/tart_setup_monterey.sh --recreate' if you want a fresh VM."
    exit 0
  fi
fi

echo "==> Cloning Monterey VM"
echo "Source image: $BASE_IMAGE"
echo "Local name:    $VM_NAME"
tart clone "$BASE_IMAGE" "$VM_NAME"

echo
echo "==> Starting VM in VNC mode"
echo "Use Screen Sharing to connect when Tart prints the VNC endpoint."
echo "Common local endpoint is vnc://127.0.0.1:5900"
echo
echo "Note: 'tart run --dir ...' is not supported for macOS 12 guests because Tart directory sharing requires macOS 13+ in the guest."
echo "Use './scripts/tart_push_app_to_vm.sh --artifact dmg' after the VM is running."
echo

tart run "$VM_NAME" --vnc

