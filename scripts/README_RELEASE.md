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

Manual verification:

```bash
./scripts/verify_dmg_layout.sh ./.build/WordFreqApp.dmg
```
