# Release Packaging

## Build + Notarize

```bash
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

`make_dmg.sh` supports deterministic layout tuning via env vars:

- `DMG_CANVAS_W` / `DMG_CANVAS_H` (background image is resized to these exact pixels)
- `DMG_CHROME_W` / `DMG_CHROME_H` (Finder chrome padding added to window bounds)
- `DMG_ICON_SIZE`
- `DMG_APP_POS_X` / `DMG_APP_POS_Y`
- `DMG_APPS_POS_X` / `DMG_APPS_POS_Y`

Example:

```bash
DMG_CANVAS_W=640 DMG_CANVAS_H=400 \
DMG_CHROME_W=100 DMG_CHROME_H=100 \
DMG_APP_POS_X=192 DMG_APP_POS_Y=338 \
DMG_APPS_POS_X=480 DMG_APPS_POS_Y=338 \
./scripts/make_dmg.sh ./.build/release/WordFreqApp/WordFreqApp.app ./.build/WordFreqApp.dmg
```

Manual verification:

```bash
./scripts/verify_dmg_layout.sh ./.build/WordFreqApp.dmg
```
