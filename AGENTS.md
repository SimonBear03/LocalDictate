# LocalDictate Agent Notes

LocalDictate is a native macOS dictation app. Keep the product Mac-first for v1.

## Build

- Main local run entrypoint: `./script/build_and_run.sh`.
- The run script builds with Xcode, packages `LocalDictate.app`, installs it to
  `~/Applications`, ad-hoc signs it with `LocalDictate.entitlements`, and opens
  the installed app bundle.
- Minimum supported macOS version is macOS 15. The app uses SwiftUI
  `defaultLaunchBehavior(.presented)` so Finder/Application launches reliably
  show the main window.
- Prefer full Xcode's toolchain for SwiftPM commands:
  `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift ...`.
- Tests: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift test`.
- Product build: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift build --product LocalDictate`.
- CLI product: `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcrun swift run localdictate status`.

## Local Runtime And Sandbox Notes

- There are three different validation levels. Be explicit about which one has
  happened:
  1. `swift build` means the code compiles only.
  2. `swift test` means package tests pass only.
  3. `./script/build_and_run.sh --verify` means the installed
     `~/Applications/LocalDictate.app` was rebuilt, signed, opened, and a
     running app process was found.
- Do not tell Simon "the app works" or "you can open it from Applications" after
  only `swift build`, `swift test`, `swift run`, or launching a raw executable.
  For GUI/runtime claims, first run `./script/build_and_run.sh --verify` and
  confirm the app is running from
  `~/Applications/LocalDictate.app/Contents/MacOS/LocalDictate`.
- Do not judge the GUI by running the raw `.build/.../LocalDictate` executable.
  Build and run the app bundle through `./script/build_and_run.sh` so macOS sees
  the correct app identity, Info.plist usage strings, entitlements, and menu bar
  behavior.
- LocalDictate is intentionally a regular macOS app with a menu-bar extra in V1,
  not an `LSUIElement` accessory-only app. Do not re-add `LSUIElement` or
  `NSApp.setActivationPolicy(.accessory)` unless the launch/reopen behavior is
  redesigned and verified.
- macOS permissions such as Accessibility and Microphone attach to the exact app
  bundle identity/path. Keep using the stable `~/Applications/LocalDictate.app`
  install path to avoid duplicate app entries and repeated permission prompts.
- When the UI seems stale, invisible, or "not responding", assume the first
  suspects are an old installed bundle, a still-running old process, a raw
  `.build` executable, or a mismatched app identity. Use the run script to kill,
  rebuild, sign, install, and open the stable bundle before diagnosing app code.
- Some verification cannot complete inside the Codex filesystem sandbox because
  SwiftPM/Xcode writes user-level compiler caches under `~/Library` and
  `~/.cache`, and GUI launching/log streaming are outside normal sandbox scope.
  If a SwiftPM command fails with cache permissions, CLT framework issues, or a
  GUI/open/log restriction, rerun it with the appropriate sandbox escalation.
- The Command Line Tools SwiftPM may fail on this machine with missing
  `BuildServerProtocol`; use `/Applications/Xcode.app` via `DEVELOPER_DIR`.
- Useful local script modes:
  `./script/build_and_run.sh run`,
  `./script/build_and_run.sh --verify`,
  `./script/build_and_run.sh --telemetry`,
  `./script/build_and_run.sh --logs`.

## Design Rules

- Keep the app native: SwiftUI scenes, menu bar extra, semantic colors, SF Symbols, and standard macOS controls.
- Keep V1 local-only. Do not add cloud calls, analytics, or remote diagnostics without an explicit product decision.
- Keep StickS3 integration out of this repo's product language. StickS3 Companion is only a future API client.
- Preserve App Store readiness: sandbox on, minimal entitlements, clear privacy copy, and no private APIs.
- For Apple UI/API references, prefer official Markdown endpoints when the
  normal Developer pages require JavaScript:
  - HIG: `https://docs.developer.apple.com/tutorials/data/design/human-interface-guidelines/<slug>.md`
    such as `buttons.md`, `toolbars.md`, `search-fields.md`, and `sidebars.md`.
  - SwiftUI: `https://docs.developer.apple.com/tutorials/data/documentation/swiftui/<symbol>.md`
    such as `navigationsplitview.md` and `toolbaritemplacement.md`.
  - For overloaded SwiftUI symbols, quote the URL in zsh, for example
    `curl -L 'https://docs.developer.apple.com/tutorials/data/documentation/swiftui/view/searchable(text:placement:prompt:).md'`.
