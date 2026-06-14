import LocalDictateCore
import SwiftUI

struct HistoryView: View {
    @ObservedObject var store: HistoryStore
    @State private var selectedRecordID: DictationRecord.ID?

    private var selectedRecord: DictationRecord? {
        store.records.first { $0.id == selectedRecordID } ?? store.records.first
    }

    var body: some View {
        HSplitView {
            List(store.records, selection: $selectedRecordID) { record in
                VStack(alignment: .leading, spacing: 4) {
                    Text(record.cleanedText.isEmpty ? record.rawTranscript : record.cleanedText)
                        .font(.headline)
                        .lineLimit(2)
                    Text("\(record.createdAt.formatted(date: .abbreviated, time: .shortened)) · \(record.templateName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .padding(.vertical, 4)
                .tag(record.id)
            }
            .frame(minWidth: 280, idealWidth: 330)

            Group {
                if let selectedRecord {
                    HistoryDetailView(record: selectedRecord) {
                        store.delete(selectedRecord)
                    }
                } else {
                    ContentUnavailableView("No Dictations", systemImage: "text.bubble", description: Text("Record a dictation from the menu bar to build local history."))
                }
            }
            .frame(minWidth: 420)
        }
        .navigationTitle("History")
        .toolbar {
            ToolbarItem {
                Button("Clear History", role: .destructive) {
                    store.deleteAll()
                }
                .disabled(store.records.isEmpty)
            }
        }
    }
}

private struct HistoryDetailView: View {
    var record: DictationRecord
    var onDelete: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(record.createdAt.formatted(date: .complete, time: .shortened))
                            .font(.title3.weight(.semibold))
                        Text("\(record.targetAppName) · \(record.languageIdentifier)")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Delete", role: .destructive, action: onDelete)
                }

                TextSection(title: "Cleaned Text", text: record.cleanedText)
                TextSection(title: "Raw Transcript", text: record.rawTranscript)
            }
            .padding(24)
        }
    }
}

private struct TextSection: View {
    var title: String
    var text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(text.isEmpty ? "No text" : text)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
        }
    }
}

