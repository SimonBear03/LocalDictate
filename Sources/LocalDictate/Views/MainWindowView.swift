import LocalDictateCore
import SwiftUI

struct MainWindowView: View {
    @EnvironmentObject private var model: LocalDictateModel

    var body: some View {
        NavigationSplitView {
            List(SidebarSection.allCases, selection: $model.selectedSidebarSection) { section in
                Label(section.title, systemImage: section.systemImage)
                    .tag(section)
            }
            .listStyle(.sidebar)
            .systemSidebarSurface()
            .navigationTitle("LocalDictate")
        } detail: {
            detailContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .systemWindowSurface()
        }
        .systemWindowSurface()
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    model.toggleRecording()
                } label: {
                    Label(model.status == .listening ? "Stop Recording" : "Start Recording", systemImage: model.status == .listening ? "stop.fill" : "mic.fill")
                }
                .labelStyle(.iconOnly)
                .help(model.status == .listening ? "Stop Recording" : "Start Recording")

                Button {
                    model.insertLatest()
                } label: {
                    Label("Insert", systemImage: "arrow.down.doc")
                }
                .labelStyle(.iconOnly)
                .disabled(model.cleanedText.isEmpty)
                .help("Insert Latest Dictation")
            }

            if #available(macOS 26.0, *) {
                ToolbarSpacer(.fixed)
            }

            ToolbarItem(placement: .primaryAction) {
                ToolbarStatusBadge(status: model.status)
            }
        }
    }

    @ViewBuilder
    private var detailContent: some View {
        switch model.selectedSidebarSection ?? .history {
        case .history:
            HistoryView(store: model.historyStore)
        case .templates:
            TemplatesView(store: model.templateStore, selectedTemplateID: $model.selectedTemplateID)
        case .settings:
            SettingsView()
        case .privacy:
            PrivacyView()
        case .diagnostics:
            DiagnosticsView()
        }
    }
}

private struct ToolbarStatusBadge: View {
    let status: DictationStatus

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: status.systemImage)
                .imageScale(.medium)
                .frame(width: 17, alignment: .center)

            Text(status.title)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .font(.callout.weight(.semibold))
        .foregroundStyle(status.tint)
        .frame(minWidth: 116, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Status, \(status.title)")
        .help("Status: \(status.title)")
    }
}
