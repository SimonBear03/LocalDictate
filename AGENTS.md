# LocalDictate Agent Notes

LocalDictate is a native macOS dictation app. Keep the product Mac-first for v1.

## Build

- Main local run entrypoint: `./script/build_and_run.sh`
- Tests: `xcrun swift test`
- CLI product: `xcrun swift run localdictate status`

## Design Rules

- Keep the app native: SwiftUI scenes, menu bar extra, settings scene, semantic colors, SF Symbols, and standard macOS controls.
- Keep V1 local-only. Do not add cloud calls, analytics, or remote diagnostics without an explicit product decision.
- Keep StickS3 integration out of this repo's product language. StickS3 Companion is only a future API client.
- Preserve App Store readiness: sandbox on, minimal entitlements, clear privacy copy, and no private APIs.

