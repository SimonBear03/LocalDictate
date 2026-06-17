import AVFoundation
import ApplicationServices
import AppKit
import LocalDictateCore
import Speech

enum PermissionService {
    static func snapshot() -> PermissionSnapshot {
        PermissionSnapshot(
            microphone: microphoneState(),
            speech: speechState(),
            accessibility: accessibilityState()
        )
    }

    static func microphoneState() -> PermissionState {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized: .granted
        case .denied: .denied
        case .restricted: .restricted
        case .notDetermined: .notDetermined
        @unknown default: .unknown
        }
    }

    static func requestMicrophone() async -> PermissionState {
        let granted = await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                continuation.resume(returning: granted)
            }
        }
        return granted ? .granted : microphoneState()
    }

    static func speechState() -> PermissionState {
        switch SFSpeechRecognizer.authorizationStatus() {
        case .authorized: .granted
        case .denied: .denied
        case .restricted: .restricted
        case .notDetermined: .notDetermined
        @unknown default: .unknown
        }
    }

    static func requestSpeech() async -> PermissionState {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                let state: PermissionState
                switch status {
                case .authorized: state = .granted
                case .denied: state = .denied
                case .restricted: state = .restricted
                case .notDetermined: state = .notDetermined
                @unknown default: state = .unknown
                }
                continuation.resume(returning: state)
            }
        }
    }

    static func accessibilityState() -> PermissionState {
        AXIsProcessTrusted() ? .granted : .denied
    }

    @MainActor
    static func requestAccessibilityPrompt() -> PermissionState {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options) ? .granted : accessibilityState()
    }

    @MainActor
    static func confirmOpenAccessibilitySettings() -> Bool {
        // Keep this as an explicit user-confirmed alert instead of an implicit settings jump.
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "Enable Accessibility for Auto Paste"
        alert.informativeText = "macOS requires you to manually enable Accessibility permission before LocalDictate can paste into other apps. Your dictated text has been copied, so it is not lost."
        alert.addButton(withTitle: "Open Accessibility Settings")
        alert.addButton(withTitle: "Not Now")

        return alert.runModal() == .alertFirstButtonReturn
    }

    @MainActor
    static func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/System Settings.app"))
            return
        }

        NSWorkspace.shared.open(url)
    }
}
