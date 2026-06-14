import Foundation
import LocalDictateCore
import Speech

struct SpeechTranscript: Sendable {
    var text: String
    var languageIdentifier: String
}

@MainActor
protocol SpeechEngine: AnyObject {
    func availability(locale: Locale) async -> EngineAvailability
}

enum SpeechEngineError: LocalizedError {
    case permissionNeeded
    case recognizerUnavailable
    case noLocalRecognizer
    case emptyTranscript
    case recognitionFailed(String)

    var errorDescription: String? {
        switch self {
        case .permissionNeeded:
            "Speech Recognition permission is required."
        case .recognizerUnavailable:
            "Speech recognition is unavailable for the selected language."
        case .noLocalRecognizer:
            "The selected language does not currently support local-only recognition on this Mac."
        case .emptyTranscript:
            "No speech was detected in the live audio."
        case .recognitionFailed(let message):
            message
        }
    }
}

@MainActor
final class AppleSpeechEngine: SpeechEngine {
    func availability(locale: Locale) async -> EngineAvailability {
        if PermissionService.speechState() != .granted {
            return EngineAvailability(state: .permissionNeeded, detail: "Speech Recognition permission has not been granted.")
        }

        guard let recognizer = SFSpeechRecognizer(locale: locale) else {
            return EngineAvailability(state: .unsupported, detail: "No Apple speech recognizer is available for \(locale.identifier).")
        }
        guard recognizer.isAvailable else {
            return EngineAvailability(state: .unavailable, detail: "Apple speech recognition is currently unavailable.")
        }
        guard recognizer.supportsOnDeviceRecognition else {
            return EngineAvailability(state: .unsupported, detail: "Local-only Apple speech recognition is not available for \(locale.identifier).")
        }
        return EngineAvailability(state: .available, detail: "Using live local Apple speech recognition for \(locale.identifier).")
    }
}
