import AppKit
import SwiftUI

struct WindowAppearanceConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async {
            configure(window: view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            configure(window: nsView.window)
        }
    }

    private func configure(window: NSWindow?) {
        guard let window else { return }

        window.isOpaque = true
        window.backgroundColor = .windowBackgroundColor
        window.titlebarAppearsTransparent = false
        window.hasShadow = true
        window.appearance = nil

        if #available(macOS 11.0, *) {
            window.toolbarStyle = .unified
        }
    }
}

extension View {
    func systemWindowSurface() -> some View {
        scrollContentBackground(.hidden)
            .background(Color(nsColor: .windowBackgroundColor))
    }

    func systemSidebarSurface() -> some View {
        scrollContentBackground(.hidden)
            .background(Color(nsColor: .controlBackgroundColor))
    }

    func systemGroupedRowSurface() -> some View {
        listRowBackground(Color(nsColor: .controlBackgroundColor))
    }

    func configuredAppWindowAppearance() -> some View {
        background(WindowAppearanceConfigurator().frame(width: 0, height: 0))
    }
}
