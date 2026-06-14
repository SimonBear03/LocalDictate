import Foundation
import LocalDictateCore

@MainActor
final class TemplateStore: ObservableObject {
    @Published private(set) var templates: [CleanupTemplate] = CleanupTemplate.builtIns
    @Published private(set) var loadError: String?

    func load() {
        do {
            let url = try AppPaths.templatesFileURL()
            guard FileManager.default.fileExists(atPath: url.path) else {
                templates = CleanupTemplate.builtIns
                save()
                return
            }
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder.localDictate.decode([CleanupTemplate].self, from: data)
            templates = mergeBuiltIns(with: decoded)
            loadError = nil
        } catch {
            templates = CleanupTemplate.builtIns
            loadError = error.localizedDescription
        }
    }

    func template(id: UUID) -> CleanupTemplate {
        templates.first { $0.id == id } ?? CleanupTemplate.builtIns[0]
    }

    func upsert(_ template: CleanupTemplate) {
        if let index = templates.firstIndex(where: { $0.id == template.id }) {
            templates[index] = template
        } else {
            templates.append(template)
        }
        save()
    }

    private func mergeBuiltIns(with decoded: [CleanupTemplate]) -> [CleanupTemplate] {
        var byID = Dictionary(uniqueKeysWithValues: decoded.map { ($0.id, $0) })
        for builtIn in CleanupTemplate.builtIns {
            byID[builtIn.id] = builtIn
        }
        return byID.values.sorted {
            if $0.isBuiltIn != $1.isBuiltIn {
                return $0.isBuiltIn && !$1.isBuiltIn
            }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    private func save() {
        do {
            let url = try AppPaths.templatesFileURL()
            let data = try JSONEncoder.localDictate.encode(templates)
            try data.write(to: url, options: [.atomic])
            loadError = nil
        } catch {
            loadError = error.localizedDescription
        }
    }
}

