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
        You are LocalDictate's local cleanup engine. Follow the user's selected template exactly.

        Output contract:
        - Return exactly one thing: the cleaned dictation text.
        - Do not add explanations, labels, headings, Markdown fences, quotes, or commentary.
        - Do not prefix the response with "Transcript:", "Cleaned Text:", "Output:", "Result:", or similar labels.
        - The user's dictation will be wrapped in <dictation> tags. Never include those tags in your response.

        Template:
        \(template.prompt)
        """
        let session = LanguageModelSession(model: model, instructions: instructions)
        let prompt = """
        <dictation>
        \(trimmed)
        </dictation>
        """
        let response = try await session.respond(
            to: prompt,
            options: GenerationOptions(temperature: 0.2, maximumResponseTokens: 1_200)
        )
        let cleaned = Self.stripLeadingOutputLabels(from: response.content)
        return cleaned.isEmpty ? trimmed : cleaned
    }

    private static func stripLeadingOutputLabels(from text: String) -> String {
        var output = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let labels = [
            "Here is the cleaned text",
            "Here is the cleaned transcript",
            "Cleaned Transcript",
            "Cleaned Text",
            "Transcript",
            "Output",
            "Result"
        ]

        for label in labels {
            if output.range(of: label, options: [.anchored, .caseInsensitive]) != nil {
                output = trimLeadingLabelSeparator(String(output.dropFirst(label.count)))
                break
            }
        }

        return output
    }

    private static func trimLeadingLabelSeparator(_ text: String) -> String {
        let separators = CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: ":：-–—"))
        return text.trimmingCharacters(in: separators)
    }
}
