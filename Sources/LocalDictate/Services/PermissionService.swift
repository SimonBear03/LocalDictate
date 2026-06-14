import AVFoundation
import ApplicationServices
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
        AXIsProcessTrusted() ? .granted : .notDetermined
    }

    static func requestAccessibilityPrompt() -> PermissionState {
        let promptKey = "AXTrustedCheckOptionPrompt"
        return AXIsProcessTrustedWithOptions([promptKey: true] as CFDictionary) ? .granted : accessibilityState()
    }
}
