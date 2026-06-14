import Carbon
import Foundation

enum HotkeyError: LocalizedError {
    case registrationFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case .registrationFailed(let status):
            "Could not register global hotkey. OSStatus \(status)."
        }
    }
}

final class HotkeyService {
    private let actionBox = HotkeyActionBox()
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?

    deinit {
        unregister()
    }

    func registerCommandD(action: @escaping @MainActor @Sendable () -> Void) throws {
        unregister()
        actionBox.action = action

        var eventSpec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let userData = Unmanaged.passUnretained(actionBox).toOpaque()
        let handlerStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            hotkeyEventHandler,
            1,
            &eventSpec,
            userData,
            &eventHandlerRef
        )
        guard handlerStatus == noErr else {
            throw HotkeyError.registrationFailed(handlerStatus)
        }

        let hotKeyID = EventHotKeyID(signature: Self.signature, id: Self.commandDID)
        let registerStatus = RegisterEventHotKey(
            UInt32(kVK_ANSI_D),
            UInt32(cmdKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        guard registerStatus == noErr else {
            unregister()
            throw HotkeyError.registrationFailed(registerStatus)
        }
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
            self.eventHandlerRef = nil
        }
    }

    fileprivate static let signature = fourCharCode("LDct")
    fileprivate static let commandDID: UInt32 = 1
}

private final class HotkeyActionBox: @unchecked Sendable {
    var action: (@MainActor @Sendable () -> Void)?
}

private let hotkeyEventHandler: EventHandlerUPP = { _, event, userData in
    guard let event, let userData else {
        return noErr
    }

    var hotKeyID = EventHotKeyID()
    let status = GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotKeyID
    )
    guard status == noErr else {
        return status
    }

    guard hotKeyID.signature == HotkeyService.signature,
          hotKeyID.id == HotkeyService.commandDID else {
        return noErr
    }

    let box = Unmanaged<HotkeyActionBox>.fromOpaque(userData).takeUnretainedValue()
    Task { @MainActor in
        box.action?()
    }
    return noErr
}

private func fourCharCode(_ string: String) -> OSType {
    string.utf8.reduce(0) { result, character in
        (result << 8) + OSType(character)
    }
}
