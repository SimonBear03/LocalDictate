import Foundation
import LocalDictateCore

@MainActor
final class HistoryStore: ObservableObject {
    @Published private(set) var records: [DictationRecord] = []
    @Published private(set) var loadError: String?

    func load() {
        do {
            let url = try AppPaths.historyFileURL()
            guard FileManager.default.fileExists(atPath: url.path) else {
                records = []
                return
            }
            let data = try Data(contentsOf: url)
            records = try JSONDecoder.localDictate.decode([DictationRecord].self, from: data)
                .sorted { $0.createdAt > $1.createdAt }
            loadError = nil
        } catch {
            loadError = error.localizedDescription
        }
    }

    func add(_ record: DictationRecord) {
        records.insert(record, at: 0)
        save()
    }

    func delete(_ record: DictationRecord) {
        records.removeAll { $0.id == record.id }
        save()
    }

    func deleteAll() {
        records.removeAll()
        save()
    }

    private func save() {
        do {
            let url = try AppPaths.historyFileURL()
            let data = try JSONEncoder.localDictate.encode(records)
            try data.write(to: url, options: [.atomic])
            loadError = nil
        } catch {
            loadError = error.localizedDescription
        }
    }
}

