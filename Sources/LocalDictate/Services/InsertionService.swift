import AppKit
import ApplicationServices
import LocalDictateCore

enum InsertionResult: Sendable {
    case empty
    case copied
    case pasted
    case copiedAccessibilityMissing
}

final class InsertionService {
    func insertOrCopy(_ text: String, mode: InsertionMode) throws -> InsertionResult {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .empty
        }

        let pasteboard = NSPasteboard.general
        let previousString = pasteboard.string(forType: .string)
        pasteboard.clearContents()
        pasteboard.setString(trimmed, forType: .string)

        guard mode == .autoPaste else {
            return .copied
        }

        guard AXIsProcessTrusted() else {
            return .copiedAccessibilityMissing
        }

        postCommandV()

        if let previousString {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                pasteboard.clearContents()
                pasteboard.setString(previousString, forType: .string)
            }
        }
        return .pasted
    }

    private func postCommandV() {
        let source = CGEventSource(stateID: .hidSystemState)
        let keyCodeForV: CGKeyCode = 9
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCodeForV, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCodeForV, keyDown: false)
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}
