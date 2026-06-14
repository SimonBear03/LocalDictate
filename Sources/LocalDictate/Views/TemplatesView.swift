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
                    TextEditor(text: .constant(selectedTemplate.prompt))
                        .font(.body.monospaced())
                        .textSelection(.enabled)
                        .frame(minHeight: 260)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(.quaternary)
                        )

                    Text("Built-in templates are read-only in this first pass. Custom template editing is the next feature surface.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(24)
            } else {
                ContentUnavailableView("No Templates", systemImage: "text.badge.star")
            }
        }
        .navigationTitle("Templates")
    }
}

