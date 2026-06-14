import LocalDictateCore
import SwiftUI

struct DiagnosticsView: View {
    @EnvironmentObject private var model: LocalDictateModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Diagnostics")
                        .font(.largeTitle.weight(.semibold))
                    Text("Use this when permissions, local models, or insertion behavior need to be inspected.")
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 12) {
                    EngineRow(title: "Speech Engine", availability: model.speechAvailability)
                    EngineRow(title: "Cleanup Engine", availability: model.cleanupAvailability)
                    HStack {
                        Text("Local API")
                            .font(.headline)
                        Spacer()
                        Text(model.localAPIService.status.detail)
                            .foregroundStyle(.secondary)
                    }
                    .padding(12)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                }

                if let latestError = model.latestError {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Latest Error")
                            .font(.headline)
                        Text(latestError)
                            .textSelection(.enabled)
                            .foregroundStyle(.orange)
                    }
                    .padding(12)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                }

                HStack {
                    Button("Refresh") {
                        Task { await model.refreshSystemState() }
                    }
                    Button("Run Cleanup Test") {
                        model.runSampleCleanup()
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Current Transcript")
                        .font(.headline)
                    Text(model.liveTranscript.isEmpty ? "No transcript yet." : model.liveTranscript)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                    Text("Cleaned Text")
                        .font(.headline)
                    Text(model.cleanedText.isEmpty ? "No cleaned text yet." : model.cleanedText)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(28)
            .frame(maxWidth: 820, alignment: .leading)
        }
        .navigationTitle("Diagnostics")
        .task {
            await model.refreshSystemState()
        }
    }
}

private struct EngineRow: View {
    var title: String
    var availability: EngineAvailability

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Circle()
                    .fill(availability.state.tint)
                    .frame(width: 9, height: 9)
                Text(title)
                    .font(.headline)
                Spacer()
                Text(availability.state.title)
                    .foregroundStyle(availability.state.tint)
                    .font(.callout.weight(.medium))
            }
            Text(availability.detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
        .padding(12)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
    }
}
