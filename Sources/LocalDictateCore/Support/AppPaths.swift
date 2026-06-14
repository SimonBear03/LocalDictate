import Foundation

public enum AppPaths {
    public static func applicationSupportDirectory() throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = base.appendingPathComponent("LocalDictate", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    public static func historyFileURL() throws -> URL {
        try applicationSupportDirectory().appendingPathComponent("history.json")
    }

    public static func templatesFileURL() throws -> URL {
        try applicationSupportDirectory().appendingPathComponent("templates.json")
    }

    public static func recordingsDirectory() throws -> URL {
        let directory = try applicationSupportDirectory().appendingPathComponent("Recordings", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}

