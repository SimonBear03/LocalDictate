import AppKit
import LocalDictateCore
import SwiftUI

@main
@MainActor
struct LocalDictateApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model: LocalDictateModel

    init() {
        let model = LocalDictateModel()
        _model = StateObject(wrappedValue: model)
        Task { @MainActor [model] in
            model.launch()
        }
    }

    var body: some Scene {
        MenuBarExtra("A", systemImage: "text.cursor") {
            MenuBarContentView()
                .environmentObject(model)
                .tint(.blue)
                .accentColor(.blue)
        }
        .menuBarExtraStyle(.window)

        Window("LocalDictate", id: WindowID.main.rawValue) {
            MainWindowView()
                .environmentObject(model)
                .tint(.blue)
                .accentColor(.blue)
                .configuredAppWindowAppearance()
                .frame(minWidth: 720, minHeight: 420)
                .task {
                    model.launch()
                }
        }
        .defaultSize(width: 980, height: 660)
        .defaultLaunchBehavior(.presented)
        .commands {
            CommandGroup(after: .newItem) {
                Button(model.status == .listening ? "Stop Recording" : "Start Recording") {
                    model.toggleRecording()
                }
                .keyboardShortcut("d", modifiers: [.command])
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        WindowFocusService.focusMainWindow()
        return true
    }
}

enum WindowID: String {
    case main
}
