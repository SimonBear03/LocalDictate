import Foundation
import OSLog

struct RuntimeTraceEvent: Codable, Identifiable, Hashable {
    let id: UUID
    let date: Date
    let scope: String
    let message: String
    let details: String?

    init(scope: String, message: String, details: String? = nil) {
        self.id = UUID()
        self.date = Date()
        self.scope = scope
        self.message = message
        self.details = details
    }
}

actor RuntimeDiagnostics {
    static let shared = RuntimeDiagnostics()

    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.simonbear.localdictate", category: "runtime")
    private static let maxFileEvents = 2000
    private static let fileLock = NSLock()

    private let maxEvents = 500
    private var events: [RuntimeTraceEvent] = []

    private static var logFileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let directory = base.appendingPathComponent("LocalDictate")
        let runtimeDirectory = directory.appendingPathComponent("Runtime")
        try? FileManager.default.createDirectory(
            at: runtimeDirectory,
            withIntermediateDirectories: true
        )
        return runtimeDirectory.appendingPathComponent("trace-events.jsonl")
    }

    private var logFileURL: URL {
        Self.logFileURL
    }

    static func log(scope: String, message: String, details: String? = nil) {
        Task.detached {
            await shared.record(scope: scope, message: message, details: details)
        }
    }

    static func logSync(scope: String, message: String, details: String? = nil) {
        let event = RuntimeTraceEvent(scope: scope, message: message, details: details)
        appendToDiskSync(event)
        logger.debug("runtime-scope=\(scope, privacy: .public) message=\(message, privacy: .public) details=\(details ?? "", privacy: .public)")
    }

    static var logFilePath: String {
        logFileURL.path
    }

    func record(scope: String, message: String, details: String? = nil) async {
        let event = RuntimeTraceEvent(scope: scope, message: message, details: details)
        appendInMemory(event)
        await appendToDisk(event)
        Self.logger.debug("runtime-scope=\(scope, privacy: .public) message=\(message, privacy: .public) details=\(details ?? "", privacy: .public)")
    }

    func snapshot(limit: Int) async -> [RuntimeTraceEvent] {
        let diskEvents = Self.readDiskEvents(limit: max(limit, maxEvents))
        var mergedByID = [UUID: RuntimeTraceEvent]()
        for event in events {
            mergedByID[event.id] = event
        }
        for event in diskEvents {
            mergedByID[event.id] = event
        }
        return Array(mergedByID.values)
            .sorted { $0.date > $1.date }
            .prefix(limit)
            .map { $0 }
    }

    func logFilePath() -> String {
        logFileURL.path
    }

    func clear() {
        events.removeAll()
        try? FileManager.default.removeItem(at: logFileURL)
    }

    private func appendInMemory(_ event: RuntimeTraceEvent) {
        events.append(event)
        if events.count > maxEvents {
            events.removeFirst(events.count - maxEvents)
        }
    }

    private func appendToDisk(_ event: RuntimeTraceEvent) async {
        Self.appendToDiskSync(event)
        await trimLogFileIfNeeded()
    }

    private static func appendToDiskSync(_ event: RuntimeTraceEvent) {
        fileLock.lock()
        defer { fileLock.unlock() }

        let line: String
        do {
            let encoded = try JSONEncoder().encode(event)
            line = String(data: encoded, encoding: .utf8) ?? "{\"error\":\"encoding\"}"
        } catch {
            line = "{\"scope\":\"runtime\",\"message\":\"encoding_error\",\"date\":\"\(Date())\",\"details\":\"\(error.localizedDescription)\"}"
        }

        let payload = "\(line)\n"
        if let fileHandle = try? FileHandle(forWritingTo: logFileURL) {
            do {
                try fileHandle.seekToEnd()
                try fileHandle.write(contentsOf: Data(payload.utf8))
                try fileHandle.close()
            } catch {
                Self.logger.warning("Unable to write runtime trace to disk: \(error.localizedDescription, privacy: .public)")
            }
            return
        }

        do {
            try payload.write(to: logFileURL, atomically: true, encoding: .utf8)
        } catch {
            Self.logger.warning("Unable to create runtime trace file: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func trimLogFileIfNeeded() async {
        guard
            let data = try? Data(contentsOf: logFileURL),
            let content = String(data: data, encoding: .utf8)
        else { return }

        let lines = content.split(whereSeparator: \.isNewline)
        guard lines.count > Self.maxFileEvents else { return }

        let tail = lines.suffix(Self.maxFileEvents).joined(separator: "\n")
        let rewritten = "\(tail)\n"
        try? rewritten.write(to: logFileURL, atomically: true, encoding: String.Encoding.utf8)
    }

    private static func readDiskEvents(limit: Int) -> [RuntimeTraceEvent] {
        guard
            let data = try? Data(contentsOf: logFileURL),
            let content = String(data: data, encoding: .utf8)
        else { return [] }

        let decoder = JSONDecoder()
        return content
            .split(whereSeparator: \.isNewline)
            .suffix(limit)
            .compactMap { line in
                guard let data = String(line).data(using: .utf8) else { return nil }
                return try? decoder.decode(RuntimeTraceEvent.self, from: data)
            }
    }
}
