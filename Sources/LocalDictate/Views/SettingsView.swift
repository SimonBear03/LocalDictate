import LocalDictateCore
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: LocalDictateModel

    var body: some View {
        Form {
            Section("Dictation") {
                Picker("Locale", selection: $model.selectedLocaleIdentifier) {
                    ForEach(LocaleChoice.options(selectedIdentifier: model.selectedLocaleIdentifier)) { choice in
                        Text(choice.title).tag(choice.identifier)
                    }
                }
                Text("Use system default unless a specific recognition locale is needed.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .systemGroupedRowSurface()

            Section("Audio Input") {
                Picker("Input", selection: $model.selectedAudioInputDeviceID) {
                    ForEach(model.audioInputDevices) { device in
                        Text(device.name).tag(device.id)
                    }
                }

                Button("Refresh Inputs") {
                    model.refreshAudioInputDevices()
                }
                .controlSize(.small)
            }
            .systemGroupedRowSurface()

            Section("Hotkey") {
                LabeledContent("Record / Stop") {
                    Text(model.hotkeyDescription)
                        .font(.body.monospaced())
                        .foregroundStyle(.secondary)
                }

                if let hotkeyError = model.hotkeyError {
                    Text(hotkeyError)
                        .font(.callout)
                        .foregroundStyle(.orange)
                } else {
                    Text("Global hotkey is active while LocalDictate is running.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Button("Reconnect Hotkey") {
                    model.registerGlobalHotkey()
                }
            }
            .systemGroupedRowSurface()

            Section("History") {
                Picker("Audio", selection: $model.audioRetention) {
                    ForEach(AudioRetention.allCases) { retention in
                        Text(retention.title).tag(retention)
                    }
                }
                Text("Text history is saved locally. Audio is discarded by default.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .systemGroupedRowSurface()
        }
        .formStyle(.grouped)
        .systemWindowSurface()
        .navigationTitle("Settings")
        .task {
            model.templateStore.load()
            await model.refreshSystemState()
        }
        .onChange(of: model.selectedLocaleIdentifier) { _, _ in
            Task { await model.refreshSystemState() }
        }
    }
}

private struct LocaleChoice: Identifiable {
    var identifier: String
    var title: String

    var id: String { identifier }

    static func options(selectedIdentifier: String) -> [LocaleChoice] {
        var options = [
            LocaleChoice(identifier: Locale.current.identifier, title: "System Default (\(Locale.current.identifier))"),
            LocaleChoice(identifier: "en_US", title: "English (US)"),
            LocaleChoice(identifier: "en_GB", title: "English (UK)"),
            LocaleChoice(identifier: "en_CA", title: "English (Canada)"),
            LocaleChoice(identifier: "zh_Hans", title: "Chinese (Simplified)"),
            LocaleChoice(identifier: "zh_Hant", title: "Chinese (Traditional)"),
            LocaleChoice(identifier: "ja_JP", title: "Japanese"),
            LocaleChoice(identifier: "ko_KR", title: "Korean"),
            LocaleChoice(identifier: "es_ES", title: "Spanish"),
            LocaleChoice(identifier: "fr_FR", title: "French"),
            LocaleChoice(identifier: "de_DE", title: "German")
        ]

        if !options.contains(where: { $0.identifier == selectedIdentifier }) {
            options.insert(LocaleChoice(identifier: selectedIdentifier, title: "Current (\(selectedIdentifier))"), at: 1)
        }

        var seen = Set<String>()
        return options.filter { seen.insert($0.identifier).inserted }
    }
}
