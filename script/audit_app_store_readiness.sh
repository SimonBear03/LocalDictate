#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

cd "$ROOT_DIR"

echo "== Project =="
xcodebuild -list -project LocalDictate.xcodeproj

echo
echo "== Plists =="
plutil -lint Config/LocalDictate-Info.plist
plutil -lint LocalDictate.entitlements
ruby -rjson -e 'ARGV.each { |path| JSON.parse(File.read(path)); puts "#{path}: OK" }' \
  Resources/Assets.xcassets/Contents.json \
  Resources/Assets.xcassets/AppIcon.appiconset/Contents.json

echo
echo "== Entitlements =="
plutil -p LocalDictate.entitlements
if plutil -p LocalDictate.entitlements | grep -q "temporary-exception"; then
  echo "error: temporary App Sandbox exception entitlement found; document or remove before App Store submission" >&2
  exit 1
fi

echo
echo "== Source API review hints =="
if rg -n "dlopen|dlsym|objc_getClass|NSClassFromString|performSelector|x-apple\\.systempreferences|com\\.apple\\.security\\.temporary-exception|LSUIElement|setActivationPolicy\\(\\.accessory\\)" Sources Config LocalDictate.entitlements; then
  echo "warning: review the matches above before App Store submission" >&2
else
  echo "No obvious private/temporary API markers found by the lightweight scan."
fi

echo
echo "== SwiftPM tests =="
xcrun swift test

echo
echo "App Store readiness audit completed. Final upload signing still requires a paid Apple Developer Program team."
