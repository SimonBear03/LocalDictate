# LocalDictate

LocalDictate is a local-first voice typing app for Mac. It is designed as a native macOS menu bar app with real windows for history, templates, privacy, settings, and diagnostics.

## Current State

This is the current runnable native macOS app:

- Menu bar status and recording controls
- Main SwiftUI window with History, Templates, Settings, Privacy, and Diagnostics
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
- App Store-oriented sandbox entitlement and permission copy
- `localdictate` CLI placeholder for future local API integration

## Build And Run

```bash
./script/build_and_run.sh
```

The script builds with Xcode's toolchain, installs `~/Applications/LocalDictate.app`, ad-hoc signs it with the project entitlements, and opens it as a menu bar app. Keeping one stable installed app bundle avoids duplicate Spotlight entries and reduces repeated macOS permission prompts after rebuilds.

Optional modes:

```bash
./script/build_and_run.sh --verify
./script/build_and_run.sh --logs
./script/build_and_run.sh --telemetry
```

## Test

```bash
xcrun swift test
```

## V1 Boundaries

- V1 is Mac-only.
- V1 is local-only.
- The local automation API is planned but opt-in and disabled in this scaffold.
- Custom template editing, configurable hotkeys, floating preview, and modern `DictationTranscriber` input are future implementation steps.
