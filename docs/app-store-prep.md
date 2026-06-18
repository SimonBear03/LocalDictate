# LocalDictate App Store Preparation

LocalDictate is being prepared for Mac App Store distribution. V1 remains local-only: it does not upload audio, transcripts, cleanup text, history, diagnostics, or analytics.

## Current Distribution State

- Bundle ID: `com.simonbear.localdictate`
- Minimum macOS: `15.0`
- Release version baseline: `1.0.0`, build `1`
- Xcode project: `LocalDictate.xcodeproj`
- Local Xcode validation: `script/build_app_store_local.sh`
- Local archive validation: `script/archive_app_store_local.sh`
- Lightweight compliance audit: `script/audit_app_store_readiness.sh`
- Current signing for local validation: ad-hoc
- Final App Store signing: blocked until paid Apple Developer Program access is available

## App Store Connect Items To Prepare

- App name: `LocalDictate`
- Platform: macOS
- Primary category: Productivity
- Bundle ID: `com.simonbear.localdictate`
- SKU: choose a stable internal value, for example `localdictate-macos`
- Support URL: required before submission
- Privacy policy URL: required before submission
- Screenshots: required before submission
- Age rating: required before submission
- App Review notes: required because Accessibility and auto-paste are non-obvious

## Public APIs Used

The app should stay on documented Apple platform frameworks and avoid private APIs or temporary sandbox exceptions.

- SwiftUI/AppKit: app shell, windows, menu bar status item, forms, popovers
- AVFoundation: microphone access and audio capture
- Speech: Apple speech recognition and local dictation path where supported
- FoundationModels: local cleanup on supported macOS versions, with raw transcript fallback
- ApplicationServices Accessibility: checking whether the user granted Accessibility permission and identifying focused editable elements
- CoreGraphics events: posting Command-V after the user grants Accessibility
- NSPasteboard: temporary pasteboard insertion and restoration
- OSLog: local diagnostics

## App Review Risk Notes

Accessibility is the main App Review risk. The feature is intentional and user-facing: LocalDictate uses Accessibility only to paste the user's dictated text into the active text field after recording. The app should not read arbitrary screen contents, inspect unrelated controls, automate other workflows, or run hidden background actions.

The App Review notes should explicitly state:

- The app is a local dictation utility.
- Microphone access records the user's dictation.
- Speech Recognition converts voice to text.
- Accessibility is used only for auto-paste into the active text field.
- The app keeps text available in the app if no editable field is focused.
- V1 does not collect or transmit user data.

## Pre-Submission Checks

1. Run `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift test`.
2. Run `script/audit_app_store_readiness.sh`.
3. Run `script/build_app_store_local.sh`.
4. Run `script/archive_app_store_local.sh`.
5. Open `LocalDictate.xcodeproj` in Xcode.
6. Set the paid Apple Developer team once available.
7. Verify App Sandbox remains enabled.
8. Archive with Xcode.
9. Upload to App Store Connect.
10. Use TestFlight before public App Review if available.

## Final Signing Blocker

The checked-in project uses ad-hoc signing for local validation so it can be built before a paid developer account exists. Before App Store upload, update signing in Xcode to the Apple Developer team and Mac App Store distribution profile. Do not submit an ad-hoc signed build.

## Local Xcode Toolchain Note

If `xcodebuild` fails with `IDESimulatorFoundation` or `DVTDownloads` plugin errors, the machine's active developer directory or Xcode first-launch setup is not healthy enough for Xcode archive validation. Check:

```bash
xcode-select -p
/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild -version
```

This repo expects full Xcode, not Command Line Tools, for archive work. The local fix may require opening Xcode once, accepting/installing additional components, running `xcodebuild -runFirstLaunch`, or switching the active developer directory to `/Applications/Xcode.app/Contents/Developer`.
