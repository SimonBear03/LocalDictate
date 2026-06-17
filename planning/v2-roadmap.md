# LocalDictate V2 Roadmap Notes

LocalDictate V1 remains a Mac-first, local-first dictation app. These notes
capture V2 ideas that should be designed deliberately instead of being slipped
into V1 piecemeal.

## Product Direction

V2 should keep the app useful offline while adding optional higher-quality
cleanup and a more adaptive native macOS interface.

The core product promise remains:

- Speech-to-text should work locally when Apple local speech assets are
  available.
- Cleanup should be optional and should never block access to the raw
  transcript.
- Cloud or network-backed features must be explicit, explainable, and optional.

## Engine Selector

Add an explicit cleanup/transcript engine selector:

- Raw Transcript: no cleanup. Fastest and most predictable.
- Local Apple Model: on-device Foundation Models cleanup. Default for V2 unless
  user chooses otherwise.
- Apple Private Cloud: macOS 27+ Private Cloud Compute model. Optional, network
  required, stronger cleanup expected.
- Auto: prefer local, fall back according to user settings.

The selector should make clear that speech recognition and text cleanup are
separate stages.

## Apple Private Cloud Compute

Investigate and add Apple Private Cloud Compute as an optional cleanup engine.

Open questions:

- What quota or usage limits does Apple expose through `quotaUsage`?
- Which failures are runtime recoverable versus user-actionable?
- How should the UI explain that this is private but not offline?
- Should Auto mode ever use Private Cloud without explicit opt-in?

Expected behavior:

- Check model availability before showing it as ready.
- Show quota/availability state when Apple exposes it.
- Handle quota/network/service errors without losing the transcript.
- Fall back to Local Apple Model or Raw Transcript depending on settings.
- Make privacy copy clear: local works offline; Private Cloud needs network.

## Foundation Models Diagnostics

Improve error handling for Foundation Models and future Private Cloud cleanup.

User-facing diagnostic categories should include:

- Apple Intelligence disabled.
- Device not eligible.
- Model not ready or assets still downloading.
- Unsupported locale.
- Context too large.
- Guardrail/refusal.
- Rate or quota limited.
- Concurrent request.
- Network failure.
- Service unavailable.
- Unknown model error.

The app should preserve the raw transcript for every cleanup failure.

## Raw Transcript Fallback

Make raw transcript fallback an explicit product behavior.

Desired flow:

- Dictation always produces raw text first.
- Cleanup runs only after raw text exists.
- If cleanup succeeds, insertion uses the selected output mode.
- If cleanup fails, the raw transcript remains available and can optionally be
  inserted automatically.
- Diagnostics should say cleanup failed without implying dictation failed.

## Native macOS UI And Liquid Glass

Use macOS native structure first, then Liquid Glass where it improves the app.

V2 should address current layout issues before adding visual treatment:

- Stable minimum window size.
- Comfortable left-half-screen layout.
- No page-specific width expansion bugs.
- Sidebar and content should adapt cleanly across sections.
- Native toolbar/status presentation.
- Standard macOS controls and semantic colors.
- Remove custom backgrounds that fight system materials.
- Use custom glass only for app-specific surfaces, such as a floating dictation
  preview, not for basic sidebars or settings rows.

## Non-Goals For V1

- Do not make V1 depend on macOS 27-only APIs.
- Do not make Private Cloud Compute part of V1.
- Do not add online model providers in V1.
- Do not weaken the local-first privacy story.
