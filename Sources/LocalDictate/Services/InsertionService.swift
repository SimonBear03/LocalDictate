import AppKit
import ApplicationServices
import LocalDictateCore
import OSLog

private let insertionLogger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "com.simonbear.localdictate",
    category: "Insertion"
)

enum InsertionResult: Sendable {
    case empty
    case copied
    case pasted
    case copiedAccessibilityMissing
    case noEditableTextField

    var title: String {
        switch self {
        case .empty: "Empty"
        case .copied: "Copied"
        case .pasted: "Pasted"
        case .copiedAccessibilityMissing: "Copied - Accessibility Missing"
        case .noEditableTextField: "No Editable Text Field"
        }
    }
}

struct InsertionOutcome: Sendable {
    var result: InsertionResult
    var diagnostics: InsertionDiagnostics
}

struct InsertionDiagnostics: Sendable {
    var result: InsertionResult
    var mode: InsertionMode
    var characters: Int
    var frontmostAppName: String
    var accessibilityTrusted: Bool
    var focusSource: String?
    var focusReason: String?
    var focusRole: String?
    var focusSubrole: String?
    var focusValueSettable: Bool?
}

@MainActor
final class InsertionService {
    func insertOrCopy(_ text: String, mode: InsertionMode) throws -> InsertionOutcome {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let frontmostAppName = TargetAppService.frontmostAppName()
        RuntimeDiagnostics.logSync(
            scope: "Insertion",
            message: "insertOrCopy begin",
            details: "mode=\(mode.rawValue) chars=\(trimmed.count) frontmost=\(frontmostAppName)"
        )
        guard !trimmed.isEmpty else {
            RuntimeDiagnostics.logSync(scope: "Insertion", message: "empty text")
            insertionLogger.info("insertion skipped reason=empty")
            return outcome(
                result: .empty,
                mode: mode,
                characters: 0,
                frontmostAppName: frontmostAppName,
                accessibilityTrusted: AXIsProcessTrusted()
            )
        }

        insertionLogger.info(
            "insertion requested mode=\(mode.rawValue, privacy: .public) chars=\(trimmed.count, privacy: .public) frontmost=\(frontmostAppName, privacy: .public)"
        )

        let pasteboard = NSPasteboard.general
        if mode == .copyOnly {
            RuntimeDiagnostics.logSync(scope: "Insertion", message: "copyOnly pasteboard write begin")
            pasteboard.clearContents()
            pasteboard.setString(trimmed, forType: .string)
            RuntimeDiagnostics.logSync(scope: "Insertion", message: "copyOnly pasteboard write complete")
            insertionLogger.info("insertion completed result=copied chars=\(trimmed.count, privacy: .public)")
            return outcome(
                result: .copied,
                mode: mode,
                characters: trimmed.count,
                frontmostAppName: frontmostAppName,
                accessibilityTrusted: AXIsProcessTrusted()
            )
        }

        let accessibilityTrusted = AXIsProcessTrusted()
        guard accessibilityTrusted else {
            RuntimeDiagnostics.logSync(scope: "Insertion", message: "blocked: accessibility missing")
            insertionLogger.warning("insertion blocked result=accessibilityMissing")
            return outcome(
                result: .copiedAccessibilityMissing,
                mode: mode,
                characters: trimmed.count,
                frontmostAppName: frontmostAppName,
                accessibilityTrusted: false
            )
        }

        RuntimeDiagnostics.logSync(scope: "Insertion", message: "focus check begin")
        let focusStatus = focusedElementTextInputStatus()
        RuntimeDiagnostics.logSync(
            scope: "Insertion",
            message: "focus check complete",
            details: "allowsPaste=\(focusStatus.allowsPaste) source=\(focusStatus.source) reason=\(focusStatus.reason) role=\(focusStatus.role ?? "nil") subrole=\(focusStatus.subrole ?? "nil")"
        )
        insertionLogger.info(
            "paste-time focus check accepts=\(focusStatus.acceptsText, privacy: .public) allowsPaste=\(focusStatus.allowsPaste, privacy: .public) source=\(focusStatus.source, privacy: .public) reason=\(focusStatus.reason, privacy: .public) role=\(focusStatus.role ?? "nil", privacy: .public) subrole=\(focusStatus.subrole ?? "nil", privacy: .public) valueSettable=\(focusStatus.isValueSettable, privacy: .public)"
        )

        guard focusStatus.allowsPaste else {
            RuntimeDiagnostics.logSync(scope: "Insertion", message: "blocked: no editable text field")
            return outcome(
                result: .noEditableTextField,
                mode: mode,
                characters: trimmed.count,
                frontmostAppName: frontmostAppName,
                accessibilityTrusted: true,
                focusStatus: focusStatus
            )
        }

        RuntimeDiagnostics.logSync(scope: "Insertion", message: "pasteboard text snapshot begin")
        let previousPasteboard = PasteboardSnapshot.capture(from: pasteboard)
        RuntimeDiagnostics.logSync(scope: "Insertion", message: "pasteboard text snapshot complete")
        RuntimeDiagnostics.logSync(scope: "Insertion", message: "pasteboard write begin")
        pasteboard.clearContents()
        pasteboard.setString(trimmed, forType: .string)
        RuntimeDiagnostics.logSync(scope: "Insertion", message: "command-v post begin")
        postCommandV()
        RuntimeDiagnostics.logSync(scope: "Insertion", message: "command-v post complete")
        insertionLogger.info(
            "insertion completed result=pasted chars=\(trimmed.count, privacy: .public) frontmost=\(frontmostAppName, privacy: .public) focusConfirmed=\(focusStatus.acceptsText, privacy: .public)"
        )

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            RuntimeDiagnostics.logSync(scope: "Insertion", message: "pasteboard restore begin")
            previousPasteboard.restore(to: pasteboard)
            RuntimeDiagnostics.logSync(scope: "Insertion", message: "pasteboard restore complete")
            insertionLogger.debug("pasteboard restored after automatic paste")
        }
        return outcome(
            result: .pasted,
            mode: mode,
            characters: trimmed.count,
            frontmostAppName: frontmostAppName,
            accessibilityTrusted: true,
            focusStatus: focusStatus
        )
    }

    private func outcome(
        result: InsertionResult,
        mode: InsertionMode,
        characters: Int,
        frontmostAppName: String,
        accessibilityTrusted: Bool,
        focusStatus: FocusedTextInputStatus? = nil
    ) -> InsertionOutcome {
        InsertionOutcome(
            result: result,
            diagnostics: InsertionDiagnostics(
                result: result,
                mode: mode,
                characters: characters,
                frontmostAppName: frontmostAppName,
                accessibilityTrusted: accessibilityTrusted,
                focusSource: focusStatus?.source,
                focusReason: focusStatus?.reason,
                focusRole: focusStatus?.role,
                focusSubrole: focusStatus?.subrole,
                focusValueSettable: focusStatus?.isValueSettable
            )
        )
    }

    private func focusedElementTextInputStatus() -> FocusedTextInputStatus {
        let lookup = focusedElementLookup()
        guard let focusedValue = lookup.value else {
            return FocusedTextInputStatus(
                acceptsText: false,
                allowsPaste: true,
                source: lookup.source,
                reason: "noFocusedElement",
                role: nil,
                subrole: nil,
                isValueSettable: false
            )
        }

        guard CFGetTypeID(focusedValue) == AXUIElementGetTypeID() else {
            return FocusedTextInputStatus(
                acceptsText: false,
                allowsPaste: true,
                source: lookup.source,
                reason: "focusedValueNotAXElement",
                role: nil,
                subrole: nil,
                isValueSettable: false
            )
        }
        let focusedElement = focusedValue as! AXUIElement
        let role = stringAttribute(kAXRoleAttribute, from: focusedElement)
        let subrole = stringAttribute(kAXSubroleAttribute, from: focusedElement)
        var isSettable = DarwinBoolean(false)
        let settableStatus = AXUIElementIsAttributeSettable(
            focusedElement,
            kAXValueAttribute as CFString,
            &isSettable
        )
        let valueSettable = settableStatus == .success && isSettable.boolValue

        guard subrole != "AXSecureTextField" else {
            return FocusedTextInputStatus(
                acceptsText: false,
                allowsPaste: false,
                source: lookup.source,
                reason: "secureTextField",
                role: role,
                subrole: subrole,
                isValueSettable: valueSettable
            )
        }

        if isKnownTextInputRole(role) {
            return FocusedTextInputStatus(
                acceptsText: true,
                allowsPaste: true,
                source: lookup.source,
                reason: "knownTextRole",
                role: role,
                subrole: subrole,
                isValueSettable: valueSettable
            )
        }

        if valueSettable {
            return FocusedTextInputStatus(
                acceptsText: true,
                allowsPaste: true,
                source: lookup.source,
                reason: "settableAXValue",
                role: role,
                subrole: subrole,
                isValueSettable: valueSettable
            )
        }

        return FocusedTextInputStatus(
            acceptsText: false,
            allowsPaste: false,
            source: lookup.source,
            reason: "notEditable",
            role: role,
            subrole: subrole,
            isValueSettable: valueSettable
        )
    }

    private func focusedElementLookup() -> (value: CFTypeRef?, source: String) {
        let systemElement = AXUIElementCreateSystemWide()
        if let focusedValue = focusedElement(from: systemElement) {
            return (focusedValue, "systemWide")
        }

        guard let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier else {
            return (nil, "systemWide")
        }

        let appElement = AXUIElementCreateApplication(pid)
        if let focusedValue = focusedElement(from: appElement) {
            return (focusedValue, "frontmostApplication")
        }

        return (nil, "frontmostApplication")
    }

    private func focusedElement(from element: AXUIElement) -> CFTypeRef? {
        var focusedValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element,
            kAXFocusedUIElementAttribute as CFString,
            &focusedValue
        ) == .success else {
            return nil
        }
        return focusedValue
    }

    private func isKnownTextInputRole(_ role: String?) -> Bool {
        guard let role else {
            return false
        }

        return [
            kAXTextFieldRole,
            kAXTextAreaRole,
            kAXComboBoxRole
        ].contains(role)
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

private struct FocusedTextInputStatus: Sendable {
    var acceptsText: Bool
    var allowsPaste: Bool
    var source: String
    var reason: String
    var role: String?
    var subrole: String?
    var isValueSettable: Bool
}

private struct PasteboardSnapshot: Sendable {
    var string: String?

    static func capture(from pasteboard: NSPasteboard) -> PasteboardSnapshot {
        PasteboardSnapshot(string: pasteboard.string(forType: .string))
    }

    func restore(to pasteboard: NSPasteboard) {
        guard let string else { return }
        pasteboard.clearContents()
        pasteboard.setString(string, forType: .string)
    }
}
