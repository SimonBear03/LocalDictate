import LocalDictateCore
import SwiftUI

extension DictationStatus {
    var systemImage: String {
        switch self {
        case .idle: "text.cursor"
        case .listening: "waveform"
        case .transcribing: "captions.bubble"
        case .cleaning: "sparkles"
        case .ready: "checkmark.circle"
        case .inserted: "arrow.down.doc"
        case .error: "exclamationmark.triangle"
        }
    }

    var tint: Color {
        switch self {
        case .idle: .secondary
        case .listening: .red
        case .transcribing: .blue
        case .cleaning: .teal
        case .ready: .green
        case .inserted: .green
        case .error: .red
        }
    }
}

extension PermissionState {
    var tint: Color {
        switch self {
        case .granted: .green
        case .denied, .restricted: .red
        case .notDetermined: .orange
        case .unknown: .secondary
        }
    }
}

extension EngineState {
    var tint: Color {
        switch self {
        case .available: .green
        case .downloading: .secondary
        case .permissionNeeded: .orange
        case .unavailable, .unsupported: .red
        case .unknown: .secondary
        }
    }
}
