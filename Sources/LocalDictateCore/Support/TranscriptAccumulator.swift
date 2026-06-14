import Foundation

public struct TranscriptSegmentWindow: Equatable, Sendable {
    public var start: TimeInterval
    public var end: TimeInterval

    public init(start: TimeInterval, end: TimeInterval) {
        self.start = start
        self.end = max(start, end)
    }
}

public enum TranscriptAccumulatorDecision: String, Sendable {
    case emptyIgnored
    case started
    case unchanged
    case revisedCurrentWindow
    case appendedNewWindow
    case appendedAfterTimestampReset
    case acceptedFullRebase
    case mergedOverlap
    case ignoredShortRegression
    case revisedWithoutTiming
    case appendedWithoutTiming
}

public struct TranscriptAccumulatorUpdate: Equatable, Sendable {
    public var decision: TranscriptAccumulatorDecision
    public var previousText: String
    public var incomingText: String
    public var outputText: String
    public var previousWindow: TranscriptSegmentWindow?
    public var incomingWindow: TranscriptSegmentWindow?
    public var outputWindow: TranscriptSegmentWindow?

    public init(
        decision: TranscriptAccumulatorDecision,
        previousText: String,
        incomingText: String,
        outputText: String,
        previousWindow: TranscriptSegmentWindow?,
        incomingWindow: TranscriptSegmentWindow?,
        outputWindow: TranscriptSegmentWindow?
    ) {
        self.decision = decision
        self.previousText = previousText
        self.incomingText = incomingText
        self.outputText = outputText
        self.previousWindow = previousWindow
        self.incomingWindow = incomingWindow
        self.outputWindow = outputWindow
    }
}

public struct SpeechRecognitionDebugEvent: Identifiable, Sendable {
    public var id: UUID
    public var date: Date
    public var decision: TranscriptAccumulatorDecision
    public var previousCharacters: Int
    public var incomingCharacters: Int
    public var outputCharacters: Int
    public var previousPreview: String
    public var incomingPreview: String
    public var outputPreview: String
    public var previousWindow: TranscriptSegmentWindow?
    public var incomingWindow: TranscriptSegmentWindow?
    public var outputWindow: TranscriptSegmentWindow?

    public init(update: TranscriptAccumulatorUpdate, date: Date = Date()) {
        self.id = UUID()
        self.date = date
        self.decision = update.decision
        self.previousCharacters = update.previousText.count
        self.incomingCharacters = update.incomingText.count
        self.outputCharacters = update.outputText.count
        self.previousPreview = Self.preview(update.previousText)
        self.incomingPreview = Self.preview(update.incomingText)
        self.outputPreview = Self.preview(update.outputText)
        self.previousWindow = update.previousWindow
        self.incomingWindow = update.incomingWindow
        self.outputWindow = update.outputWindow
    }

    private static func preview(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > 96 else {
            return trimmed
        }
        let endIndex = trimmed.index(trimmed.startIndex, offsetBy: 96)
        return String(trimmed[..<endIndex]) + "..."
    }
}

public struct TranscriptAccumulator: Sendable {
    private var committedText = ""
    private var currentText = ""
    private var currentWindow: TranscriptSegmentWindow?

    public init() {}

    public var text: String {
        Self.join(committedText, currentText)
    }

    @discardableResult
    public mutating func update(text incomingText: String, window incomingWindow: TranscriptSegmentWindow?) -> String {
        updateDetailed(text: incomingText, window: incomingWindow).outputText
    }

    @discardableResult
    public mutating func updateDetailed(text incomingText: String, window incomingWindow: TranscriptSegmentWindow?) -> TranscriptAccumulatorUpdate {
        let incomingText = incomingText.trimmingCharacters(in: .whitespacesAndNewlines)
        let previousText = text
        let previousWindow = currentWindow

        guard !incomingText.isEmpty else {
            return makeUpdate(
                decision: .emptyIgnored,
                previousText: previousText,
                incomingText: incomingText,
                incomingWindow: incomingWindow,
                previousWindow: previousWindow
            )
        }

        guard let incomingWindow else {
            return updateWithoutTiming(
                text: incomingText,
                previousText: previousText,
                previousWindow: previousWindow
            )
        }

        guard let currentWindow else {
            currentText = incomingText
            self.currentWindow = incomingWindow
            return makeUpdate(
                decision: .started,
                previousText: previousText,
                incomingText: incomingText,
                incomingWindow: incomingWindow,
                previousWindow: previousWindow
            )
        }

        if incomingWindow.start < currentWindow.start - Self.rebasedStartTolerance {
            if shouldAcceptFullRebase(incomingText: incomingText, existingText: previousText) {
                committedText = ""
                currentText = incomingText
                self.currentWindow = incomingWindow
                return makeUpdate(
                    decision: .acceptedFullRebase,
                    previousText: previousText,
                    incomingText: incomingText,
                    incomingWindow: incomingWindow,
                    previousWindow: previousWindow
                )
            }

            committedText = previousText
            currentText = incomingText
            self.currentWindow = incomingWindow
            return makeUpdate(
                decision: .appendedAfterTimestampReset,
                previousText: previousText,
                incomingText: incomingText,
                incomingWindow: incomingWindow,
                previousWindow: previousWindow
            )
        }

        if abs(incomingWindow.start - currentWindow.start) <= Self.sameWindowStartTolerance {
            if !committedText.isEmpty, shouldAcceptFullRebase(incomingText: incomingText, existingText: committedText) {
                committedText = ""
                currentText = incomingText
                self.currentWindow = incomingWindow
                return makeUpdate(
                    decision: .acceptedFullRebase,
                    previousText: previousText,
                    incomingText: incomingText,
                    incomingWindow: incomingWindow,
                    previousWindow: previousWindow
                )
            }

            if previousText.hasPrefix(incomingText), incomingText.count + Self.shortRegressionSlack < previousText.count {
                return makeUpdate(
                    decision: .ignoredShortRegression,
                    previousText: previousText,
                    incomingText: incomingText,
                    incomingWindow: incomingWindow,
                    previousWindow: previousWindow
                )
            }

            currentText = incomingText
            self.currentWindow = incomingWindow
            return makeUpdate(
                decision: incomingText == previousText ? .unchanged : .revisedCurrentWindow,
                previousText: previousText,
                incomingText: incomingText,
                incomingWindow: incomingWindow,
                previousWindow: previousWindow
            )
        }

        if incomingWindow.start >= currentWindow.end - Self.nextWindowOverlapTolerance {
            committedText = Self.join(committedText, currentText)
            currentText = incomingText
            self.currentWindow = incomingWindow
            return makeUpdate(
                decision: .appendedNewWindow,
                previousText: previousText,
                incomingText: incomingText,
                incomingWindow: incomingWindow,
                previousWindow: previousWindow
            )
        }

        currentText = Self.mergeOverlappingText(currentText, incomingText)
        self.currentWindow = TranscriptSegmentWindow(
            start: min(currentWindow.start, incomingWindow.start),
            end: max(currentWindow.end, incomingWindow.end)
        )
        return makeUpdate(
            decision: .mergedOverlap,
            previousText: previousText,
            incomingText: incomingText,
            incomingWindow: incomingWindow,
            previousWindow: previousWindow
        )
    }

    public mutating func reset() {
        committedText = ""
        currentText = ""
        currentWindow = nil
    }

    private mutating func updateWithoutTiming(
        text incomingText: String,
        previousText displayedText: String,
        previousWindow: TranscriptSegmentWindow?
    ) -> TranscriptAccumulatorUpdate {
        guard !displayedText.isEmpty else {
            currentText = incomingText
            return makeUpdate(
                decision: .started,
                previousText: displayedText,
                incomingText: incomingText,
                incomingWindow: nil,
                previousWindow: previousWindow
            )
        }

        if incomingText == displayedText {
            return makeUpdate(
                decision: .unchanged,
                previousText: displayedText,
                incomingText: incomingText,
                incomingWindow: nil,
                previousWindow: previousWindow
            )
        }

        if incomingText.hasPrefix(displayedText) || Self.sharedPrefixLength(incomingText, displayedText) >= Self.revisionPrefixThreshold {
            committedText = ""
            currentText = incomingText
            currentWindow = nil
            return makeUpdate(
                decision: .revisedWithoutTiming,
                previousText: displayedText,
                incomingText: incomingText,
                incomingWindow: nil,
                previousWindow: previousWindow
            )
        }

        if displayedText.hasPrefix(incomingText) {
            return makeUpdate(
                decision: .ignoredShortRegression,
                previousText: displayedText,
                incomingText: incomingText,
                incomingWindow: nil,
                previousWindow: previousWindow
            )
        }

        let merged = Self.mergeOverlappingText(displayedText, incomingText)
        committedText = ""
        currentText = merged
        currentWindow = nil
        return makeUpdate(
            decision: .appendedWithoutTiming,
            previousText: displayedText,
            incomingText: incomingText,
            incomingWindow: nil,
            previousWindow: previousWindow
        )
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
            outputWindow: currentWindow
        )
    }

    private static func sharedPrefixLength(_ left: String, _ right: String) -> Int {
        var count = 0
        var leftIndex = left.startIndex
        var rightIndex = right.startIndex

        while leftIndex < left.endIndex, rightIndex < right.endIndex {
            guard left[leftIndex].lowercased() == right[rightIndex].lowercased() else {
                break
            }
            count += 1
            left.formIndex(after: &leftIndex)
            right.formIndex(after: &rightIndex)
        }

        return count
    }

    private func shouldAcceptFullRebase(incomingText: String, existingText: String) -> Bool {
        let incomingText = Self.normalizedForRebase(incomingText)
        let existingText = Self.normalizedForRebase(existingText)
        guard !incomingText.isEmpty, !existingText.isEmpty else {
            return true
        }

        if incomingText == existingText || incomingText.hasPrefix(existingText) {
            return true
        }

        if existingText.hasPrefix(incomingText) {
            return false
        }

        let sharedPrefix = Self.sharedPrefixLength(incomingText, existingText)
        guard sharedPrefix >= Self.revisionPrefixThreshold else {
            return false
        }

        let existingCoverage = Double(sharedPrefix) / Double(max(existingText.count, 1))
        let lengthRatio = Double(incomingText.count) / Double(max(existingText.count, 1))
        return existingCoverage >= 0.75 || (lengthRatio >= 0.85 && existingCoverage >= 0.5)
    }

    private static func normalizedForRebase(_ text: String) -> String {
        let allowed = CharacterSet.letters.union(.decimalDigits)
        var normalized = ""
        var lastWasSpace = true

        for scalar in text.unicodeScalars {
            if allowed.contains(scalar) {
                normalized.append(String(scalar).lowercased())
                lastWasSpace = false
            } else if !lastWasSpace {
                normalized.append(" ")
                lastWasSpace = true
            }
        }

        return normalized.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func mergeOverlappingText(_ left: String, _ right: String) -> String {
        let left = left.trimmingCharacters(in: .whitespacesAndNewlines)
        let right = right.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !left.isEmpty else { return right }
        guard !right.isEmpty else { return left }

        let overlap = longestSuffixPrefixOverlap(left: left, right: right)
        if overlap > 0 {
            let suffixStart = right.index(right.startIndex, offsetBy: overlap)
            return join(left, String(right[suffixStart...]))
        }

        return join(left, right)
    }

    private static func join(_ left: String, _ right: String) -> String {
        let left = left.trimmingCharacters(in: .whitespacesAndNewlines)
        let right = right.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !left.isEmpty else { return right }
        guard !right.isEmpty else { return left }

        if noSpacePrefixes.contains(where: { right.hasPrefix($0) }) {
            return left + right
        }
        return left + " " + right
    }

    private static func longestSuffixPrefixOverlap(left: String, right: String) -> Int {
        let maxLength = min(left.count, right.count)
        guard maxLength > 0 else { return 0 }

        let normalizedLeft = left.lowercased()
        let normalizedRight = right.lowercased()

        for length in stride(from: maxLength, through: 1, by: -1) {
            let leftSuffixStart = normalizedLeft.index(normalizedLeft.endIndex, offsetBy: -length)
            let rightPrefixEnd = normalizedRight.index(normalizedRight.startIndex, offsetBy: length)
            if normalizedLeft[leftSuffixStart...] == normalizedRight[..<rightPrefixEnd] {
                return length
            }
        }

        return 0
    }

    private static let sameWindowStartTolerance: TimeInterval = 0.35
    private static let rebasedStartTolerance: TimeInterval = 0.35
    private static let nextWindowOverlapTolerance: TimeInterval = 0.12
    private static let revisionPrefixThreshold = 10
    private static let shortRegressionSlack = 8
    private static let noSpacePrefixes = [".", ",", "!", "?", ":", ";", ")", "]", "}", "%"]
}
