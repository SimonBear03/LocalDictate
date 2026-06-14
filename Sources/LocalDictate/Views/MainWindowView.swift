import SwiftUI

struct MainWindowView: View {
    @EnvironmentObject private var model: LocalDictateModel
    @State private var selection: SidebarSection? = .history

    var body: some View {
        NavigationSplitView {
            List(SidebarSection.allCases, selection: $selection) { section in
                Label(section.title, systemImage: section.systemImage)
                    .tag(section)
            }
            .listStyle(.sidebar)
            .navigationTitle("LocalDictate")
        } detail: {
            switch selection ?? .history {
            case .history:
                HistoryView(store: model.historyStore)
            case .templates:
                TemplatesView(store: model.templateStore, selectedTemplateID: $model.selectedTemplateID)
            case .privacy:
                PrivacyView()
            case .diagnostics:
                DiagnosticsView()
            }
        }
        .toolbar {
            ToolbarItemGroup {
                Button {
                    model.toggleRecording()
                } label: {
                    Label(model.status == .listening ? "Stop Recording" : "Start Recording", systemImage: model.status == .listening ? "stop.fill" : "mic.fill")
                }

                Button {
                    model.insertLatest()
                } label: {
                    Label("Insert", systemImage: "arrow.down.doc")
                }
                .disabled(model.cleanedText.isEmpty)
            }
        }
    }
}

