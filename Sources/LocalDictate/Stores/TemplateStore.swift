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
            templates = CleanupTemplate.builtIns
            save()
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
        templates = [template]
        save()
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
