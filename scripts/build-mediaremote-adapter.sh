#!/bin/bash
# Rebuilds Vendor/MediaRemoteAdapter from a pinned release of github.com/ungive/mediaremote-adapter (BSD-3-Clause).
# Now Playing needs it because MediaRemote only answers Apple-signed binaries since macOS 15.4: the adapter's
# perl script runs under /usr/bin/perl and loads this framework. Plain clang, so no cmake is needed.
set -euo pipefail

TAG="v0.7.7"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/build/mediaremote-adapter-$TAG"
OUT="$ROOT/Vendor/MediaRemoteAdapter"
FW="$OUT/MediaRemoteAdapter.framework"

[[ -d "$SRC" ]] || git clone -q --depth 1 --branch "$TAG" https://github.com/ungive/mediaremote-adapter.git "$SRC"

rm -rf "$FW"
mkdir -p "$FW/Versions/A/Resources"
xcrun clang -dynamiclib -fobjc-arc -fvisibility=default -arch arm64 -arch x86_64 -mmacosx-version-min=14.0 -O2 \
  -install_name @rpath/MediaRemoteAdapter.framework/Versions/A/MediaRemoteAdapter \
  -I "$SRC/include" -I "$SRC/src" \
  -framework Foundation -framework AppKit -framework UniformTypeIdentifiers \
  "$SRC"/src/adapter/*.m "$SRC"/src/private/MediaRemote.m "$SRC"/src/utility/*.m \
  -o "$FW/Versions/A/MediaRemoteAdapter"
cat > "$FW/Versions/A/Resources/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleExecutable</key><string>MediaRemoteAdapter</string>
  <key>CFBundleIdentifier</key><string>com.vandenbe.MediaRemoteAdapter</string>
  <key>CFBundlePackageType</key><string>FMWK</string>
  <key>CFBundleShortVersionString</key><string>${TAG#v}</string>
  <key>CFBundleVersion</key><string>${TAG#v}</string>
</dict></plist>
PLIST
ln -s A "$FW/Versions/Current"
ln -s Versions/Current/MediaRemoteAdapter "$FW/MediaRemoteAdapter"
ln -s Versions/Current/Resources "$FW/Resources"
codesign --force --sign - "$FW"

cp "$SRC/bin/mediaremote-adapter.pl" "$OUT/"
cp "$SRC/LICENSE" "$OUT/LICENSE"
echo "✓ $FW ($(du -sh "$FW" | cut -f1))"
