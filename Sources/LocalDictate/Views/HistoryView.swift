import LocalDictateCore
import SwiftUI

struct HistoryView: View {
    @ObservedObject var store: HistoryStore
    @State private var selectedRecordID: DictationRecord.ID?
    @State private var searchText = ""

    private var filteredRecords: [DictationRecord] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            return store.records
        }

        return store.records.filter {
            $0.searchableText.localizedCaseInsensitiveContains(query)
        }
    }

    private var selectedRecord: DictationRecord? {
        filteredRecords.first { $0.id == selectedRecordID } ?? filteredRecords.first
    }

    var body: some View {
        HStack(spacing: 0) {
            HistoryListPane(
                records: filteredRecords,
                selectedRecordID: $selectedRecordID,
                deleteRecord: store.delete
            )

            Divider()

            Group {
                if let selectedRecord {
                    HistoryDetailView(record: selectedRecord)
                } else {
                    ContentUnavailableView(
                        searchText.isEmpty ? "No Dictations" : "No Results",
                        systemImage: "text.bubble",
                        description: Text(searchText.isEmpty ? "Record a dictation from the menu bar to build local history." : "Try a different search.")
                    )
                }
            }
            .frame(minWidth: 260, maxWidth: .infinity)
            .systemWindowSurface()
        }
        .systemWindowSurface()
        .navigationTitle("History")
        .searchable(text: $searchText, placement: .toolbar, prompt: "Search History")
        .onAppear(perform: ensureSelectedRecordIsVisible)
        .onChange(of: filteredRecords.map(\.id)) { _, _ in
            ensureSelectedRecordIsVisible()
        }
    }

    private func ensureSelectedRecordIsVisible() {
        guard !filteredRecords.isEmpty else {
            selectedRecordID = nil
            return
        }
        if selectedRecordID == nil || !filteredRecords.contains(where: { $0.id == selectedRecordID }) {
            selectedRecordID = filteredRecords.first?.id
        }
    }
}

private struct HistoryListPane: View {
    var records: [DictationRecord]
    @Binding var selectedRecordID: DictationRecord.ID?
    var deleteRecord: (DictationRecord) -> Void

    var body: some View {
        List(selection: $selectedRecordID) {
            ForEach(records) { record in
                HistoryListRow(record: record)
                    .tag(record.id)
                    .contextMenu {
                        Button("Delete", role: .destructive) {
                            deleteRecord(record)
                        }
                    }
            }
        }
        .listStyle(.plain)
        .frame(width: 240)
        .overlay {
            if records.isEmpty {
                ContentUnavailableView(
                    "No Results",
                    systemImage: "text.bubble",
                    description: Text("Try a different search.")
                )
            }
        }
    }
}

private struct HistoryListRow: View {
    var record: DictationRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(record.previewText)
                .font(.headline)
                .lineLimit(2)
            Text("\(record.createdAt.formatted(date: .abbreviated, time: .shortened)) · \(record.targetAppName)")
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.vertical, 8)
    }
}

private struct HistoryDetailView: View {
    var record: DictationRecord

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(record.createdAt.formatted(date: .complete, time: .shortened))
                        .font(.title2.weight(.semibold))
                    Text("\(record.targetAppName) · \(record.templateName) · \(record.languageIdentifier)")
                        .foregroundStyle(.secondary)
                }

                HStack(alignment: .top, spacing: 16) {
                    TextSection(title: "Raw Transcript", text: record.rawTranscript)
                    TextSection(title: "Cleaned Text", text: record.cleanedText, emptyText: "No cleaned text")
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .systemWindowSurface()
    }
}

private struct TextSection: View {
    var title: String
    var text: String
    var emptyText = "No text"

    var body: some View {
        GroupBox(title) {
            Text(text.isEmpty ? emptyText : text)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

private extension DictationRecord {
    var previewText: String {
        let cleaned = cleanedText.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? rawTranscript : cleaned
    }

    var searchableText: String {
        [
            rawTranscript,
            cleanedText,
            targetAppName,
            templateName,
            languageIdentifier,
            createdAt.formatted(date: .abbreviated, time: .shortened),
            createdAt.formatted(date: .complete, time: .shortened)
        ]
        .joined(separator: " ")
    }
}
