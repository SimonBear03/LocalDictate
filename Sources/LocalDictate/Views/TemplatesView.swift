import LocalDictateCore
import SwiftUI

struct TemplatesView: View {
    @ObservedObject var store: TemplateStore
    @Binding var selectedTemplateID: UUID
    @State private var selectedTemplateListID: CleanupTemplate.ID?

    private var selectedTemplate: CleanupTemplate? {
        store.templates.first { $0.id == selectedTemplateListID } ?? store.templates.first { $0.id == selectedTemplateID } ?? store.templates.first
    }

    var body: some View {
        HSplitView {
            List(store.templates, selection: $selectedTemplateListID) { template in
                VStack(alignment: .leading, spacing: 4) {
                    Text(template.name)
                        .font(.headline)
                    Text(template.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                .padding(.vertical, 4)
                .tag(template.id)
            }
            .frame(minWidth: 260, idealWidth: 320)
            .systemSidebarSurface()

            if let selectedTemplate {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(selectedTemplate.name)
                                .font(.title2.weight(.semibold))
                            Text(selectedTemplate.summary)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(selectedTemplate.id == selectedTemplateID ? "Default" : "Use Template") {
                            selectedTemplateID = selectedTemplate.id
                        }
                        .disabled(selectedTemplate.id == selectedTemplateID)
                    }

                    Text("Prompt")
                        .font(.headline)
                    ScrollView {
                        Text(selectedTemplate.prompt)
                            .font(.body.monospaced())
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                    }
                    .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(.quaternary)
                    )
                        .frame(minHeight: 260)

                    Text("The default cleanup prompt is read-only in this first pass. It is intentionally conservative and avoids rewriting your wording.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(24)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .systemWindowSurface()
            } else {
                ContentUnavailableView("No Templates", systemImage: "text.badge.star")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .systemWindowSurface()
            }
        }
        .systemWindowSurface()
        .navigationTitle("Templates")
    }
}
