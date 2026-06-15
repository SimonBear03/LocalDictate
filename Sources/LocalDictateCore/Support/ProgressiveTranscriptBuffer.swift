import Foundation

public struct ProgressiveTranscriptBuffer: Sendable {
    private var finalizedText = ""
    private var volatileText = ""
    private var finalizedWindow: TranscriptSegmentWindow?
    private var volatileWindow: TranscriptSegmentWindow?

    public init() {}

    public var text: String {
        Self.compose(finalizedText: finalizedText, volatileText: volatileText)
    }

    @discardableResult
    public mutating func updateDetailed(
        text incomingText: String,
        window incomingWindow: TranscriptSegmentWindow?,
        isFinal: Bool
    ) -> TranscriptAccumulatorUpdate {
        let incomingText = incomingText.trimmingCharacters(in: .whitespacesAndNewlines)
        let previousText = text
        let previousWindow = outputWindow

        guard !incomingText.isEmpty else {
            return makeUpdate(
                decision: .emptyIgnored,
                previousText: previousText,
                incomingText: incomingText,
                incomingWindow: incomingWindow,
                previousWindow: previousWindow
            )
        }

        if isFinal {
            appendFinalText(incomingText, window: incomingWindow)
            volatileText = ""
            volatileWindow = nil
            return makeUpdate(
                decision: .finalResult,
                previousText: previousText,
                incomingText: incomingText,
                incomingWindow: incomingWindow,
                previousWindow: previousWindow
            )
        }

        volatileText = incomingText
        volatileWindow = incomingWindow

        return makeUpdate(
            decision: incomingText == previousText ? .unchanged : .partialPreview,
            previousText: previousText,
            incomingText: incomingText,
            incomingWindow: incomingWindow,
            previousWindow: previousWindow
        )
    }

    public mutating func reset() {
        finalizedText = ""
        volatileText = ""
        finalizedWindow = nil
        volatileWindow = nil
    }

    private var outputWindow: TranscriptSegmentWindow? {
        switch (finalizedWindow, volatileWindow) {
        case (.none, .none):
            nil
        case (.some(let window), .none), (.none, .some(let window)):
            window
        case (.some(let lhs), .some(let rhs)):
            TranscriptSegmentWindow(
                start: min(lhs.start, rhs.start),
                end: max(lhs.end, rhs.end)
            )
        }
    }

    private mutating func appendFinalText(_ text: String, window: TranscriptSegmentWindow?) {
        if finalizedText.isEmpty {
            finalizedText = text
            finalizedWindow = window
            return
        }

        if finalizedText == text || finalizedText.hasSuffix(text) {
            finalizedWindow = Self.merge(finalizedWindow, window)
            return
        }

        if text.hasPrefix(finalizedText) {
            finalizedText = text
            finalizedWindow = Self.merge(finalizedWindow, window)
            return
        }

        finalizedText = Self.join(finalizedText, text)
        finalizedWindow = Self.merge(finalizedWindow, window)
    }

    private func makeUpdate(
        decision: TranscriptAccumulatorDecision,
        previousText: String,
        incomingText: String,
        incomingWindow: TranscriptSegmentWindow?,
        previousWindow: TranscriptSegmentWindow?
    ) -> TranscriptAccumulatorUpdate {
        TranscriptAccumulatorUpdate(
            decision: decision,
            previousText: previousText,
            incomingText: incomingText,
            outputText: text,
            previousWindow: previousWindow,
            incomingWindow: incomingWindow,
            outputWindow: outputWindow
        )
    }

    private static func compose(finalizedText: String, volatileText: String) -> String {
        let finalizedText = finalizedText.trimmingCharacters(in: .whitespacesAndNewlines)
        let volatileText = volatileText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !finalizedText.isEmpty else { return volatileText }
        guard !volatileText.isEmpty else { return finalizedText }

        if volatileText == finalizedText || volatileText.hasPrefix(finalizedText) {
            return volatileText
        }

        if finalizedText.hasSuffix(volatileText) {
            return finalizedText
        }

        return join(finalizedText, volatileText)
    }

    private static func join(_ lhs: String, _ rhs: String) -> String {
        let lhs = lhs.trimmingCharacters(in: .whitespacesAndNewlines)
        let rhs = rhs.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !lhs.isEmpty else { return rhs }
        guard !rhs.isEmpty else { return lhs }

        guard let left = lhs.last, let right = rhs.first else {
            return "\(lhs) \(rhs)"
        }

        if right.isClosingPunctuation || left.isOpeningPunctuation || left.isCJK || right.isCJK {
            return lhs + rhs
        }

        return "\(lhs) \(rhs)"
    }

    private static func merge(
        _ lhs: TranscriptSegmentWindow?,
        _ rhs: TranscriptSegmentWindow?
    ) -> TranscriptSegmentWindow? {
        switch (lhs, rhs) {
        case (.none, .none):
            nil
        case (.some(let window), .none), (.none, .some(let window)):
            window
        case (.some(let lhs), .some(let rhs)):
            TranscriptSegmentWindow(
                start: min(lhs.start, rhs.start),
                end: max(lhs.end, rhs.end)
            )
        }
    }
}

private extension Character {
    var isClosingPunctuation: Bool {
        [".", ",", "!", "?", ":", ";", ")", "]", "}", "，", "。", "！", "？", "：", "；", "）", "】", "」", "』"].contains(self)
    }

    var isOpeningPunctuation: Bool {
        ["(", "[", "{", "（", "【", "「", "『"].contains(self)
    }

    var isCJK: Bool {
        unicodeScalars.contains { scalar in
            (0x4E00...0x9FFF).contains(scalar.value) ||
                (0x3400...0x4DBF).contains(scalar.value) ||
                (0x3040...0x30FF).contains(scalar.value) ||
                (0xAC00...0xD7AF).contains(scalar.value)
        }
    }
}
