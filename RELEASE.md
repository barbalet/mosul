# MOSUL Release Procedure

This checklist describes the release flow for MOSUL when shipping the native macOS SwiftUI application built from `MosulGame.xcodeproj`. It creates Apple Silicon and Intel DMG packages, plus a source archive for the exact tagged Mosul source and the linked `modernerKrieg` submodule source used to build those artifacts.

Before starting, decide the new release number and use it as the `VERSION` input throughout this checklist. Set `VERSION` without a leading `v`; the Git tag adds the leading `v` separately. For example, the current Mosul app version `0.1` uses `VERSION=0.1` and tag `v0.1`.

## Release Scope

The first standalone release keeps the Xcode product target, scheme, app bundle,
and executable named `MosulGame`. Public-facing copy and DMG volume names use
`MOSUL`.

- Product target and scheme: `MosulGame`
- App bundle and executable: `MosulGame.app` / `MosulGame`
- Bundle identifier: `com.barbalet.mosulgame`
- Minimum macOS version: 14.0
- Release architectures: Apple Silicon `arm64` and Intel `x86_64`
- Default public-demo scenario:
  `modernerKrieg/game/mosul/scenarios/market_commercial_streets_2003.mkscenario`
- Runtime payload inventory:
  `release/mosulgame_runtime_resources.json`
- Runtime payload validation:
  `python3 scripts/check_mosulgame_runtime_resources.py`
- Built app payload validation:
  `python3 scripts/check_mosulgame_runtime_resources.py --app <path-to-MosulGame.app>`
- Build-time runtime payload copy:
  `scripts/copy_mosulgame_runtime_resources.py` copies the curated payload into
  `Contents/Resources/mosul-runtime/modernerKrieg` during `MosulGame` app
  builds.
- Runtime root resolution:
  the app checks bundled `mosul-runtime` resources first and falls back to the
  source checkout for development.
- App-bundle runtime check:
  `open -W -n <path-to-MosulGame.app> --args --check-runtime-resources --require-bundled-runtime --runtime-check-output <path-to-runtime-check.txt>`
- Accessibility/minimum-window evidence:
  `scripts/check_mosulgame_accessibility_ui.sh` captures the playable shell at
  `980x680` and verifies keyboard/VoiceOver guardrails.
- Audio release evidence:
  `python3 scripts/write_mosulgame_audio_report.py --output snapshots/evidence/mosul-audio-release.txt`
  validates manifest counts, speech transcripts/captions, review metadata,
  credits coverage, and the release audio byte budget.
- App-bundle audio smoke:
  `scripts/check_mosulgame_audio_smoke.sh` launches the built app, verifies
  bundled audio asset/loop/cue/voice counts, mute/unmute, radio captions, and
  representative cue playback without requiring speakers.
- Local release-candidate app bundles:
  `scripts/build_mosulgame_release_candidate.sh` builds ad-hoc signed
  `arm64` and `x86_64` candidates under
  `dist/release-candidate/<arch>/MosulGame.app` and verifies each executable
  with `lipo`.

## 1. Prepare the Version

Update the Mosul app version in `Mac/Mosul/App/MosulVersion.swift`:

```text
shortVersion
build
```

Update the Xcode target build settings in `MosulGame.xcodeproj/project.pbxproj` for both Debug and Release:

```text
MARKETING_VERSION = <VERSION>;
CURRENT_PROJECT_VERSION = <BUILD>;
```

Use the same `VERSION` value in artifact names without the leading `v`. The Xcode target, scheme, app bundle, and executable are all named `MosulGame`.

The `MosulGame` Xcode target copies the standalone runtime payload during the
build. The payload is generated from `release/mosulgame_runtime_resources.json`
and intentionally excludes source art, build outputs, snapshots, and
candidate/provenance folders.

`modernerKrieg` does not drive Mosul release numbering yet. For now, capture its exact linked submodule commit in the Mosul release by committing the desired gitlink and packaging the initialized submodule source into `dist/mosul-src-<VERSION>.zip`.

## 2. Write the Release Synopsis

Create an approximately 200-word synopsis for this version before packaging the release. Summarize the user-facing MOSUL Mac app changes first, then call out major `modernerKrieg` core, scenario, asset, replay, file-format, source-compatibility, or platform changes that matter to downstream users. Use this synopsis as the GitHub release description.

Include the `modernerKrieg` submodule commit in the release notes:

```bash
git submodule status --recursive
```

## 3. Lock And Tag The Source

Make sure the desired `modernerKrieg` revision is checked out, initialized, and committed as the Mosul submodule gitlink before tagging:

```bash
git submodule update --init --recursive
git status --short
git submodule status --recursive
```

After the version number is decided and the final release commit is ready, tag the Mosul source code with the matching version number. The tag must point at the exact commit used to build the DMGs and source archive.

```bash
VERSION="<VERSION>"
git tag -a "v${VERSION}" -m "MOSUL ${VERSION}"
git push origin "v${VERSION}"
```

If the release version changes, update `VERSION` and recreate the tag before publishing it.

## Release Candidate Shortcut

Before manual DMG packaging, run the local release-candidate gates:

```bash
scripts/check_mosulgame_accessibility_ui.sh
python3 scripts/write_mosulgame_audio_report.py --output snapshots/evidence/mosul-audio-release.txt
scripts/check_mosulgame_audio_smoke.sh
scripts/build_mosulgame_release_candidate.sh
```

The accessibility check writes ignored evidence to
`snapshots/evidence/mosul-accessibility-ui.*`. The release-candidate builder
keeps the app bundle named `MosulGame.app`, writes architecture-specific
folders under `dist/release-candidate/`, validates bundled runtime resources,
ad-hoc signs by default, and records `lipo` results in
`snapshots/evidence/mosul-release-candidate.txt`.

The audio report and audio smoke write ignored evidence under
`snapshots/evidence/`. The report checks manifest/license/transcript/caption
metadata without launching the app; the smoke check verifies the bundled
`AVAudioEngine` path, mute controls, radio captions, and event-driven cue
loading from the built app bundle.

The manual Apple Silicon and Intel sections below remain the underlying build,
signing, and DMG packaging flow. Later release automation should package the
candidate app folders into DMGs without changing the app bundle name.

## 4. Build Apple Silicon

From the repository root:

```bash
mkdir -p dist
VERSION="<VERSION>"
xcodebuild \
  -project MosulGame.xcodeproj \
  -scheme MosulGame \
  -configuration Release \
  -destination "generic/platform=macOS" \
  -derivedDataPath build/release-derived-data-arm64 \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=NO \
  CODE_SIGNING_ALLOWED=NO \
  build
```

The unsigned build output is:

```text
build/release-derived-data-arm64/Build/Products/Release/MosulGame.app
```

Ad-hoc sign the generated app if Developer ID signing is not available:

```bash
codesign --force --deep --sign - "build/release-derived-data-arm64/Build/Products/Release/MosulGame.app"
```

If you have Developer ID and notarization credentials, sign and notarize instead of ad-hoc signing:

```bash
VERSION="<VERSION>"
codesign --force --deep --options runtime --timestamp --sign "$DEVELOPER_ID_APPLICATION" "build/release-derived-data-arm64/Build/Products/Release/MosulGame.app"
ditto -c -k --keepParent "build/release-derived-data-arm64/Build/Products/Release/MosulGame.app" "dist/mosul-mac-silicon-${VERSION}-notary.zip"
xcrun notarytool submit "dist/mosul-mac-silicon-${VERSION}-notary.zip" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "build/release-derived-data-arm64/Build/Products/Release/MosulGame.app"
```

Package the DMG:

```bash
VERSION="<VERSION>"
hdiutil create \
  -volname "MOSUL ${VERSION} Apple Silicon" \
  -srcfolder "build/release-derived-data-arm64/Build/Products/Release/MosulGame.app" \
  -format UDZO \
  -ov \
  "dist/mosul-mac-silicon-${VERSION}.dmg"
```

Verify the architecture:

```bash
lipo -info "build/release-derived-data-arm64/Build/Products/Release/MosulGame.app/Contents/MacOS/MosulGame"
```

## 5. Build Intel

```bash
VERSION="<VERSION>"
xcodebuild \
  -project MosulGame.xcodeproj \
  -scheme MosulGame \
  -configuration Release \
  -destination "generic/platform=macOS" \
  -derivedDataPath build/release-derived-data-x86_64 \
  ARCHS=x86_64 \
  ONLY_ACTIVE_ARCH=NO \
  CODE_SIGNING_ALLOWED=NO \
  build
```

The unsigned build output is:

```text
build/release-derived-data-x86_64/Build/Products/Release/MosulGame.app
```

Ad-hoc sign the generated app if Developer ID signing is not available:

```bash
codesign --force --deep --sign - "build/release-derived-data-x86_64/Build/Products/Release/MosulGame.app"
```

If you have Developer ID and notarization credentials, use the same signing, notary submission, and stapling flow described in the Apple Silicon section, with the x86_64 app path and an Intel-specific notary zip name.

Package the DMG:

```bash
VERSION="<VERSION>"
hdiutil create \
  -volname "MOSUL ${VERSION} Intel" \
  -srcfolder "build/release-derived-data-x86_64/Build/Products/Release/MosulGame.app" \
  -format UDZO \
  -ov \
  "dist/mosul-mac-intel-${VERSION}.dmg"
```

Verify the architecture:

```bash
lipo -info "build/release-derived-data-x86_64/Build/Products/Release/MosulGame.app/Contents/MacOS/MosulGame"
```

## 6. Create The Source Package

Do not rely on GitHub's automatic source archives for Mosul releases. Those archives may omit the populated `modernerKrieg` submodule source. Create and attach the Mosul source archive below instead.

Stage the source into a versioned folder so the archive has a stable top-level directory. Exclude VCS folders, build outputs, release artifacts, local Xcode user state, and Finder metadata.

```bash
VERSION="<VERSION>"
SRC_ROOT="mosul-${VERSION}"
SRC_STAGE="$(mktemp -d)/${SRC_ROOT}"
git submodule update --init --recursive
rsync -a ./ "$SRC_STAGE"/ \
  --exclude .git \
  --exclude build \
  --exclude dist \
  --exclude "*.xcuserstate" \
  --exclude "xcuserdata" \
  --exclude ".DS_Store"
git rev-parse HEAD > "$SRC_STAGE/RELEASE_MOSUL_REVISION.txt"
git -C modernerKrieg rev-parse HEAD > "$SRC_STAGE/RELEASE_MODERNERKRIEG_REVISION.txt"
git submodule status --recursive > "$SRC_STAGE/RELEASE_SUBMODULES.txt"
test -f "$SRC_STAGE/modernerKrieg/CMakeLists.txt"
test -f "$SRC_STAGE/modernerKrieg/assets/mosul/runtime/maps/market_commercial_streets_2003/overview.png"
ditto -c -k --keepParent "$SRC_STAGE" "dist/mosul-src-${VERSION}.zip"
```

The resulting zip intentionally contains `modernerKrieg` source, scenarios, manifests, and runtime PNG assets from the linked submodule checkout.

## 7. Verify Release Artifacts

```bash
VERSION="<VERSION>"
ls -lh \
  "dist/mosul-mac-silicon-${VERSION}.dmg" \
  "dist/mosul-mac-intel-${VERSION}.dmg" \
  "dist/mosul-src-${VERSION}.zip"
shasum -a 256 \
  "dist/mosul-mac-silicon-${VERSION}.dmg" \
  "dist/mosul-mac-intel-${VERSION}.dmg" \
  "dist/mosul-src-${VERSION}.zip"
```

Verify the source archive contains the submodule payload:

```bash
VERSION="<VERSION>"
VERIFY_DIR="$(mktemp -d)"
ditto -x -k "dist/mosul-src-${VERSION}.zip" "$VERIFY_DIR"
test -f "$VERIFY_DIR/mosul-${VERSION}/modernerKrieg/CMakeLists.txt"
test -f "$VERIFY_DIR/mosul-${VERSION}/modernerKrieg/engine/core/include/mk_core.h"
test -f "$VERIFY_DIR/mosul-${VERSION}/modernerKrieg/assets/mosul/runtime/maps/market_commercial_streets_2003/overview.png"
```

Attach these files to the GitHub release:

```text
dist/mosul-mac-silicon-<VERSION>.dmg
dist/mosul-mac-intel-<VERSION>.dmg
dist/mosul-src-<VERSION>.zip
```
