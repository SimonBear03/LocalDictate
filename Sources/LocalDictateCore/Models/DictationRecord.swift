import Foundation

public struct DictationRecord: Codable, Identifiable, Hashable, Sendable {
    public var id: UUID
    public var createdAt: Date
    public var targetAppName: String
    public var rawTranscript: String
    public var cleanedText: String
    public var templateID: UUID
    public var templateName: String
    public var languageIdentifier: String
    public var audioFileName: String?

    public init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        targetAppName: String,
        rawTranscript: String,
        cleanedText: String,
        templateID: UUID,
        templateName: String,
        languageIdentifier: String,
        audioFileName: String? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.targetAppName = targetAppName
        self.rawTranscript = rawTranscript
        self.cleanedText = cleanedText
        self.templateID = templateID
        self.templateName = templateName
        self.languageIdentifier = languageIdentifier
        self.audioFileName = audioFileName
    }
}

