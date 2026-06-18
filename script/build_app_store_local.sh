#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DERIVED_DATA_PATH="${LOCALDICTATE_DERIVED_DATA_PATH:-$ROOT_DIR/.build/xcode-derived}"
PROJECT_PATH="$ROOT_DIR/LocalDictate.xcodeproj"
SCHEME="LocalDictate"
CONFIGURATION="${LOCALDICTATE_CONFIGURATION:-Release}"

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -destination "generic/platform=macOS" \
  -configuration "$CONFIGURATION" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO \
  DEVELOPMENT_TEAM="" \
  clean build

APP_PATH="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION/LocalDictate.app"

if [ ! -d "$APP_PATH" ]; then
  echo "error: expected app bundle not found at $APP_PATH" >&2
  exit 1
fi

echo "Built $APP_PATH"
codesign -dvvv --entitlements - "$APP_PATH"
plutil -p "$APP_PATH/Contents/Info.plist"
