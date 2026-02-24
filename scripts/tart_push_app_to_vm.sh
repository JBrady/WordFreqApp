#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage:
  ./scripts/tart_push_app_to_vm.sh [--vm monterey] [--artifact app|dmg] [--user <vm-user>]

Defaults:
  --vm monterey
  --artifact dmg
  --user admin

Examples:
  ./scripts/tart_push_app_to_vm.sh
  ./scripts/tart_push_app_to_vm.sh --artifact app
  ./scripts/tart_push_app_to_vm.sh --vm monterey --artifact dmg --user admin
EOF
}

if ! command -v tart >/dev/null 2>&1; then
  echo "ERROR: tart is not installed or not on PATH. Action: install Tart, then re-run this script." >&2
  exit 1
fi
if ! command -v scp >/dev/null 2>&1; then
  echo "ERROR: scp is not available. Action: install OpenSSH client tools, then re-run this script." >&2
  exit 1
fi

VM_NAME="monterey"
ARTIFACT_KIND="dmg"
VM_USER="admin"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --vm)
      VM_NAME="${2:-}"
      if [[ -z "$VM_NAME" ]]; then
        echo "ERROR: --vm requires a value. Action: pass a VM name." >&2
        exit 1
      fi
      shift 2
      ;;
    --artifact)
      ARTIFACT_KIND="${2:-}"
      if [[ "$ARTIFACT_KIND" != "app" && "$ARTIFACT_KIND" != "dmg" ]]; then
        echo "ERROR: invalid --artifact value '$ARTIFACT_KIND'. Action: use 'app' or 'dmg'." >&2
        exit 1
      fi
      shift 2
      ;;
    --user)
      VM_USER="${2:-}"
      if [[ -z "$VM_USER" ]]; then
        echo "ERROR: --user requires a value. Action: pass the VM username (example: admin)." >&2
        exit 1
      fi
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: unknown argument '$1'. Action: run with --help." >&2
      exit 1
      ;;
  esac
done

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH="$ROOT_DIR/.build/release/WordFreqApp/WordFreqApp.app"
DMG_PATH="$ROOT_DIR/.build/WordFreqApp.dmg"

if [[ "$ARTIFACT_KIND" == "app" ]]; then
  ARTIFACT_PATH="$APP_PATH"
else
  ARTIFACT_PATH="$DMG_PATH"
fi

if [[ ! -e "$ARTIFACT_PATH" ]]; then
  echo "ERROR: artifact not found: $ARTIFACT_PATH" >&2
  if [[ "$ARTIFACT_KIND" == "dmg" ]]; then
    echo "Action: run './scripts/build_release.sh && ./scripts/make_dmg.sh' then retry." >&2
  else
    echo "Action: run './scripts/build_release.sh' then retry." >&2
  fi
  exit 1
fi

if ! tart get "$VM_NAME" >/dev/null 2>&1; then
  echo "ERROR: VM '$VM_NAME' does not exist locally. Action: run './scripts/tart_setup_monterey.sh --recreate' first." >&2
  exit 1
fi

VM_IP=""
if VM_IP="$(tart ip "$VM_NAME" 2>/dev/null)"; then
  VM_IP="$(echo "$VM_IP" | head -n 1 | tr -d '[:space:]')"
fi

if [[ -z "$VM_IP" ]]; then
  echo "ERROR: could not determine VM IP for '$VM_NAME' via 'tart ip'."
  echo "Action: start the VM, then inside the VM open System Settings -> Network and note the IP address."
  echo "Then copy manually with:"
  echo "  scp -o StrictHostKeyChecking=accept-new -r \"$ARTIFACT_PATH\" \"$VM_USER@<VM_IP>:/Users/$VM_USER/Downloads/\""
  echo
  echo "Fallback: in Screen Sharing, try drag-and-drop or clipboard transfer."
  echo "Note: '--dir' sharing is unavailable on macOS 12 guests because Tart requires macOS 13+ guest support for directory sharing."
  exit 1
fi

echo "Detected VM IP: $VM_IP"

if ! nc -zw 3 "$VM_IP" 22 >/dev/null 2>&1; then
  echo "ERROR: SSH is not reachable on $VM_IP:22."
  echo "Action inside VM: System Settings -> General -> Sharing -> enable 'Remote Login'."
  echo "Then retry this script."
  echo
  echo "Fallback: Screen Sharing transfer (drag-and-drop/clipboard) if available."
  exit 1
fi

REMOTE_DIR="/Users/$VM_USER/Downloads/"
echo "==> Copying artifact to VM via scp (preferred for Monterey)"
echo "Local:  $ARTIFACT_PATH"
echo "Remote: $VM_USER@$VM_IP:$REMOTE_DIR"
echo
echo "Equivalent one-liner:"
echo "scp -o StrictHostKeyChecking=accept-new -r \"$ARTIFACT_PATH\" \"$VM_USER@$VM_IP:$REMOTE_DIR\""
echo

# Monterey guest note:
# tart run --dir is not available on macOS 12 guests (requires macOS 13+ guest support),
# so we use network copy (scp) instead.
scp -o StrictHostKeyChecking=accept-new -o ConnectTimeout=8 -r "$ARTIFACT_PATH" "$VM_USER@$VM_IP:$REMOTE_DIR"

echo
echo "Copy complete."
echo "Next: in the VM, open Downloads and launch the copied ${ARTIFACT_KIND}."
echo "Fallback note: Screen Sharing drag-and-drop/clipboard can work in some sessions, but scp is more reliable."

