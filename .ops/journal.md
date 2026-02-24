# A.C.S. Journal

- [bootstrap] Initialized A.C.S. journal for WordFreqApp.
- [history] Added dmgbuild-based packaging flow with deterministic window sizing and icon placement.
- [history] DMG background mode set to `none` for ship-now reliability.
- [history] DMG file icon support added via `fileicon` (non-fatal if missing).
- [history] macOS deployment target lowered to 12.0 for Monterey compatibility.
- [history] Monterey Tart base image path identified (`ghcr.io/cirruslabs/macos-monterey-base:latest`).
- [history] Clarified that Tart `--dir` sharing confusion was due to Monterey guests requiring macOS 13+ for that feature.
- [next] Next: run ops/checklist.sh
- [2026-02-24T07:32:31Z] Checklist start
- [2026-02-24T07:32:34Z] app_launch_local unknown: open command succeeded, but launch cannot be asserted reliably from CLI
- [2026-02-24T07:32:34Z] build_release success: existing release app and codesign verification passed
- [2026-02-24T07:32:53Z] dmg_packaging success: DMG exists at .build/WordFreqApp.dmg
- [2026-02-24T07:32:53Z] dmg_opens success (best effort): open command returned success
- [2026-02-24T07:32:53Z] dmg layout verification passed
- [2026-02-24T07:41:12Z] vm_boot_monterey prep: cloned local 'monterey' VM
- [2026-02-24T07:41:17Z] vm_boot_monterey unknown: start command issued but boot not auto-confirmed. Next manual step: connect via Screen Sharing and verify About This Mac shows 12.x
- [2026-02-24T07:41:17Z] Checklist end
- [2026-02-24T07:41:44Z] ACS scripts validated
