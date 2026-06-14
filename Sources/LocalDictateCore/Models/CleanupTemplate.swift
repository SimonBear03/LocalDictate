import Foundation

public struct CleanupTemplate: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var summary: String
    public var prompt: String
    public var isBuiltIn: Bool

    public init(
        id: UUID = UUID(),
        name: String,
        summary: String,
        prompt: String,
        isBuiltIn: Bool = false
    ) {
        self.id = id
        self.name = name
        self.summary = summary
        self.prompt = prompt
        self.isBuiltIn = isBuiltIn
    }

    public static let cleanDictationID = UUID(uuidString: "C1EAD600-0000-4000-9000-000000000001")!
    public static let formalEmailID = UUID(uuidString: "C1EAD600-0000-4000-9000-000000000002")!
    public static let codexPromptID = UUID(uuidString: "C1EAD600-0000-4000-9000-000000000003")!
    public static let mixedNotesID = UUID(uuidString: "C1EAD600-0000-4000-9000-000000000004")!
    public static let verbatimID = UUID(uuidString: "C1EAD600-0000-4000-9000-000000000005")!

    public static let builtIns: [CleanupTemplate] = [
        CleanupTemplate(
            id: cleanDictationID,
            name: "Clean Dictation",
            summary: "Light cleanup while preserving meaning and tone.",
            prompt: """
            Clean up the dictated text. Preserve the speaker's meaning, voice, language, and paragraph structure. Remove filler words and false starts only when they do not change intent. Add punctuation and capitalization. Return only the cleaned text.
            """,
            isBuiltIn: true
        ),
        CleanupTemplate(
            id: formalEmailID,
            name: "Formal Email",
            summary: "Turn rough speech into a concise email draft.",
            prompt: """
            Rewrite the dictated text as a clear, professional email. Preserve all factual details and requests. Do not invent names, dates, or commitments. Return only the email body unless the transcript clearly contains a subject line.
            """,
            isBuiltIn: true
        ),
        CleanupTemplate(
            id: codexPromptID,
            name: "Codex Prompt",
            summary: "Make the text precise enough to give to Codex.",
            prompt: """
            Clean this dictated request into a precise software-engineering prompt for Codex. Preserve constraints, file names, observed errors, and acceptance criteria. Keep the result direct and actionable. Return only the cleaned prompt.
            """,
            isBuiltIn: true
        ),
        CleanupTemplate(
            id: mixedNotesID,
            name: "Chinese/English Notes",
            summary: "Preserve mixed Chinese and English notes.",
            prompt: """
            Clean up this dictated note while preserving the original mix of Chinese and English. Add punctuation, spacing, and line breaks where helpful. Do not translate unless the transcript explicitly asks for translation. Return only the cleaned text.
            """,
            isBuiltIn: true
        ),
        CleanupTemplate(
            id: verbatimID,
            name: "Verbatim",
            summary: "Keep wording as close to the transcript as possible.",
            prompt: """
            Preserve the transcript as closely as possible. Only add punctuation, capitalization, and obvious missing spacing. Do not rewrite style or remove repeated words unless they are clearly recognition artifacts. Return only the cleaned text.
            """,
            isBuiltIn: true
        )
    ]
}

