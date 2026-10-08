#!/bin/bash
# Builds dist/SplitTunnel.app (universal, ad-hoc signed) and dist/SplitTunnel-<version>.zip.
# Usage: scripts/make-app.sh <version>   (x.y.z or x.y.z-suffix; CFBundleVersion gets only x.y.z)
set -euo pipefail
cd "$(dirname "$0")/.."
USAGE="usage: scripts/make-app.sh <version>   (x.y.z or x.y.z-suffix, e.g. 0.1.1 or 0.2.0-rc.1)"
VERSION="${1:-}"
[[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.]+)?$ ]] || { echo "$USAGE" >&2; exit 1; }
BUILD="${VERSION%%-*}"
APP=dist/SplitTunnel.app

swift build -c release --arch arm64 --arch x86_64
BIN="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/SplitTunnel"

rm -rf dist
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/SplitTunnel"
sed -e "s/__VERSION__/$VERSION/g" -e "s/__BUILD__/$BUILD/g" Resources/Info.plist > "$APP/Contents/Info.plist"
cp -R Resources/*.lproj Resources/AppIcon.icns "$APP/Contents/Resources/"
codesign --force --sign - "$APP"
codesign --verify --strict "$APP"
(cd dist && ditto -c -k --keepParent SplitTunnel.app "SplitTunnel-$VERSION.zip")
echo "Built $APP ($VERSION)"
