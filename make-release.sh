#!/bin/bash
# Builds an anonymous, universal (Apple Silicon + Intel) Pebble.dmg and copies it into the website.
# Ad-hoc signed: no Apple account or personal identity is embedded.
# Afterwards: cd website && git add -A && git commit -m "New Pebble build" && git push   (Vercel redeploys)
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
echo "Done: website/download/Pebble.dmg ($(du -h dist/Pebble.dmg | cut -f1))"
