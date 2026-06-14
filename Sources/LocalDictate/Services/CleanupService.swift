import Foundation
import FoundationModels
import LocalDictateCore

@MainActor
protocol CleanupService: AnyObject {
    func availability() -> EngineAvailability
    func clean(text: String, template: CleanupTemplate) async throws -> String
}

enum CleanupError: LocalizedError {
    case modelUnavailable(String)
    case emptyInput

    var errorDescription: String? {
        switch self {
        case .modelUnavailable(let message): message
        case .emptyInput: "There is no transcript to clean."
        }
    }
}

@MainActor
final class FoundationModelCleanupService: CleanupService {
    func availability() -> EngineAvailability {
        guard #available(macOS 26.0, *) else {
            return EngineAvailability(state: .unsupported, detail: "Foundation Models require macOS 26 or newer.")
        }
        let model = SystemLanguageModel.default
        switch model.availability {
        case .available:
            return EngineAvailability(state: .available, detail: "Foundation Models are available on device.")
        case .unavailable(let reason):
            switch reason {
            case .appleIntelligenceNotEnabled:
                return EngineAvailability(state: .unavailable, detail: "Apple Intelligence is not enabled in System Settings.")
            case .deviceNotEligible:
                return EngineAvailability(state: .unsupported, detail: "This Mac is not eligible for Apple on-device language models.")
            case .modelNotReady:
                return EngineAvailability(state: .downloading, detail: "The on-device language model is not ready yet.")
            @unknown default:
                return EngineAvailability(state: .unknown, detail: "Foundation Models are unavailable for an unknown reason.")
            }
        @unknown default:
            return EngineAvailability(state: .unknown, detail: "Foundation Models availability could not be determined.")
        }
    }

    func clean(text: String, template: CleanupTemplate) async throws -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw CleanupError.emptyInput
        }
        guard #available(macOS 26.0, *) else {
            return trimmed
        }

        let model = SystemLanguageModel.default
        guard model.isAvailable else {
            return trimmed
        }

        let instructions = """
        You are LocalDictate's local cleanup engine. Follow the user's selected template exactly. Do not add explanations, headings, Markdown fences, or commentary.

        Template:
        \(template.prompt)
        """
        let session = LanguageModelSession(model: model, instructions: instructions)
        let prompt = """
        Transcript:
        \(trimmed)
        """
        let response = try await session.respond(
            to: prompt,
            options: GenerationOptions(temperature: 0.2, maximumResponseTokens: 1_200)
        )
        let cleaned = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? trimmed : cleaned
    }
}
