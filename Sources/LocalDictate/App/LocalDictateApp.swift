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
        } label: {
            Label(model.status.title, systemImage: model.status.systemImage)
        }
        .menuBarExtraStyle(.window)

        WindowGroup("LocalDictate", id: WindowID.main.rawValue) {
            MainWindowView()
                .environmentObject(model)
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
                .keyboardShortcut("r", modifiers: [.command, .shift])
            }
        }

        Settings {
            SettingsView()
                .environmentObject(model)
                .frame(width: 520)
                .task {
                    model.launch()
                }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}

enum WindowID: String {
    case main
}

