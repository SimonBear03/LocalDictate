import AppKit

@MainActor
enum WindowFocusService {
    static func activateApp() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
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
