# Release Notes

## 2026-06-19

### v1.0.1 (App Store validation prep)

- Added the Xcode project, app metadata plist, icon asset catalog, and local archive/build validation scripts for Mac App Store preparation.
- Added draft App Review notes, privacy policy copy, and App Store preparation documentation.
- Restored standard macOS `Command-Q` behavior so quitting the app fully terminates LocalDictate, while closing the main window keeps the menu bar utility running.
- Confirmed the App Store readiness audit passes with sandbox and microphone entitlements only.

## 2026-06-17

### V1 (Local-only, Mac-only)

- Stabilized permission flow for one hotkey attempt:
  - microphone and speech prompts are checked first,
  - accessibility prompt for auto-paste is checked in the same pass,
  - recording does not auto-start until user re-triggers `⌘D`.
- Added explicit guidance for Accessibility app identity to handle duplicate LocalDictate entries.
- Added fresh-install verification steps to README.
- Kept V1 local-only by default:
  - local speech stack only,
  - no remote analytics, no remote model calls,
  - history and optional diagnostics kept on-device.

## Known Notes

- If a second `LocalDictate.app` copy exists, Accessibility permissions may still reference the wrong binary.
  Use the Privacy page `Running App` path and keep only this installed copy in permission lists.
