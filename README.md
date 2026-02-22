# WordFreqApp

Native macOS desktop app (Swift 5.9+, SwiftUI) that computes word frequencies from a stage play text file.

## Features

- Choose a `.txt` file via `NSOpenPanel` (Google Docs export recommended)
- Configure:
  - Top N results (default `100`)
  - Minimum word length (default `2`)
  - Keep internal apostrophes (default `off`)
  - Include numbers (default `off`)
- Stopwords:
  - Built-in English stopwords bundled with app
  - Optional custom stopwords file (one word per line), merged with built-in
- Analyze and view table: `Word | Count` sorted descending by count
- Filter results via search box
- Export CSV (`word,count`)

## Google Docs -> Plain Text

1. Open your document in Google Docs.
2. Click `File` -> `Download` -> `Plain Text (.txt)`.
3. Save the `.txt` file and load it in WordFreqApp.

## Text Processing Rules

- Unicode normalization: NFKC
- Lowercasing
- Fancy quotes normalized to straight quotes
- Hyphens treated as separators
- Punctuation stripped
- Apostrophes:
  - `keep internal apostrophes = off` -> `don't` becomes `dont`
  - `on` -> internal apostrophes kept, edge apostrophes dropped
- Tokenization:
  - default: `a-z`
  - with numbers: `a-z0-9`
- Filters:
  - stopwords removed
  - tokens shorter than minimum length removed

## Build in Xcode

1. Generate project files:
   ```bash
   xcodegen generate
   ```
2. Open project:
   ```bash
   open WordFreqApp.xcodeproj
   ```
3. Build and run from Xcode (`Cmd+R`).

## CLI Build

```bash
xcodegen generate
xcodebuild -project WordFreqApp.xcodeproj -scheme WordFreqApp -configuration Release build
```

## Archive Release Build

```bash
xcodebuild \
  -project WordFreqApp.xcodeproj \
  -scheme WordFreqApp \
  -configuration Release \
  -archivePath build/WordFreqApp.xcarchive \
  archive
```

## Developer ID Signing (Direct Distribution)

Set your bundle id and Team in Xcode project settings or via build settings override.

Example archive with Developer ID signing:

```bash
xcodebuild \
  -project WordFreqApp.xcodeproj \
  -scheme WordFreqApp \
  -configuration Release \
  -archivePath build/WordFreqApp.xcarchive \
  PRODUCT_BUNDLE_IDENTIFIER=com.yourcompany.wordfreqapp \
  DEVELOPMENT_TEAM=YOURTEAMID \
  CODE_SIGN_IDENTITY="Developer ID Application" \
  archive
```

Export signed app with an `ExportOptions.plist` using `method = developer-id`:

```bash
xcodebuild \
  -exportArchive \
  -archivePath build/WordFreqApp.xcarchive \
  -exportPath build/export \
  -exportOptionsPlist ExportOptions.plist
```

## Notarization + Stapling (`notarytool`)

1. Store credentials once:
   ```bash
   xcrun notarytool store-credentials "AC_PROFILE" \
     --apple-id "you@example.com" \
     --team-id "YOURTEAMID" \
     --password "app-specific-password"
   ```
2. Run script:
   ```bash
   ./scripts/notarize.sh --app build/export/WordFreqApp.app --keychain-profile AC_PROFILE
   ```
3. Optional DMG in same flow:
   ```bash
   ./scripts/notarize.sh --app build/export/WordFreqApp.app --keychain-profile AC_PROFILE --dmg
   ```

## DMG Creation

```bash
./scripts/dmg.sh build/export/WordFreqApp.app WordFreqApp.dmg
```

## Notes

- This implementation is `.txt`-only by default to keep parsing reliable and dependency-free.
- If your source is `.docx`, export from Google Docs to `.txt` first.
