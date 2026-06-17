import LocalDictateCore
import SwiftUI

struct MainWindowView: View {
    @EnvironmentObject private var model: LocalDictateModel
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            List(SidebarSection.allCases, selection: $model.selectedSidebarSection) { section in
                Label(section.title, systemImage: section.systemImage)
                    .tag(section)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(210)
            .systemSidebarSurface()
        } detail: {
            detailContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .systemWindowSurface()
        }
        .systemWindowSurface()
        .toolbar {
            ToolbarItem(placement: .automatic) {
                HStack(spacing: 6) {
                    Button {
                        model.toggleRecording()
                    } label: {
                        Image(systemName: model.status == .listening ? "stop.fill" : "mic.fill")
                            .font(.callout.weight(.semibold))
                            .frame(width: 18, height: 18)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(model.status == .listening ? .red : .primary)
                    .accessibilityLabel(model.status == .listening ? "Stop Recording" : "Start Recording")
                    .help(model.status == .listening ? "Stop Recording" : "Start Recording")

                    ToolbarStatusIndicator(status: model.status)
                }
                .fixedSize(horizontal: true, vertical: false)
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

private struct ToolbarStatusIndicator: View {
    let status: DictationStatus

    var body: some View {
        Text(status.title)
            .lineLimit(1)
            .font(.callout.weight(.semibold))
            .foregroundStyle(status.tint)
            .fixedSize(horizontal: true, vertical: false)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Status, \(status.title)")
            .help("Status: \(status.title)")
    }
}
