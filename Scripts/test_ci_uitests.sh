#!/bin/bash
# Replica esatta dei passi CI per i UI tests (job ui-test in .github/workflows/ci.yml).
set -euo pipefail

SRCROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$SRCROOT"

XCODE_DD="$SRCROOT/.build/xcode-derived"

echo "=== 0. Reset ==="
rm -rf .build uitest-results.xcresult uitest-results
rm -f Sources/Panora/Scrobbling/Secrets.generated.swift

echo "=== 1. Secrets stub ==="
./Scripts/generate-secrets.sh

echo "=== 2. Build (swift build) ==="
swift build

echo "=== 3. Create .app bundle ==="
./Scripts/bundle-app.sh

echo "=== 4. Generate workspace + test plan ==="
./Scripts/generate-xcode-workspace.sh

echo "=== 5. build-for-testing (xcodebuild) ==="
xcodebuild build-for-testing \
    -workspace .swiftpm/xcode/package.xcworkspace \
    -scheme Panora \
    -destination 'platform=macOS' \
    -derivedDataPath "$XCODE_DD" 2>&1

echo "=== 6. Copy .app to products dir ==="
PRODUCTS_DIR="$XCODE_DD/Build/Products/Debug"
cp -R "$SRCROOT/.build/debug/Panora.app" "$PRODUCTS_DIR/Panora.app"

echo "=== 7. Patch .xctestrun ==="
XCTESTRUN=$(find "$XCODE_DD/Build/Products" -name "*.xctestrun" | head -1)
echo "Patching: $XCTESTRUN"
/usr/libexec/PlistBuddy -c "Add :PanoraUITests:IsUITestBundle bool YES" "$XCTESTRUN"
/usr/libexec/PlistBuddy -c "Add :PanoraUITests:UIApplicationPath string __TESTROOT__/Debug/Panora.app" "$XCTESTRUN"

echo "=== 8. test-without-building (xcodebuild) ==="
xcodebuild test-without-building \
    -xctestrun "$XCTESTRUN" \
    -destination 'platform=macOS' \
    -resultBundlePath "$SRCROOT/uitest-results" 2>&1

echo "=== Done ==="
