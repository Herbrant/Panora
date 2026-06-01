#!/bin/bash
# After `swift build`, wraps the raw executable in a minimal .app bundle
# so that XCUIApplication(url:) can find it.
# Usage: ./Scripts/bundle-app.sh
set -euo pipefail

SRCROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$SRCROOT"

BUILD_DIR="$SRCROOT/.build/debug"
APP_BUNDLE="$BUILD_DIR/Panora.app"

echo "Creating $APP_BUNDLE …"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"
cp "$BUILD_DIR/Panora" "$APP_BUNDLE/Contents/MacOS/Panora"
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
