import LocalDictateCore
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: LocalDictateModel

    var body: some View {
        Form {
            Section("Dictation") {
                Picker("Default Template", selection: $model.selectedTemplateID) {
                    ForEach(model.templateStore.templates) { template in
                        Text(template.name).tag(template.id)
                    }
                }

                TextField("Locale", text: $model.selectedLocaleIdentifier)
                    .textFieldStyle(.roundedBorder)
                    .help("Use BCP-47 identifiers such as en-US or zh-Hans.")
            }

            Section("Insertion") {
                Picker("Mode", selection: $model.insertionMode) {
                    ForEach(InsertionMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                Text("Auto Paste requires Accessibility permission. Copy Only never posts keyboard events.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("History") {
                Picker("Audio", selection: $model.audioRetention) {
                    ForEach(AudioRetention.allCases) { retention in
                        Text(retention.title).tag(retention)
                    }
                }
                Text("Text history is saved locally. Audio is discarded by default.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Permissions") {
                HStack {
                    Button("Request Microphone + Speech") {
                        model.requestCorePermissions()
                    }
                    Button("Request Accessibility") {
                        model.requestAccessibility()
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding(20)
        .task {
            model.templateStore.load()
            await model.refreshSystemState()
        }
    }
}

