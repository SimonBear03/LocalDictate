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

        if #available(macOS 26.0, *) {
            if let analyzerAvailability = await analyzerAvailability(locale: locale) {
                return analyzerAvailability
            }
        }

        return legacyAvailability(locale: locale)
    }

    @available(macOS 26.0, *)
    private func analyzerAvailability(locale: Locale) async -> EngineAvailability? {
        guard let supportedLocale = await DictationTranscriber.supportedLocale(equivalentTo: locale) else {
            return nil
        }

        let transcriber = DictationTranscriber(
            locale: supportedLocale,
            contentHints: [],
            transcriptionOptions: [.punctuation],
            reportingOptions: [.volatileResults, .frequentFinalization],
            attributeOptions: [.audioTimeRange, .transcriptionConfidence]
        )
        let status = await AssetInventory.status(forModules: [transcriber])

        switch status {
        case .installed:
            return EngineAvailability(
                state: .available,
                detail: "Using local Apple DictationTranscriber with SpeechAnalyzer for \(supportedLocale.identifier)."
            )
        case .supported:
            return EngineAvailability(
                state: .available,
                detail: "Apple DictationTranscriber supports \(supportedLocale.identifier); local assets may install on first use."
            )
        case .downloading:
            return EngineAvailability(
                state: .downloading,
                detail: "Apple local dictation assets for \(supportedLocale.identifier) are downloading."
            )
        case .unsupported:
            return nil
        @unknown default:
            return nil
        }
    }

    private func legacyAvailability(locale: Locale) -> EngineAvailability {
        guard let recognizer = SFSpeechRecognizer(locale: locale) else {
            return EngineAvailability(state: .unsupported, detail: "No Apple speech recognizer is available for \(locale.identifier).")
        }
        guard recognizer.isAvailable else {
            return EngineAvailability(state: .unavailable, detail: "Apple speech recognition is currently unavailable.")
        }
        guard recognizer.supportsOnDeviceRecognition else {
            return EngineAvailability(state: .unsupported, detail: "Local-only Apple speech recognition is not available for \(locale.identifier).")
        }
        return EngineAvailability(state: .available, detail: "Using legacy local Apple speech recognition for \(locale.identifier).")
    }
}
