import Foundation

public enum DictationStatus: String, Codable, CaseIterable, Identifiable, Sendable {
    case idle
    case checkingPermissions
    case permissionNeeded
    case listening
    case transcribing
    case cleaning
    case inserting
    case ready
    case inserted
    case error

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .idle: "Idle"
        case .checkingPermissions: "Checking Permissions"
        case .permissionNeeded: "Permission Needed"
        case .listening: "Listening"
        case .transcribing: "Transcribing"
        case .cleaning: "Cleaning"
        case .inserting: "Inserting"
        case .ready: "Ready"
        case .inserted: "Inserted"
        case .error: "Error"
        }
    }

    public var menuTitle: String {
        switch self {
        case .idle: "LocalDictate Idle"
        case .checkingPermissions: "LocalDictate Checking Permissions"
        case .permissionNeeded: "LocalDictate Permission Needed"
        case .listening: "LocalDictate Listening"
        case .transcribing: "LocalDictate Transcribing"
        case .cleaning: "LocalDictate Cleaning"
        case .inserting: "LocalDictate Inserting"
        case .ready: "LocalDictate Ready"
        case .inserted: "LocalDictate Inserted"
        case .error: "LocalDictate Error"
        }
    }
}

public enum PermissionState: String, Codable, Sendable {
    case granted
    case denied
    case notDetermined
    case restricted
    case unknown

    public var title: String {
        switch self {
        case .granted: "Granted"
        case .denied: "Denied"
        case .notDetermined: "Not Asked"
        case .restricted: "Restricted"
        case .unknown: "Unknown"
        }
    }
}

public enum RecordingMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case hold
    case toggle
    case menu

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .hold: "Hold to Record"
        case .toggle: "Toggle"
        case .menu: "Menu Button"
        }
    }
}

public enum InsertionMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case autoPaste
    case copyOnly

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .autoPaste: "Auto Paste"
        case .copyOnly: "Copy Only"
        }
    }
}

public enum AudioRetention: String, Codable, CaseIterable, Identifiable, Sendable {
    case off
    case manualDelete

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .off: "Do Not Save Audio"
        case .manualDelete: "Keep Until Deleted"
        }
    }
}
