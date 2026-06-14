import Foundation

public enum EngineState: String, Codable, Sendable {
    case available
    case unavailable
    case downloading
    case unsupported
    case permissionNeeded
    case unknown

    public var title: String {
        switch self {
        case .available: "Available"
        case .unavailable: "Unavailable"
        case .downloading: "Downloading"
        case .unsupported: "Unsupported"
        case .permissionNeeded: "Permission Needed"
        case .unknown: "Unknown"
        }
    }
}

public struct EngineAvailability: Codable, Hashable, Sendable {
    public var state: EngineState
    public var detail: String

    public init(state: EngineState, detail: String) {
        self.state = state
        self.detail = detail
    }

    public static let unknown = EngineAvailability(state: .unknown, detail: "Not checked yet.")
}

public struct PermissionSnapshot: Codable, Hashable, Sendable {
    public var microphone: PermissionState
    public var speech: PermissionState
    public var accessibility: PermissionState

    public init(
        microphone: PermissionState = .unknown,
        speech: PermissionState = .unknown,
        accessibility: PermissionState = .unknown
    ) {
        self.microphone = microphone
        self.speech = speech
        self.accessibility = accessibility
    }
}

