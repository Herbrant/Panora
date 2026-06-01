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
  printf '%s\n' \
    '// Auto-generated. Do not edit.' \
    'enum Secrets {' \
    '    static let lastfmApiKey: String? = nil' \
    '    static let lastfmSharedSecret: String? = nil' \
    '}' > "$OUTPUT_FILE"
  exit 0
fi

trim_whitespace() {
  local value="$1"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  printf '%s' "$value"
}

swift_string_literal() {
  local value="$1"
  value="${value//\\/\\\\}"
  value="${value//\"/\\\"}"
  value="${value//$'\n'/\\n}"
  value="${value//$'\r'/\\r}"
  value="${value//$'\t'/\\t}"
  printf '"%s"' "$value"
}

LASTFM_API_KEY="YOUR_LASTFM_API_KEY"
LASTFM_API_SECRET="YOUR_LASTFM_API_SECRET"

# Read only the expected key-value pairs from Config.xcconfig.
while IFS= read -r line || [ -n "$line" ]; do
  line="$(trim_whitespace "$line")"
  case "$line" in
    ''|\#*|//*)
      continue
      ;;
  esac

  if [[ "$line" =~ ^([^=]+)=(.*)$ ]]; then
    key="$(trim_whitespace "${BASH_REMATCH[1]}")"
    value="$(trim_whitespace "${BASH_REMATCH[2]}")"

    case "$key" in
      LASTFM_API_KEY)
        LASTFM_API_KEY="$value"
        ;;
      LASTFM_API_SECRET)
        LASTFM_API_SECRET="$value"
        ;;
    esac
  fi
done < "$CONFIG_FILE"

{
  printf '%s\n' '// Auto-generated. Do not edit.'
  printf '%s\n' 'enum Secrets {'
  printf '    static let lastfmApiKey = %s\n' "$(swift_string_literal "$LASTFM_API_KEY")"
  printf '    static let lastfmSharedSecret = %s\n' "$(swift_string_literal "$LASTFM_API_SECRET")"
  printf '%s\n' '}'
} > "$OUTPUT_FILE"

echo "✅ Generated $OUTPUT_FILE with embedded credentials."
