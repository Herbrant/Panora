#!/bin/bash
set -euo pipefail

SRCROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$SRCROOT/.build/release"
APP_BUNDLE="$BUILD_DIR/Panora.app"

echo "Creating $APP_BUNDLE …"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"
cp "$BUILD_DIR/Panora" "$APP_BUNDLE/Contents/MacOS/Panora"
cp "$SRCROOT/Sources/Panora/Info.plist" "$APP_BUNDLE/Contents/Info.plist"
echo "Done."
