# Release Packaging

## Quick Commands

Build + open DMG:

```bash
./scripts/make_dmg.sh && open .build/WordFreqApp.dmg
```

Verify DMG:

```bash
./scripts/verify_dmg_layout.sh
```

Notarize + staple (use existing script):

```bash
./scripts/notarize.sh --file ./.build/WordFreqApp.dmg --profile AC_PROFILE
```

## Build + Notarize

```bash
./scripts/install_packaging_deps.sh
./scripts/build_release.sh
./scripts/notarize.sh --file ./.build/release/WordFreqApp/WordFreqApp.app --profile AC_PROFILE
./scripts/make_dmg.sh ./.build/release/WordFreqApp/WordFreqApp.app ./.build/WordFreqApp.dmg
./scripts/notarize.sh --file ./.build/WordFreqApp.dmg --profile AC_PROFILE
```

## DMG Volume Naming

`make_dmg.sh` uses a unique volume name by default to reduce Finder cache collisions:

- `WordFreqApp <CFBundleShortVersionString>(<CFBundleVersion>)` when available
- otherwise `WordFreqApp <YYYYMMDD-HHMM>`

Override explicitly with:

```bash
DMG_VOL_NAME="WordFreqApp" ./scripts/make_dmg.sh ./.build/release/WordFreqApp/WordFreqApp.app ./.build/WordFreqApp.dmg
```

## Layout Verification

`make_dmg.sh` runs `scripts/verify_dmg_layout.sh` automatically after DMG conversion.

## DMG Layout Tuning

`make_dmg.sh` now uses `dmgbuild` (no Finder scripting) and supports deterministic layout tuning via env vars:

- `DMG_WIN_X` / `DMG_WIN_Y` / `DMG_WIN_W` / `DMG_WIN_H`
- `DMG_ICON_SIZE` / `DMG_TEXT_SIZE`
- `DMG_APP_X` / `DMG_APP_Y` / `DMG_APPS_X` / `DMG_APPS_Y`
- `DMG_BACKGROUND_MODE=none` (backgrounds disabled)

Example:

```bash
DMG_WIN_W=820 DMG_WIN_H=520 \
DMG_APP_X=260 DMG_APP_Y=280 \
DMG_APPS_X=540 DMG_APPS_Y=280 \
./scripts/make_dmg.sh ./.build/release/WordFreqApp/WordFreqApp.app ./.build/WordFreqApp.dmg
```

Manual verification:

```bash
./scripts/verify_dmg_layout.sh ./.build/WordFreqApp.dmg
```
