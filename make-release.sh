#!/bin/bash
# Builds an anonymous, universal (Apple Silicon + Intel) Pebble.dmg and copies it into the website.
# Ad-hoc signed: no Apple account or personal identity is embedded.
# Before running: raise CFBundleShortVersionString (and CFBundleVersion) in Resources/Info.plist.
# Optional release notes: RELEASE_NOTES="Fixed X, added Y" ./make-release.sh
# Afterwards: git add -A && git commit -m "Pebble vX.Y.Z" && git push   (Vercel redeploys; installed apps see the update)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
cd "$ROOT"
export CLANG_MODULE_CACHE_PATH="$ROOT/.build/module-cache"
export SWIFT_MODULECACHE_PATH="$ROOT/.build/module-cache"

for T in arm64-apple-macosx14.0 x86_64-apple-macosx14.0; do
  echo "Building $T..."
  swift build --disable-sandbox -c release --triple "$T" --scratch-path ".build/rel-${T%%-*}" \
    -Xswiftc -module-cache-path -Xswiftc "$ROOT/.build/module-cache"
done

APP="dist/Pebble.app"
rm -rf dist
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
lipo -create .build/rel-arm64/release/PebbleCompanion .build/rel-x86_64/release/PebbleCompanion \
  -output "$APP/Contents/MacOS/PebbleCompanion"
strip -x "$APP/Contents/MacOS/PebbleCompanion"
cp Resources/Info.plist "$APP/Contents/Info.plist"
chmod +x "$APP/Contents/MacOS/PebbleCompanion"
xattr -cr "$APP"
codesign --force --deep --sign - --timestamp=none "$APP"
codesign --verify --deep --strict "$APP"

if strings -a "$APP/Contents/MacOS/PebbleCompanion" | grep -qiE "/Users/|$(whoami)"; then
  echo "Refusing to package: the binary contains a personal path or username." >&2
  exit 1
fi

mkdir -p dist/dmgroot
cp -R "$APP" dist/dmgroot/
ln -s /Applications dist/dmgroot/Applications
hdiutil create -quiet -volname "Pebble" -srcfolder dist/dmgroot -fs HFS+ -format UDZO \
  -imagekey zlib-level=9 dist/Pebble.dmg
xattr -c dist/Pebble.dmg

mkdir -p website/download
cp dist/Pebble.dmg website/download/Pebble.dmg

# Tell installed copies of Pebble that this version exists (read by UpdateChecker.swift).
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" Resources/Info.plist)
BUILD=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" Resources/Info.plist)
VERSION="$VERSION" BUILD="$BUILD" NOTES="${RELEASE_NOTES:-}" python3 -c '
import json, os
json.dump({"version": os.environ["VERSION"], "build": int(os.environ["BUILD"]),
           "url": "https://pebble-focus.vercel.app/download/Pebble.dmg",
           "notes": os.environ["NOTES"]}, open("website/version.json", "w"), indent=2)
open("website/version.json", "a").write("\n")'
echo "Published website/version.json -> $VERSION"
echo "Done: website/download/Pebble.dmg ($(du -h dist/Pebble.dmg | cut -f1))"
