import LocalDictateCore
import SwiftUI

struct PrivacyView: View {
    @EnvironmentObject private var model: LocalDictateModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Privacy")
                        .font(.largeTitle.weight(.semibold))
                    Text("LocalDictate is designed to process dictation locally. V1 does not send audio, transcripts, cleanup text, analytics, or diagnostics off device.")
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 12) {
                    PermissionRow(title: "Microphone", state: model.permissions.microphone, detail: "Needed to record dictation.")
                    PermissionRow(title: "Speech Recognition", state: model.permissions.speech, detail: "Needed for Apple local speech recognition.")
                    PermissionRow(title: "Accessibility", state: model.permissions.accessibility, detail: "Only needed for automatic Cmd+V insertion.")
                }

                HStack {
                    Button("Request Microphone + Speech") {
                        model.requestCorePermissions()
                    }
                    Button("Request Accessibility") {
                        model.requestAccessibility()
                    }
                    Button("Refresh") {
                        Task { await model.refreshSystemState() }
                    }
                }

                Divider()

                VStack(alignment: .leading, spacing: 10) {
                    Text("Data Storage")
                        .font(.title3.weight(.semibold))
                    Text("History is stored in your user Application Support folder. Audio clips are not retained unless enabled in Settings.")
                        .foregroundStyle(.secondary)
                    Text("Local API")
                        .font(.title3.weight(.semibold))
                    Text("The local automation API is disabled by default. It will bind only to 127.0.0.1 when enabled.")
                        .foregroundStyle(.secondary)
                }
            }
            .padding(28)
            .frame(maxWidth: 760, alignment: .leading)
        }
        .navigationTitle("Privacy")
        .task {
            await model.refreshSystemState()
        }
    }
}

private struct PermissionRow: View {
    var title: String
    var state: PermissionState
    var detail: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Circle()
                .fill(state.tint)
                .frame(width: 9, height: 9)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(state.title)
                .font(.callout.weight(.medium))
                .foregroundStyle(state.tint)
        }
        .padding(12)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
    }
}
