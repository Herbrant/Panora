#!/bin/bash
set -euo pipefail

VERSION="${1:?Usage: create-dmg.sh <version>}"
SRCROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$SRCROOT/.build/release/Panora.app"
DMG="$SRCROOT/Panora-${VERSION}.dmg"

hdiutil create -volname "Panora" -srcfolder "$APP" -ov -format UDZO "$DMG"
echo "Created: $DMG"
