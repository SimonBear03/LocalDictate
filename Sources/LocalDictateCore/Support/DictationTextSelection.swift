import Foundation

public enum DictationTextSelection {
    public static func preferredText(rawTranscript: String, cleanedText: String) -> String {
        let cleaned = cleanedText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !cleaned.isEmpty {
            return cleaned
        }
        return rawTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
