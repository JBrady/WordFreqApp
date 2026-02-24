#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OPS="$ROOT_DIR/scripts/ops"
APP="$ROOT_DIR/.build/release/WordFreqApp/WordFreqApp.app"
DMG="$ROOT_DIR/.build/WordFreqApp.dmg"

log() {
  "$OPS/acs_log.sh" "$*" >/dev/null
}

set_status() {
  "$OPS/acs_update_status.sh" "$1" "$2" >/dev/null
}

capture() {
  "$OPS/acs_capture_error.sh" "$@"
}

"$OPS/acs_init.sh" >/dev/null

log "Checklist start"

# 1) app_launch_local (best effort)
if [[ -d "$APP" ]]; then
  if capture app_open open "$APP"; then
    sleep 2
    set_status app_launch_local unknown
    log "app_launch_local unknown: open command succeeded, but launch cannot be asserted reliably from CLI"
  else
    set_status app_launch_local unknown
    log "app_launch_local unknown: open command failed; check .artifacts/app_open.log"
  fi
else
  set_status app_launch_local unknown
  log "app_launch_local unknown: release app missing at $APP"
fi

# 2) build_release
if [[ -d "$APP" ]] && capture app_codesign_verify codesign --verify --deep --strict --verbose=2 "$APP"; then
  set_status build_release success
  log "build_release success: existing release app and codesign verification passed"
else
  log "build_release rerun: existing release output missing/invalid"
  if capture build_release ./scripts/build_release.sh; then
    if [[ -d "$APP" ]] && capture app_codesign_verify codesign --verify --deep --strict --verbose=2 "$APP"; then
      set_status build_release success
      log "build_release success: script completed and app verified"
    else
      set_status build_release failed
      log "build_release failed: post-build app verification failed"
    fi
  else
    set_status build_release failed
    log "build_release failed: check .artifacts/build_release.log"
  fi
fi

# 3) dmg_packaging + dmg_opens
if capture make_dmg ./scripts/make_dmg.sh; then
  if [[ -f "$DMG" ]]; then
    set_status dmg_packaging success
    log "dmg_packaging success: DMG exists at .build/WordFreqApp.dmg"
  else
    set_status dmg_packaging failed
    log "dmg_packaging failed: make_dmg completed but DMG file missing"
  fi
else
  set_status dmg_packaging failed
  log "dmg_packaging failed: check .artifacts/make_dmg.log"
fi

if [[ -f "$DMG" ]]; then
  if capture open_dmg open "$DMG"; then
    set_status dmg_opens success
    log "dmg_opens success (best effort): open command returned success"
  else
    set_status dmg_opens unknown
    log "dmg_opens unknown: open command failed; check .artifacts/open_dmg.log"
  fi

  if capture verify_dmg_layout ./scripts/verify_dmg_layout.sh "$DMG"; then
    set_status dmg_packaging success
    log "dmg layout verification passed"
  else
    set_status dmg_packaging failed
    log "dmg layout verification failed; check .artifacts/verify_dmg_layout.log"
  fi
fi

# 4) vm_boot_monterey (Tart)
if capture tart_version tart --version; then
  if tart get monterey >/dev/null 2>&1; then
    log "vm_boot_monterey prep: local 'monterey' VM exists"
  else
    if capture tart_clone_monterey tart clone ghcr.io/cirruslabs/macos-monterey-base:latest monterey; then
      log "vm_boot_monterey prep: cloned local 'monterey' VM"
    else
      set_status vm_boot_monterey unknown
      log "vm_boot_monterey unknown: failed to clone VM; check .artifacts/tart_clone_monterey.log"
    fi
  fi

  if capture tart_run_monterey_vnc bash -lc "nohup tart run monterey --vnc > '$ROOT_DIR/.artifacts/tart_run_monterey_vnc_runtime.log' 2>&1 &"; then
    sleep 4
    VM_IP="$(tart ip monterey 2>/dev/null | head -n 1 | tr -d '[:space:]' || true)"
    if [[ -n "$VM_IP" ]]; then
      set_status vm_boot_monterey success
      log "vm_boot_monterey success: tart reports IP $VM_IP"
    else
      set_status vm_boot_monterey unknown
      log "vm_boot_monterey unknown: start command issued but boot not auto-confirmed. Next manual step: connect via Screen Sharing and verify About This Mac shows 12.x"
    fi
  else
    set_status vm_boot_monterey unknown
    log "vm_boot_monterey unknown: failed to start tart run --vnc; check .artifacts/tart_run_monterey_vnc.log"
  fi
else
  set_status vm_boot_monterey unknown
  log "vm_boot_monterey unknown: Tart not installed or unavailable"
fi

log "Checklist end"

echo
echo "==== .ops/status.json ===="
cat "$ROOT_DIR/.ops/status.json"
echo
echo "==== Last 20 lines of .ops/journal.md ===="
tail -n 20 "$ROOT_DIR/.ops/journal.md"
