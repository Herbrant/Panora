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
echo "Done."
