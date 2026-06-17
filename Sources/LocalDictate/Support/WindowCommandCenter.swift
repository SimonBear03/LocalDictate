import SwiftUI

@MainActor
final class WindowCommandCenter {
    static let shared = WindowCommandCenter()

    private var openMainWindowAction: (() -> Void)?

    private init() {}

    func install(openMainWindow: @escaping () -> Void) {
        openMainWindowAction = openMainWindow
    }

    func openMainWindow() {
        if let openMainWindowAction {
            openMainWindowAction()
        } else {
            WindowFocusService.focusMainWindow()
        }
    }

    func openSettings() {
        LocalDictateApp.sharedModel.selectedSidebarSection = .settings
        openMainWindow()
    }
}

struct WindowCommandInstaller: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .onAppear {
                WindowCommandCenter.shared.install {
                    openWindow(id: WindowID.main.rawValue)
                    WindowFocusService.focusMainWindow()
                }
            }
    }
}
