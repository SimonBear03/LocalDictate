# LocalDictate

LocalDictate is a local-first voice typing app for Mac. It is designed as a native macOS app with a menu-bar extra and real windows for history, templates, privacy, settings, and diagnostics.

## Current State

This is the current runnable native macOS app:

- Minimum supported macOS version: macOS 15
- Animated menu bar status item and recording controls
- Main SwiftUI window with History, Templates, Settings, Privacy, and Diagnostics
- Closing the main window keeps LocalDictate running from the menu bar
- `⌘Q` quits LocalDictate normally; the menu bar popover's `Quit` button also quits
- Native macOS sidebar, grouped forms, toolbar controls, group boxes, and menu-bar popover styling
- Settings sidebar page for locale, insertion mode, hotkey status, audio input, and audio retention
- Audio input selection for system default or a specific microphone
- Global `⌘D` recording hotkey while LocalDictate is running
- Microphone, Speech Recognition, and Accessibility permission checks
- Live AVFoundation sample-buffer capture for system/default and selected microphone inputs, with input-level diagnostics
- Local-only Apple speech recognition through live audio buffers
- Live transcript accumulation that handles partial-result revisions, pauses, timestamp resets, and short recognizer regressions
- Speech trace diagnostics showing recognizer accumulator decisions for debugging live transcription resets
- Foundation Models cleanup when available, with raw transcript fallback
- Local history and one conservative default cleanup template
- Conservative cleanup prompt that removes filler words, fixes punctuation/capitalization, and avoids rewriting the user's wording
- Automatic paste by default through pasteboard plus `Cmd+V` when Accessibility is granted; otherwise text is copied
- Dedicated menu bar visual state:
  - idle is clear,
  - recording breathes bright orange,
  - cleanup breathes electric blue,
  - success flashes green three times,
  - real errors flash red three times.
- Permission prompts and permission-required states do not appear as recording activity.
- App Store-oriented sandbox entitlement and permission copy
- Xcode project for Mac App Store preparation
- `localdictate` CLI placeholder for future local API integration

## Build And Run

```bash
./script/build_and_run.sh
```

The script builds with Xcode's toolchain, installs `~/Applications/LocalDictate.app`, ad-hoc signs it with the project entitlements, and opens it as a regular macOS app with a menu-bar extra. Keeping one stable installed app bundle avoids duplicate Spotlight entries and reduces repeated macOS permission prompts after rebuilds.

Optional modes:

```bash
./script/build_and_run.sh --verify
./script/build_and_run.sh --logs
./script/build_and_run.sh --telemetry
```

## App Store Preparation

The release/archive path starts from `LocalDictate.xcodeproj`. The SwiftPM package remains useful for tests and package-level development, but the Xcode project owns the App Store app bundle metadata, asset catalog, entitlements, and archive structure.

Local validation before paid Apple Developer Program signing is available:

```bash
./script/audit_app_store_readiness.sh
./script/build_app_store_local.sh
./script/archive_app_store_local.sh
```

These scripts use ad-hoc signing only to validate the app structure locally. Final App Store upload signing requires a paid Apple Developer Program team configured in Xcode.

## Test

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift test
```

## Fresh Install Verification

For a brand-new machine or first launch after deleting/relocating the app:

1. Remove old copies of LocalDictate from Applications and quit any running instances.
2. Rebuild and launch only from this path:
   - `/Users/simon/Applications/LocalDictate.app`
3. Open the app from Applications (not via `swift run` or the raw `.build` binary).
4. Open **Privacy** and verify:
   - `Accessibility` row points to the same app path shown under `Running App`.
   - `Microphone` and `Speech Recognition` are available after a single `⌘D` permission attempt.
5. Press `⌘D` once:
   - the app should stop at first-run permission prompts if needed.
6. Grant anything requested and press `⌘D` again to start dictation.
7. In Diagnostics, confirm `Speech`, `Cleanup`, and insertion status are present.

This flow should stay stable as long as you keep using `~/Applications/LocalDictate.app` as the only installed copy.

## V1 Boundaries

- V1 is Mac-only.
- V1 is local-only.
- The local automation API is planned but opt-in and disabled in this scaffold.
- Custom template editing, configurable hotkeys, floating preview, and modern `DictationTranscriber` input are future implementation steps.

## V1 Completion Notes

- Permission gating now requires explicit user action on each hotkey attempt:
  - microphone and speech permission prompts run first,
  - accessibility prompt (auto-paste) is included in the same attempt,
  - recording starts only after all prompts are already granted and the user presses `⌘D` again.
- Added explicit identity guidance for Accessibility so duplicate app copies are easier to troubleshoot.
- Auto-paste is the default insertion mode, with full menu-bar and diagnostics visibility.
- Menu bar animation is intentionally separate from text status. `DictationStatus`
  describes workflow text such as `Checking Permissions`, `Permission Needed`,
  `Listening`, `Cleaning`, `Inserting`, `Ready`, and `Inserted`; the menu bar
  color only indicates active recording/cleanup or short success/error flashes.
