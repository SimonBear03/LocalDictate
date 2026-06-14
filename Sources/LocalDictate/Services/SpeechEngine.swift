import AVFoundation
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
    func transcribe(audioFileURL: URL, locale: Locale) async throws -> SpeechTranscript
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
            "No speech was detected in the recording."
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
            let equivalent = await DictationTranscriber.supportedLocale(equivalentTo: locale)
            if let equivalent {
                let transcriber = DictationTranscriber(locale: equivalent, preset: .progressiveLongDictation)
                let status = await AssetInventory.status(forModules: [transcriber])
                switch status {
                case .installed:
                    return EngineAvailability(state: .available, detail: "Modern local dictation assets are installed for \(equivalent.identifier).")
                case .downloading:
                    return EngineAvailability(state: .downloading, detail: "Modern dictation assets are downloading for \(equivalent.identifier).")
                case .supported:
                    return EngineAvailability(state: .available, detail: "Modern dictation is supported for \(equivalent.identifier); assets may install on demand.")
                case .unsupported:
                    break
                @unknown default:
                    break
                }
            }
        }

        guard let recognizer = SFSpeechRecognizer(locale: locale) else {
            return EngineAvailability(state: .unsupported, detail: "No Apple speech recognizer is available for \(locale.identifier).")
        }
        guard recognizer.isAvailable else {
            return EngineAvailability(state: .unavailable, detail: "Apple speech recognition is currently unavailable.")
        }
        return EngineAvailability(state: .available, detail: "Using local-only Apple speech recognition for \(locale.identifier).")
    }

    func transcribe(audioFileURL: URL, locale: Locale) async throws -> SpeechTranscript {
        guard PermissionService.speechState() == .granted else {
            throw SpeechEngineError.permissionNeeded
        }
        guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.isAvailable else {
            throw SpeechEngineError.recognizerUnavailable
        }

        let request = SFSpeechURLRecognitionRequest(url: audioFileURL)
        request.requiresOnDeviceRecognition = true
        request.shouldReportPartialResults = false
        if #available(macOS 13.0, *) {
            request.addsPunctuation = true
        }

        let text = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            var didResume = false
            let task = recognizer.recognitionTask(with: request) { result, error in
                if let error, !didResume {
                    didResume = true
                    continuation.resume(throwing: SpeechEngineError.recognitionFailed(error.localizedDescription))
                    return
                }
                guard let result, result.isFinal, !didResume else {
                    return
                }
                didResume = true
                continuation.resume(returning: result.bestTranscription.formattedString)
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 90) {
                guard !didResume else { return }
                didResume = true
                task.cancel()
                continuation.resume(throwing: SpeechEngineError.recognitionFailed("Timed out waiting for local speech recognition."))
            }
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw SpeechEngineError.emptyTranscript
        }
        return SpeechTranscript(text: trimmed, languageIdentifier: locale.identifier)
    }
}
