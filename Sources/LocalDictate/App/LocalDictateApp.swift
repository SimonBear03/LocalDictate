import AppKit
import LocalDictateCore
import SwiftUI

@main
struct LocalDictateApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = LocalDictateModel()

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView()
                .environmentObject(model)
                .tint(.blue)
                .accentColor(.blue)
        } label: {
            Label(model.status.title, systemImage: model.status.systemImage)
        }
        .menuBarExtraStyle(.window)

        Window("LocalDictate", id: WindowID.main.rawValue) {
            MainWindowView()
                .environmentObject(model)
                .tint(.blue)
                .accentColor(.blue)
                .configuredAppWindowAppearance()
                .frame(minWidth: 880, minHeight: 580)
                .task {
                    model.launch()
                }
        }
        .defaultSize(width: 980, height: 680)
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
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        WindowFocusService.activateApp()
        return true
    }
}

enum WindowID: String {
    case main
}
