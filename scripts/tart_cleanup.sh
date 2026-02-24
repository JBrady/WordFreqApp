#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ./scripts/tart_cleanup.sh [--purge-oci-cache] <vm-name> [<vm-name> ...]

Examples:
  ./scripts/tart_cleanup.sh monterey
  ./scripts/tart_cleanup.sh --purge-oci-cache monterey sonoma-test
EOF
}

if ! command -v tart >/dev/null 2>&1; then
  echo "ERROR: tart is not installed or not on PATH. Action: install Tart, then re-run this script." >&2
  exit 1
fi

PURGE_OCI_CACHE=0
declare -a VM_NAMES=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --purge-oci-cache)
      PURGE_OCI_CACHE=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      VM_NAMES+=("$1")
      shift
      ;;
  esac
done

if [[ ${#VM_NAMES[@]} -eq 0 ]]; then
  echo "ERROR: missing VM name. Action: pass one or more VM names (example: ./scripts/tart_cleanup.sh monterey)." >&2
  usage
  exit 1
fi

echo "==> Tart list (before)"
tart list || true
echo

for vm in "${VM_NAMES[@]}"; do
  if tart get "$vm" >/dev/null 2>&1; then
    echo "==> Deleting local VM: $vm"
    tart delete "$vm"
  else
    echo "==> Local VM not found (skipping): $vm"
  fi
done

echo
echo "==> Tart list (after VM cleanup)"
tart list || true
echo

if [[ "$PURGE_OCI_CACHE" -eq 1 ]]; then
  echo "==> Optional OCI cache purge requested"
  # Best-effort paths. Tart cache location can differ by version/environment.
  # We only delete known directories that exist, after explicit confirmation.
  declare -a CANDIDATE_DIRS=(
    "$HOME/Library/Caches/tart"
    "$HOME/Library/Application Support/tart/cache"
    "$HOME/.cache/tart"
    "$HOME/.tart/cache"
  )

  declare -a EXISTING_DIRS=()
  for dir in "${CANDIDATE_DIRS[@]}"; do
    if [[ -d "$dir" ]]; then
      EXISTING_DIRS+=("$dir")
    fi
  done

  if [[ ${#EXISTING_DIRS[@]} -eq 0 ]]; then
    echo "No known Tart OCI cache directories were found."
    echo "Action: run 'tart list' and Tart docs to find cache location, then remove manually if needed."
    exit 0
  fi

  echo "These directories will be removed if you confirm:"
  for dir in "${EXISTING_DIRS[@]}"; do
    echo "  - $dir"
  done
  echo
  read -r -p "Type YES to delete these cache directories, or NO to cancel: " confirm
  if [[ "$confirm" != "YES" ]]; then
    echo "Canceled cache purge."
    exit 0
  fi

  for dir in "${EXISTING_DIRS[@]}"; do
    echo "Removing: $dir"
    rm -rf "$dir"
  done
  echo "OCI cache purge complete."
fi

