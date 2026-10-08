#!/bin/bash
# Builds dist/SplitTunnel.app (universal, ad-hoc signed) and dist/SplitTunnel-<version>.zip.
# Usage: scripts/make-app.sh [version]
set -euo pipefail
cd "$(dirname "$0")/.."
VERSION="${1:-0.1.0}"
APP=dist/SplitTunnel.app

swift build -c release --arch arm64 --arch x86_64
BIN="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/SplitTunnel"

rm -rf dist
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/SplitTunnel"
sed "s/__VERSION__/$VERSION/g" Resources/Info.plist > "$APP/Contents/Info.plist"
cp -R Resources/*.lproj Resources/AppIcon.icns "$APP/Contents/Resources/"
codesign --force --sign - "$APP"
(cd dist && ditto -c -k --keepParent SplitTunnel.app "SplitTunnel-$VERSION.zip")
echo "Built $APP ($VERSION)"
