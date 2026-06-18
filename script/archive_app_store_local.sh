#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA_PATH="${LOCALDICTATE_DERIVED_DATA_PATH:-$ROOT_DIR/.build/xcode-derived}"
ARCHIVE_PATH="${LOCALDICTATE_ARCHIVE_PATH:-$ROOT_DIR/.build/archives/LocalDictate.xcarchive}"
PROJECT_PATH="$ROOT_DIR/LocalDictate.xcodeproj"
SCHEME="LocalDictate"

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

xcodebuild archive \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -destination "generic/platform=macOS" \
  -configuration Release \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -archivePath "$ARCHIVE_PATH" \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO \
  DEVELOPMENT_TEAM=""

echo "Archived $ARCHIVE_PATH"
