import AppKit
import ApplicationServices
import LocalDictateCore

final class InsertionService {
    func insertOrCopy(_ text: String, mode: InsertionMode) throws -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return false
        }

        let pasteboard = NSPasteboard.general
        let previousString = pasteboard.string(forType: .string)
        pasteboard.clearContents()
        pasteboard.setString(trimmed, forType: .string)

        guard mode == .autoPaste, AXIsProcessTrusted() else {
            return false
        }

        postCommandV()

        if let previousString {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                pasteboard.clearContents()
                pasteboard.setString(previousString, forType: .string)
            }
        }
        return true
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

