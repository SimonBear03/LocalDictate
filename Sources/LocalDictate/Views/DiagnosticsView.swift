import LocalDictateCore
import SwiftUI

struct DiagnosticsView: View {
    @EnvironmentObject private var model: LocalDictateModel

    var body: some View {
        Form {
            Section {
                Text("Use this when permissions, local models, or insertion behavior need to be inspected.")
                    .foregroundStyle(.secondary)
            }
            .systemGroupedRowSurface()

            Section("Runtime") {
                EngineRow(title: "Speech Engine", availability: model.speechAvailability)
                EngineRow(title: "Cleanup Engine", availability: model.cleanupAvailability)
                LabeledContent("Global Hotkey") {
                    if let hotkeyError = model.hotkeyError {
                        Text(hotkeyError)
                            .foregroundStyle(.orange)
                    } else {
                        Text("\(model.hotkeyDescription) active")
                            .foregroundStyle(.secondary)
                    }
                }
                LabeledContent("Local API") {
                    Text(model.localAPIService.status.isEnabled ? "Enabled" : "Off")
                        .foregroundStyle(.secondary)
                }
                Text(model.localAPIService.status.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .systemGroupedRowSurface()

            Section("Audio Input") {
                LabeledContent("Selected Input", value: AudioInputDeviceService.displayName(for: model.selectedAudioInputDeviceID))
                if let diagnostics = model.lastAudioDiagnostics {
                    LabeledContent("Actual Input", value: diagnostics.inputDeviceName)
                    LabeledContent("Last Capture", value: diagnostics.summary)
                    LabeledContent("Format", value: diagnostics.formatDescription)
                    if diagnostics.isProbablySilent {
                        Text("The last capture looked silent before transcription. Check System Settings > Sound > Input and make sure the input meter moves while you speak.")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                    if let writeError = diagnostics.writeErrorDescription {
                        Text(writeError)
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                } else {
                    Text("No recording has been inspected yet.")
                        .foregroundStyle(.secondary)
                }
            }
            .systemGroupedRowSurface()

            if let latestError = model.latestError {
                Section("Latest Error") {
                    Text(latestError)
                        .foregroundStyle(.orange)
                }
                .systemGroupedRowSurface()
            }

            Section("Actions") {
                HStack {
                    Button("Refresh") {
                        Task { await model.refreshSystemState() }
                    }
                    Button("Run Cleanup Test") {
                        model.runSampleCleanup()
                    }
                }
            }
            .systemGroupedRowSurface()

            Section("Current Text") {
                TextPreview(title: "Transcript", text: model.liveTranscript.isEmpty ? "No transcript yet." : model.liveTranscript)
                TextPreview(title: "Cleaned Text", text: model.cleanedText.isEmpty ? "No cleaned text yet." : model.cleanedText)
            }
            .systemGroupedRowSurface()

            Section("Speech Trace") {
                if model.speechDebugEvents.isEmpty {
                    Text("Start recording to capture live recognizer decisions.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(model.speechDebugEvents.prefix(20))) { event in
                        SpeechTraceRow(event: event)
                    }
                }
            }
            .systemGroupedRowSurface()
        }
        .formStyle(.grouped)
        .systemWindowSurface()
        .navigationTitle("Diagnostics")
        .task {
            await model.refreshSystemState()
        }
    }
}

private struct SpeechTraceRow: View {
    var event: SpeechRecognitionDebugEvent

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(event.decision.rawValue)
                    .font(.caption.monospaced())
                    .foregroundStyle(decisionTint)
                Spacer()
                Text("\(event.previousCharacters) -> \(event.incomingCharacters) -> \(event.outputCharacters) chars")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Text("windows \(Self.windowText(event.previousWindow)) | \(Self.windowText(event.incomingWindow)) | \(Self.windowText(event.outputWindow))")
                .font(.caption2.monospaced())
                .foregroundStyle(.secondary)

            if !event.incomingPreview.isEmpty {
                Text("In: \(event.incomingPreview)")
                    .font(.caption)
                    .lineLimit(2)
            }
            if !event.outputPreview.isEmpty {
                Text("Out: \(event.outputPreview)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 4)
    }

    private var decisionTint: Color {
        switch event.decision {
        case .acceptedFullRebase, .ignoredShortRegression:
            .orange
        case .appendedAfterTimestampReset:
            .blue
        case .appendedNewWindow, .appendedWithoutTiming:
            .green
        case .emptyIgnored:
            .secondary
        default:
            .primary
        }
    }

    private static func windowText(_ window: TranscriptSegmentWindow?) -> String {
        guard let window else {
            return "--"
        }
        return String(format: "%.2f-%.2f", window.start, window.end)
    }
}

private struct EngineRow: View {
    var title: String
    var availability: EngineAvailability

    var body: some View {
        LabeledContent {
            HStack(spacing: 6) {
                Circle()
                    .fill(availability.state.tint)
                    .frame(width: 8, height: 8)
                Text(availability.state.title)
                    .foregroundStyle(availability.state.tint)
            }
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(availability.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct TextPreview: View {
    var title: String
    var text: String

    var body: some View {
        GroupBox(title) {
            Text(text)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
