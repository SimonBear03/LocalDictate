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

    public static let builtIns: [CleanupTemplate] = [
        CleanupTemplate(
            id: cleanDictationID,
            name: "Default",
            summary: "Light cleanup without rewriting wording.",
            prompt: """
            Clean up this dictated text conservatively.

            Only make basic readability fixes:
            - remove filler words such as "um", "uh", "like", and repeated accidental starts when removing them does not change meaning
            - add or fix punctuation, capitalization, spacing, and paragraph breaks
            - fix obvious speech-recognition typos only when the intended word is clear

            Do not rewrite, summarize, restructure, formalize, translate, add new ideas, or change the speaker's wording, tone, intent, or level of detail. Preserve the original language and wording as much as possible. Return only the cleaned text.
            """,
            isBuiltIn: true
        )
    ]
}
