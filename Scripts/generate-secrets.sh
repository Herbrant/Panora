#!/bin/bash
# Generates Sources/Panora/Scrobbling/Secrets.generated.swift
# Reads credentials from Config.xcconfig if present, otherwise generates a stub.
# Run manually or add as a Run Script build phase in Xcode.

set -euo pipefail

CONFIG_FILE="Config.xcconfig"
OUTPUT_FILE="Sources/Panora/Scrobbling/Secrets.generated.swift"
SRCROOT="${SRCROOT:-$(pwd)}"

cd "$SRCROOT"

if [ ! -f "$CONFIG_FILE" ]; then
  echo "⚠️  $CONFIG_FILE not found. Generating stub."
  cat > "$OUTPUT_FILE" <<- STUBEOF
// Auto-generated. Do not edit.
enum Secrets {
    static let lastfmApiKey: String? = nil
    static let lastfmSharedSecret: String? = nil
}
STUBEOF
  exit 0
fi

# Read key-value pairs from Config.xcconfig (skip comments and blank lines)
eval "$(grep -vE '^\s*(//|#|$)' "$CONFIG_FILE" | sed 's/[[:space:]]*=[[:space:]]*/=/')"

cat > "$OUTPUT_FILE" <<- EOF
// Auto-generated. Do not edit.
enum Secrets {
    static let lastfmApiKey = "${LASTFM_API_KEY:-YOUR_LASTFM_API_KEY}"
    static let lastfmSharedSecret = "${LASTFM_API_SECRET:-YOUR_LASTFM_API_SECRET}"
}
EOF

echo "✅ Generated $OUTPUT_FILE with embedded credentials."
