#!/bin/bash
# Builds ExposePlus.app (ad-hoc signed) into ./build
set -euo pipefail
cd "$(dirname "$0")/.."
swift build -c release --build-system native --scratch-path "${TMPDIR:-/tmp}/exposeplus-build"
BIN="${TMPDIR:-/tmp}/exposeplus-build/release/ExposePlus"
APP="build/ExposePlus.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN" "$APP/Contents/MacOS/ExposePlus"
cp Resources/Info.plist "$APP/Contents/Info.plist"
mkdir -p "$APP/Contents/Resources"
cp Resources/AppIcon.icns Resources/MenuBarIcon.png "Resources/MenuBarIcon@2x.png" "$APP/Contents/Resources/"
codesign --force --sign - "$APP"
echo "Built $APP"
