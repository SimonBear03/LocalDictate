import AppKit
import LocalDictateCore
import SwiftUI

@main
@MainActor
struct LocalDictateApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    static let sharedModel = LocalDictateModel()
    private let model = LocalDictateApp.sharedModel

    init() {
        model.launch()
    }

    var body: some Scene {
        Window("LocalDictate", id: WindowID.main.rawValue) {
            MainWindowView()
                .environmentObject(model)
                .tint(.blue)
                .accentColor(.blue)
                .configuredAppWindowAppearance()
                .background(WindowCommandInstaller())
                .frame(minWidth: 720, minHeight: 420)
        }
        .defaultSize(width: 980, height: 660)
        .defaultLaunchBehavior(.presented)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Toggle Recording") {
                    model.toggleRecording()
                }
                .keyboardShortcut("d", modifiers: [.command])
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusBarController = StatusBarController(model: LocalDictateApp.sharedModel)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        WindowFocusService.focusMainWindow()
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
    }
}

enum WindowID: String {
    case main
}
