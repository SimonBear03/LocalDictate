import LocalDictateCore
import SwiftUI

struct MenuBarContentView: View {
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject private var model: LocalDictateModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            statusHeader

            if !model.liveTranscript.isEmpty || !model.cleanedText.isEmpty {
                transcriptPreview
            }

            if let latestError = model.latestError {
                Label(latestError, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .lineLimit(3)
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                StatusLine(label: "Speech", value: model.speechAvailability.state.title, tint: model.speechAvailability.state.tint)
                StatusLine(label: "Cleanup", value: model.cleanupAvailability.state.title, tint: model.cleanupAvailability.state.tint)
                StatusLine(label: "API", value: model.localAPIService.status.isEnabled ? "Enabled" : "Off", tint: .secondary)
            }
            .font(.caption)

            Divider()

            ControlGroup {
                Button("Open") {
                    openWindow(id: WindowID.main.rawValue)
                    WindowFocusService.focusMainWindow()
                }
                Button("Settings") {
                    model.selectedSidebarSection = .settings
                    openWindow(id: WindowID.main.rawValue)
                    WindowFocusService.focusMainWindow()
                }
                Button("Quit") {
                    NSApp.terminate(nil)
                }
            }
            .controlSize(.small)
        }
        .padding(16)
        .frame(width: 340)
        .systemWindowSurface()
        .task {
            await model.refreshSystemState()
        }
    }

    private var statusHeader: some View {
        HStack(spacing: 12) {
            Image(systemName: model.status.systemImage)
                .foregroundStyle(model.status.tint)
                .font(.title2)
                .symbolVariant(.circle.fill)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(model.status.menuTitle)
                    .font(.headline)
                Text(statusDetail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
    }

    private var transcriptPreview: some View {
        GroupBox(model.cleanedText.isEmpty ? "Transcript" : "Cleaned Text") {
            ScrollView {
                Text(transcriptText)
                    .font(.body)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 2)
            }
            .frame(height: transcriptBoxHeight)
        }
    }

    private var transcriptText: String {
        model.cleanedText.isEmpty ? model.liveTranscript : model.cleanedText
    }

    private var transcriptBoxHeight: CGFloat {
        let lineCount = estimatedTranscriptLineCount(for: transcriptText)
        let visibleLineCount = min(max(lineCount, 1), 7)
        return CGFloat(visibleLineCount) * 22 + 10
    }

    private func estimatedTranscriptLineCount(for text: String) -> Int {
        let charactersPerLine = 34
        let paragraphs = text.split(separator: "\n", omittingEmptySubsequences: false)

        return max(
            1,
            paragraphs.reduce(0) { partialResult, paragraph in
                let characterCount = max(paragraph.count, 1)
                return partialResult + max(1, Int(ceil(Double(characterCount) / Double(charactersPerLine))))
            }
        )
    }

    private var statusDetail: String {
        switch model.status {
        case .idle: "Ready for local voice typing."
        case .listening: "Recording from the selected microphone."
        case .transcribing: "Converting speech to text locally."
        case .cleaning: "Cleaning text with the selected template."
        case .ready: "Cleaned text is ready."
        case .inserted: "Text was pasted into the target app."
        case .error: "Open diagnostics for details."
        }
    }
}

private struct StatusLine: View {
    var label: String
    var value: String
    var tint: Color

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Circle()
                .fill(tint)
                .frame(width: 7, height: 7)
            Text(value)
        }
    }
}
