import AppKit

@MainActor
enum WindowFocusService {
    static func activateApp() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    static func restoreAccessoryModeSoon() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            guard !NSApp.windows.contains(where: { $0.isVisible && $0.isKeyWindow }) else {
                return
            }
            NSApp.setActivationPolicy(.accessory)
        }
    }

    static func focusMainWindow() {
        DispatchQueue.main.async {
            activateApp()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                let window = NSApp.windows.first { window in
                    window.title.localizedCaseInsensitiveContains("LocalDictate")
                }
                window?.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }

}
