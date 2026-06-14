import AppKit

enum TargetAppService {
    static func frontmostAppName() -> String {
        NSWorkspace.shared.frontmostApplication?.localizedName ?? "Unknown App"
    }
}

