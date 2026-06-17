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
            .navigationSplitViewColumnWidth(180)
            .systemSidebarSurface()
        } detail: {
            detailContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .systemWindowSurface()
        }
        .systemWindowSurface()
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
