#!/bin/bash
# Builds, signs, (optionally) notarizes and packages SuperDock. One-time setup: docs/releasing.md.
#
#   scripts/release.sh 0.2.0              # build + DMG in build/dist (ad-hoc signed unless SIGNING_IDENTITY is set)
#   scripts/release.sh 0.2.0 --publish    # also create the GitHub release (requires Developer ID + notarization)
#
# Environment:
#   SIGNING_IDENTITY  "Developer ID Application: Name (TEAMID)". Default "-" (ad-hoc, for local testing only).
#   NOTARY_PROFILE    keychain profile created with `xcrun notarytool store-credentials`. Notarization is skipped without it.
#   SPARKLE_PUBLIC_KEY  output of Sparkle's generate_keys. Without it the build has updates switched off and no appcast is made.
set -euo pipefail

VERSION="${1:?usage: scripts/release.sh <version> [--publish]}"
PUBLISH="${2:-}"
IDENTITY="${SIGNING_IDENTITY:--}"
NOTARY="${NOTARY_PROFILE:-}"
SPARKLE_KEY="${SPARKLE_PUBLIC_KEY:-}"
REPO="apurvamukherjee/SuperDoc"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/build/release"
DIST="$ROOT/build/dist"
cd "$ROOT"

if [[ "$PUBLISH" == "--publish" && ( "$IDENTITY" == "-" || -z "$NOTARY" ) ]]; then
  echo "error: publishing needs SIGNING_IDENTITY (Developer ID) and NOTARY_PROFILE; unsigned builds would be blocked by Gatekeeper" >&2
  exit 1
fi

echo "▸ Building SuperDock $VERSION"
xcodegen -q
BUILD_NUMBER="$(git rev-list --count HEAD)"
# Generic destination builds a universal (Apple silicon + Intel) app.
xcodebuild -project SuperDock.xcodeproj -scheme SuperDock -configuration Release -derivedDataPath "$BUILD" \
  -destination "generic/platform=macOS" \
  MARKETING_VERSION="$VERSION" CURRENT_PROJECT_VERSION="$BUILD_NUMBER" SPARKLE_PUBLIC_KEY="$SPARKLE_KEY" \
  CODE_SIGN_IDENTITY=- build -quiet

rm -rf "$DIST" && mkdir -p "$DIST"
APP="$DIST/SuperDock.app"
ditto "$BUILD/Build/Products/Release/SuperDock.app" "$APP"

echo "▸ Signing with identity: $IDENTITY"
# Inside-out, as Sparkle documents: XPC services, helpers, the framework, then the app. Xcode's own signing
# leaves Sparkle with its upstream Team ID, which macOS refuses to load into an app signed by anyone else.
# Developer ID builds get the hardened runtime and a secure timestamp, both required for notarization. Ad-hoc test
# builds get neither: ad-hoc signatures carry no Team ID, so hardened-runtime library validation would refuse to
# load Sparkle into the app.
OPTIONS=()
[[ "$IDENTITY" != "-" ]] && OPTIONS=(--options runtime --timestamp)
# ${arr[@]+…} because macOS bash 3.2 treats an empty array as unbound under `set -u`.
sign() { codesign --force ${OPTIONS[@]+"${OPTIONS[@]}"} --sign "$IDENTITY" "$@"; }
SPARKLE="$APP/Contents/Frameworks/Sparkle.framework/Versions/B"
sign "$SPARKLE/XPCServices/Installer.xpc"
sign --preserve-metadata=entitlements "$SPARKLE/XPCServices/Downloader.xpc"
sign "$SPARKLE/Autoupdate"
sign "$SPARKLE/Updater.app"
sign "$APP/Contents/Frameworks/Sparkle.framework"
sign --entitlements SuperDock/Resources/SuperDock.entitlements "$APP"
codesign --verify --deep --strict "$APP"

notarize() {
  echo "▸ Notarizing $(basename "$1")"
  xcrun notarytool submit "$1" --keychain-profile "$NOTARY" --wait
}

if [[ -n "$NOTARY" ]]; then
  ZIP="$DIST/SuperDock-notarize.zip"
  ditto -c -k --keepParent "$APP" "$ZIP"
  notarize "$ZIP"
  xcrun stapler staple "$APP"
  rm "$ZIP"
fi

echo "▸ Making DMG"
DMG="$DIST/SuperDock-$VERSION.dmg"
STAGING="$(mktemp -d)"
ditto "$APP" "$STAGING/SuperDock.app"
ln -s /Applications "$STAGING/Applications"
hdiutil create -quiet -volname "SuperDock" -srcfolder "$STAGING" -ov -format UDZO "$DMG"
rm -rf "$STAGING"
if [[ "$IDENTITY" != "-" ]]; then
  codesign --force --timestamp --sign "$IDENTITY" "$DMG"
  [[ -n "$NOTARY" ]] && notarize "$DMG" && xcrun stapler staple "$DMG"
fi

SHA="$(shasum -a 256 "$DMG" | cut -d' ' -f1)"
echo "▸ Updating Homebrew cask (sha256 $SHA)"
sed -i '' -E "s/^  version \".*\"/  version \"$VERSION\"/; s/^  sha256 \".*\"/  sha256 \"$SHA\"/" packaging/homebrew/superdock.rb

if [[ -n "$SPARKLE_KEY" ]]; then
  echo "▸ Generating appcast (signs the DMG with the EdDSA key in your keychain)"
  "$BUILD/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_appcast" \
    --download-url-prefix "https://github.com/$REPO/releases/download/v$VERSION/" "$DIST"
fi

if [[ "$PUBLISH" == "--publish" ]]; then
  echo "▸ Publishing GitHub release v$VERSION"
  ASSETS=("$DMG")
  [[ -f "$DIST/appcast.xml" ]] && ASSETS+=("$DIST/appcast.xml")
  gh release create "v$VERSION" "${ASSETS[@]}" --repo "$REPO" --title "SuperDock $VERSION" --generate-notes
fi

echo "✓ $DMG"
