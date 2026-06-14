# LocalDictate

LocalDictate is a local-first voice typing app for Mac. It is designed as a native macOS menu bar app with real windows for history, templates, privacy, settings, and diagnostics.

## Current State

This is the first runnable scaffold:

- Menu bar status and recording controls
- Main SwiftUI window with History, Templates, Privacy, and Diagnostics
- Settings scene for locale, insertion mode, default template, and audio retention
- Microphone, Speech Recognition, and Accessibility permission checks
- WAV recording through `AVAudioRecorder`
- Local-only Apple speech recognition path for recorded files
- Foundation Models cleanup when available, with raw transcript fallback
- Local history and built-in cleanup templates
- App Store-oriented sandbox entitlement and permission copy
- `localdictate` CLI placeholder for future local API integration

## Build And Run

```bash
./script/build_and_run.sh
```

The script builds with Xcode's toolchain, stages `dist/LocalDictate.app`, ad-hoc signs it with the project entitlements, and opens it as a menu bar app.

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
- Custom template editing, global hotkeys, live floating preview, and modern streaming `DictationTranscriber` input are the next implementation steps.

