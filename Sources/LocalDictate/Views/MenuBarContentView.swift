import LocalDictateCore
import SwiftUI

struct MenuBarContentView: View {
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject private var model: LocalDictateModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: model.status.systemImage)
                    .foregroundStyle(model.status.tint)
                    .font(.title2)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.status.menuTitle)
                        .font(.headline)
                    Text(statusDetail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer()
            }

            if !model.liveTranscript.isEmpty || !model.cleanedText.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    if !model.cleanedText.isEmpty {
                        Text(model.cleanedText)
                            .font(.body)
                            .lineLimit(5)
                    } else {
                        Text(model.liveTranscript)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .lineLimit(5)
                    }
                }
                .padding(10)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
            }

            if let latestError = model.latestError {
                Label(latestError, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .lineLimit(3)
            }

            HStack {
                Button(model.status == .listening ? "Stop" : "Record") {
                    model.toggleRecording()
                }
                .keyboardShortcut(.return, modifiers: [])

                Button("Insert") {
                    model.insertLatest()
                }
                .disabled(model.cleanedText.isEmpty)

                Button("Open") {
                    openWindow(id: WindowID.main.rawValue)
                    NSApp.activate(ignoringOtherApps: true)
                }
            }

            Divider()

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 6) {
                StatusGridRow(label: "Speech", availability: model.speechAvailability)
                StatusGridRow(label: "Cleanup", availability: model.cleanupAvailability)
                GridRow {
                    Text("API")
                        .foregroundStyle(.secondary)
                    Text(model.localAPIService.status.isEnabled ? "Enabled" : "Off")
                }
            }
            .font(.caption)

            HStack {
                SettingsLink {
                    Text("Settings")
                }
                Spacer()
                Button("Quit") {
                    NSApp.terminate(nil)
                }
            }
        }
        .padding(16)
        .frame(width: 360)
        .task {
            await model.refreshSystemState()
        }
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

private struct StatusGridRow: View {
    var label: String
    var availability: EngineAvailability

    var body: some View {
        GridRow {
            Text(label)
                .foregroundStyle(.secondary)
            HStack(spacing: 5) {
                Circle()
                    .fill(availability.state.tint)
                    .frame(width: 7, height: 7)
                Text(availability.state.title)
            }
        }
    }
}

