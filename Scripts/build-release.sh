#!/bin/bash
set -euo pipefail

SRCROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$SRCROOT/.build/release"
APP_BUNDLE="$BUILD_DIR/Panora.app"

echo "Creating $APP_BUNDLE …"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"
cp "$BUILD_DIR/Panora" "$APP_BUNDLE/Contents/MacOS/Panora"
cp "$BUILD_DIR/libMediaRemoteAdapter.dylib" "$APP_BUNDLE/Contents/MacOS/libMediaRemoteAdapter.dylib"
cp -R "$BUILD_DIR/MediaRemoteAdapter_MediaRemoteAdapter.bundle" "$APP_BUNDLE/MediaRemoteAdapter_MediaRemoteAdapter.bundle"
cp "$SRCROOT/Sources/Panora/Info.plist" "$APP_BUNDLE/Contents/Info.plist"
cp "$SRCROOT/Sources/Panora/Resources/Panora.icns" "$APP_BUNDLE/Contents/Resources/Panora.icns"
cp "$SRCROOT/Sources/Panora/Resources/MenuBarIcon.png" "$APP_BUNDLE/Contents/Resources/MenuBarIcon.png"
cp "$SRCROOT/Sources/Panora/Resources/MenuBarIcon@2x.png" "$APP_BUNDLE/Contents/Resources/MenuBarIcon@2x.png"
cp "$SRCROOT/Sources/Panora/Resources/MenuBarIcon@3x.png" "$APP_BUNDLE/Contents/Resources/MenuBarIcon@3x.png"
if [ -d "$BUILD_DIR/Panora_Panora.bundle" ]; then
    rm -rf "$APP_BUNDLE/Panora_Panora.bundle"
    ditto "$BUILD_DIR/Panora_Panora.bundle" "$APP_BUNDLE/Panora_Panora.bundle"
fi
echo "Done."
