import Testing
@testable import LocalDictateCore

@Test func builtInTemplatesHaveStableIDs() {
    #expect(CleanupTemplate.builtIns.count == 1)
    #expect(CleanupTemplate.builtIns.first?.id == CleanupTemplate.cleanDictationID)
    #expect(CleanupTemplate.builtIns.first?.name == "Default")
    #expect(CleanupTemplate.builtIns.first?.prompt.contains("Do not rewrite") == true)
}

@Test func dictationStatusTitlesAreReadable() {
    #expect(DictationStatus.idle.title == "Idle")
    #expect(DictationStatus.listening.menuTitle.contains("Listening"))
}

@Test func transcriptAccumulatorAppendsNewTimedSpeechWindows() {
    var accumulator = TranscriptAccumulator()

    accumulator.update(
        text: "I think we should start with the app",
        window: TranscriptSegmentWindow(start: 0.1, end: 2.0)
    )
    let text = accumulator.update(
        text: "and then clean up the text",
        window: TranscriptSegmentWindow(start: 3.4, end: 5.1)
    )

    #expect(text == "I think we should start with the app and then clean up the text")
}

@Test func transcriptAccumulatorRevisesSameTimedSpeechWindow() {
    var accumulator = TranscriptAccumulator()

    accumulator.update(
        text: "I want to testing",
        window: TranscriptSegmentWindow(start: 0.0, end: 1.2)
    )
    let text = accumulator.update(
        text: "I want to test this",
        window: TranscriptSegmentWindow(start: 0.1, end: 1.8)
    )

    #expect(text == "I want to test this")
}

@Test func transcriptAccumulatorAcceptsRebasedFullTranscript() {
    var accumulator = TranscriptAccumulator()

    accumulator.update(
        text: "First sentence",
        window: TranscriptSegmentWindow(start: 0.2, end: 1.0)
    )
    accumulator.update(
        text: "second sentence",
        window: TranscriptSegmentWindow(start: 2.0, end: 3.0)
    )
    let text = accumulator.update(
        text: "First sentence, second sentence",
        window: TranscriptSegmentWindow(start: 0.0, end: 3.0)
    )

    #expect(text == "First sentence, second sentence")
}

@Test func transcriptAccumulatorAppendsWhenRecognizerTimestampResetsForNewPhrase() {
    var accumulator = TranscriptAccumulator()

    accumulator.update(
        text: "First sentence",
        window: TranscriptSegmentWindow(start: 0.2, end: 1.0)
    )
    accumulator.update(
        text: "second sentence",
        window: TranscriptSegmentWindow(start: 2.0, end: 3.0)
    )
    let update = accumulator.updateDetailed(
        text: "after a pause",
        window: TranscriptSegmentWindow(start: 0.0, end: 0.9)
    )

    #expect(update.decision == .appendedAfterTimestampReset)
    #expect(update.outputText == "First sentence second sentence after a pause")
}

@Test func transcriptAccumulatorAvoidsDuplicateWhenTimestampResetLaterBecomesFullTranscript() {
    var accumulator = TranscriptAccumulator()

    accumulator.update(
        text: "First sentence",
        window: TranscriptSegmentWindow(start: 0.2, end: 1.0)
    )
    accumulator.update(
        text: "second sentence",
        window: TranscriptSegmentWindow(start: 2.0, end: 3.0)
    )
    accumulator.update(
        text: "after a pause",
        window: TranscriptSegmentWindow(start: 0.0, end: 0.9)
    )
    let update = accumulator.updateDetailed(
        text: "First sentence second sentence after a pause",
        window: TranscriptSegmentWindow(start: 0.0, end: 4.0)
    )

    #expect(update.decision == .acceptedFullRebase)
    #expect(update.outputText == "First sentence second sentence after a pause")
}

@Test func transcriptAccumulatorDoesNotAcceptShortPrefixAsFullRebase() {
    var accumulator = TranscriptAccumulator()

    accumulator.update(
        text: "First sentence",
        window: TranscriptSegmentWindow(start: 0.2, end: 1.0)
    )
    accumulator.update(
        text: "second sentence",
        window: TranscriptSegmentWindow(start: 2.0, end: 3.0)
    )
    accumulator.update(
        text: "after a pause",
        window: TranscriptSegmentWindow(start: 0.0, end: 0.9)
    )
    let update = accumulator.updateDetailed(
        text: "First sentence",
        window: TranscriptSegmentWindow(start: 0.0, end: 1.0)
    )

    #expect(update.decision == .ignoredShortRegression)
    #expect(update.outputText == "First sentence second sentence after a pause")
}
