import LocalDictateCore
import SwiftUI

struct PrivacyView: View {
    @EnvironmentObject private var model: LocalDictateModel

    var body: some View {
        Form {
            Section {
                Text("LocalDictate is designed to process dictation locally. V1 does not send audio, transcripts, cleanup text, analytics, or diagnostics off device.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .systemGroupedRowSurface()

            Section("Permissions") {
                PermissionRowsView()

                if let permissionNotice = model.permissionNotice {
                    Text(permissionNotice)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Button("Refresh") {
                    Task { await model.refreshSystemState() }
                }
            }
            .systemGroupedRowSurface()

            Section("Data Storage") {
                Text("History is stored in your user Application Support folder. Audio clips are not retained unless enabled in Settings.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .systemGroupedRowSurface()

            Section("App Identity") {
                LabeledContent("Running App") {
                    Text(Bundle.main.bundlePath)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                Text("Accessibility permission must be granted to this exact app copy.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .systemGroupedRowSurface()

            Section("Local API") {
                Text("The local automation API is disabled by default. It will bind only to 127.0.0.1 when enabled.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .systemGroupedRowSurface()
        }
        .formStyle(.grouped)
        .systemWindowSurface()
        .navigationTitle("Privacy")
        .task {
            await model.refreshSystemState()
        }
    }
}
