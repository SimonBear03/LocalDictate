import LocalDictateCore
import SwiftUI

struct TemplatesView: View {
    @ObservedObject var store: TemplateStore
    @Binding var selectedTemplateID: UUID
    @State private var selectedListTemplateID: UUID?
    @State private var searchText = ""

    private var filteredTemplates: [CleanupTemplate] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return store.templates
        }

        return store.templates.filter {
            $0.searchableText.localizedCaseInsensitiveContains(query)
        }
    }

    private var effectiveSelectedTemplateID: UUID? {
        if let selectedListTemplateID, filteredTemplates.contains(where: { $0.id == selectedListTemplateID }) {
            return selectedListTemplateID
        }
        if filteredTemplates.contains(where: { $0.id == selectedTemplateID }) {
            return selectedTemplateID
        }
        return filteredTemplates.first?.id
    }

    private var selectedTemplate: CleanupTemplate? {
        guard let effectiveSelectedTemplateID else {
            return filteredTemplates.first
        }
        return filteredTemplates.first { $0.id == effectiveSelectedTemplateID } ?? filteredTemplates.first
    }

    var body: some View {
        HStack(spacing: 0) {
            TemplateListPane(
                templates: filteredTemplates,
                selectedTemplateID: effectiveSelectedTemplateID,
                defaultTemplateID: selectedTemplateID,
                deleteTemplate: store.delete
            ) { templateID in
                selectedListTemplateID = templateID
            }

            Divider()

            Group {
                if let selectedTemplate {
                    TemplateDetailView(
                        template: selectedTemplate,
                        isDefault: selectedTemplate.id == selectedTemplateID
                    ) {
                        selectedTemplateID = selectedTemplate.id
                    }
                } else {
                    ContentUnavailableView("No Templates", systemImage: "text.badge.star")
                }
            }
            .frame(minWidth: 260, maxWidth: .infinity)
            .systemWindowSurface()
        }
        .systemWindowSurface()
        .navigationTitle("Templates")
        .searchable(text: $searchText, placement: .toolbar, prompt: "Search Templates")
        .onAppear(perform: ensureSelectedTemplateIsVisible)
        .onChange(of: filteredTemplates.map(\.id)) { _, _ in
            ensureSelectedTemplateIsVisible()
        }
    }

    private func ensureSelectedTemplateIsVisible() {
        guard !filteredTemplates.isEmpty else {
            selectedListTemplateID = nil
            return
        }
        if selectedListTemplateID == nil || !filteredTemplates.contains(where: { $0.id == selectedListTemplateID }) {
            selectedListTemplateID = effectiveSelectedTemplateID ?? filteredTemplates.first?.id
        }
    }
}

private struct TemplateListPane: View {
    var templates: [CleanupTemplate]
    var selectedTemplateID: CleanupTemplate.ID?
    var defaultTemplateID: CleanupTemplate.ID
    var deleteTemplate: (CleanupTemplate) -> Void
    var selectTemplate: (CleanupTemplate.ID) -> Void

    var body: some View {
        List(selection: Binding(
            get: { selectedTemplateID },
            set: { newValue in
                if let newValue {
                    selectTemplate(newValue)
                }
            }
        )) {
            ForEach(templates) { template in
                TemplateListRow(
                    template: template,
                    isDefault: template.id == defaultTemplateID
                )
                .tag(template.id)
                .contextMenu {
                    Button("Delete", role: .destructive) {
                        deleteTemplate(template)
                    }
                    .disabled(template.isBuiltIn)
                }
            }
        }
        .listStyle(.plain)
        .frame(width: 235)
        .overlay {
            if templates.isEmpty {
                ContentUnavailableView(
                    "No Results",
                    systemImage: "text.badge.star",
                    description: Text("Try a different search.")
                )
            }
        }
    }
}

private struct TemplateListRow: View {
    var template: CleanupTemplate
    var isDefault: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(template.name)
                    .font(.headline)
                    .lineLimit(1)

                if isDefault {
                    Text("Default")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }

            Text(template.summary)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .padding(.vertical, 8)
    }
}

private struct TemplateDetailView: View {
    var template: CleanupTemplate
    var isDefault: Bool
    var useTemplate: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(template.name)
                            .font(.title.weight(.semibold))
                        Text(template.summary)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if isDefault {
                        Text("Default")
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(.quaternary, in: Capsule())
                    } else {
                        Button("Use Template", action: useTemplate)
                    }
                }

                GroupBox("Prompt") {
                    ScrollView {
                        Text(template.prompt)
                            .font(.body.monospaced())
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxHeight: 420, alignment: .top)
                }

                Text("Custom templates and editing are planned for a later V1 pass. The default prompt stays conservative and avoids rewriting wording.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(28)
            .frame(maxWidth: 760, alignment: .topLeading)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .systemWindowSurface()
    }
}

private extension CleanupTemplate {
    var searchableText: String {
        [
            name,
            summary,
            prompt,
            isBuiltIn ? "built in default" : "custom"
        ]
        .joined(separator: " ")
    }
}
