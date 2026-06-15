import AppKit
import ApplicationServices
import LocalDictateCore

enum InsertionResult: Sendable {
    case empty
    case copied
    case pasted
    case copiedAccessibilityMissing
    case noEditableTextField
}

final class InsertionService {
    func insertOrCopy(_ text: String, mode: InsertionMode) throws -> InsertionResult {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return .empty
        }

        let pasteboard = NSPasteboard.general
        if mode == .copyOnly {
            pasteboard.clearContents()
            pasteboard.setString(trimmed, forType: .string)
            return .copied
        }

        guard AXIsProcessTrusted() else {
            return .copiedAccessibilityMissing
        }

        guard focusedElementAcceptsTextInput() else {
            return .noEditableTextField
        }

        let previousPasteboard = PasteboardSnapshot.capture(from: pasteboard)
        pasteboard.clearContents()
        pasteboard.setString(trimmed, forType: .string)
        postCommandV()

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            previousPasteboard.restore(to: pasteboard)
        }
        return .pasted
    }

    private func focusedElementAcceptsTextInput() -> Bool {
        let systemElement = AXUIElementCreateSystemWide()
        var focusedValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            systemElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedValue
        ) == .success, let focusedValue else {
            return false
        }

        guard CFGetTypeID(focusedValue) == AXUIElementGetTypeID() else {
            return false
        }
        let focusedElement = focusedValue as! AXUIElement
        guard !hasSecureTextSubrole(focusedElement) else {
            return false
        }

        if isKnownTextInputRole(focusedElement) {
            return true
        }

        var isSettable = DarwinBoolean(false)
        if AXUIElementIsAttributeSettable(
            focusedElement,
            kAXValueAttribute as CFString,
            &isSettable
        ) == .success, isSettable.boolValue {
            return true
        }

        return false
    }

    private func isKnownTextInputRole(_ element: AXUIElement) -> Bool {
        guard let role = stringAttribute(kAXRoleAttribute, from: element) else {
            return false
        }

        return [
            kAXTextFieldRole,
            kAXTextAreaRole,
            kAXComboBoxRole
        ].contains(role)
    }

    private func hasSecureTextSubrole(_ element: AXUIElement) -> Bool {
        stringAttribute(kAXSubroleAttribute, from: element) == "AXSecureTextField"
    }

    private func stringAttribute(_ attribute: String, from element: AXUIElement) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else {
            return nil
        }
        return value as? String
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

private struct PasteboardSnapshot: @unchecked Sendable {
    var items: [NSPasteboardItem]

    static func capture(from pasteboard: NSPasteboard) -> PasteboardSnapshot {
        let copiedItems = pasteboard.pasteboardItems?.compactMap {
            $0.copy() as? NSPasteboardItem
        } ?? []
        return PasteboardSnapshot(items: copiedItems)
    }

    func restore(to pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        guard !items.isEmpty else { return }
        pasteboard.writeObjects(items)
    }
}
