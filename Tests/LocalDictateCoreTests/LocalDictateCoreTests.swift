import Testing
@testable import LocalDictateCore

@Test func builtInTemplatesHaveStableIDs() {
    #expect(CleanupTemplate.builtIns.count >= 5)
    #expect(CleanupTemplate.builtIns.contains { $0.id == CleanupTemplate.cleanDictationID })
    #expect(CleanupTemplate.builtIns.allSatisfy { !$0.prompt.isEmpty })
}

@Test func dictationStatusTitlesAreReadable() {
    #expect(DictationStatus.idle.title == "Idle")
    #expect(DictationStatus.listening.menuTitle.contains("Listening"))
}

