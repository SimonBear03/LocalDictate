import AppKit
import Combine
import LocalDictateCore
import SwiftUI

@MainActor
final class StatusBarController: NSObject {
    private let model: LocalDictateModel
    private let statusItem: NSStatusItem
    private let popover = NSPopover()
    private var cancellables = Set<AnyCancellable>()
    private var currentVisualState: MenuBarVisualState = .idle
    private var animationStartDate = Date()
    private var animationTimer: Timer?

    init(model: LocalDictateModel) {
        self.model = model
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()
        configureStatusItem()
        configurePopover()
        bindStatus()
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(togglePopover(_:))
        button.imagePosition = .imageOnly
        button.toolTip = model.status.menuTitle
        button.setButtonType(.momentaryPushIn)
        updateStatusButton()
    }

    private func configurePopover() {
        popover.behavior = .transient
        popover.contentSize = NSSize(width: 340, height: 440)
        popover.contentViewController = NSHostingController(
            rootView: MenuBarContentView(
                openMainWindow: { [weak self] in
                    self?.closePopover()
                    WindowCommandCenter.shared.openMainWindow()
                },
                openSettings: { [weak self] in
                    self?.closePopover()
                    WindowCommandCenter.shared.openSettings()
                }
            )
            .environmentObject(model)
            .tint(.blue)
            .accentColor(.blue)
        )
    }

    private func bindStatus() {
        model.$menuBarVisualState
            .receive(on: RunLoop.main)
            .sink { [weak self] visualState in
                self?.applyVisualState(visualState)
            }
            .store(in: &cancellables)

        model.$status
            .receive(on: RunLoop.main)
            .sink { [weak self] status in
                self?.statusItem.button?.toolTip = status.menuTitle
            }
            .store(in: &cancellables)
    }

    private func applyVisualState(_ visualState: MenuBarVisualState) {
        currentVisualState = visualState
        animationStartDate = Date()
        configureAnimationTimer()
        updateStatusButton()
    }

    private func configureAnimationTimer() {
        animationTimer?.invalidate()
        guard currentVisualState.kind.isAnimated else {
            animationTimer = nil
            return
        }

        animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.updateStatusButton()
            }
        }
    }

    private func updateStatusButton() {
        guard let button = statusItem.button else { return }
        button.image = StatusBarBadgeRenderer.image(
            visualState: currentVisualState,
            appearance: button.effectiveAppearance,
            elapsed: Date().timeIntervalSince(animationStartDate)
        )
        statusItem.length = StatusBarBadgeRenderer.statusItemLength
    }

    @objc private func togglePopover(_ sender: NSStatusBarButton) {
        if popover.isShown {
            closePopover()
        } else {
            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func closePopover() {
        popover.performClose(nil)
    }

}

private enum StatusBarBadgeRenderer {
    static let statusItemLength: CGFloat = 28

    static func image(visualState: MenuBarVisualState, appearance: NSAppearance, elapsed: TimeInterval) -> NSImage {
        let size = NSSize(width: 28, height: 22)
        let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua

        let image = NSImage(size: size, flipped: false) { rect in
            let palette = visualState.kind.menuBarPalette(isDark: isDark)
            let intensity = visualState.kind.animationIntensity(elapsed: elapsed)

            if let background = palette.background, intensity > 0.01 {
                let diameter = 17.5 + (4.5 * intensity)
                let circleRect = NSRect(
                    x: (rect.width - diameter) / 2,
                    y: (rect.height - diameter) / 2,
                    width: diameter,
                    height: diameter
                )
                let badgePath = NSBezierPath(ovalIn: circleRect)
                background.withAlphaComponent(palette.alpha(intensity: intensity)).setFill()
                badgePath.fill()
            }

            drawTextCursorSymbol(in: rect, color: palette.foreground(intensity: intensity, isDark: isDark))
            return true
        }
        image.isTemplate = false
        return image
    }

    private static func drawTextCursorSymbol(in rect: NSRect, color: NSColor) {
        let configuration = NSImage.SymbolConfiguration(pointSize: 18, weight: .regular)
            .applying(.init(hierarchicalColor: color))
        guard let symbol = NSImage(
            systemSymbolName: "text.cursor",
            accessibilityDescription: "LocalDictate"
        )?.withSymbolConfiguration(configuration) else {
            return
        }

        let symbolSize = symbol.size
        let targetHeight: CGFloat = 18
        let targetWidth = targetHeight * symbolSize.width / max(symbolSize.height, 1)
        let symbolRect = NSRect(
            x: (rect.width - targetWidth) / 2,
            y: (rect.height - targetHeight) / 2 - 0.3,
            width: targetWidth,
            height: targetHeight
        )
        symbol.draw(
            in: symbolRect,
            from: NSRect(origin: .zero, size: symbol.size),
            operation: .sourceOver,
            fraction: 1
        )
    }
}

private extension MenuBarVisualKind {
    struct MenuBarPalette {
        let background: NSColor?
        let activeForeground: NSColor

        func alpha(intensity: Double) -> CGFloat {
            CGFloat(0.50 + (0.50 * intensity))
        }

        func foreground(intensity: Double, isDark: Bool) -> NSColor {
            guard background != nil, intensity > 0.22 else {
                return .labelColor
            }
            return activeForeground
        }
    }

    func menuBarPalette(isDark: Bool) -> MenuBarPalette {
        switch self {
        case .idle:
            return MenuBarPalette(
                background: nil,
                activeForeground: .labelColor
            )
        case .recording:
            return activePalette(NSColor(calibratedRed: 1.0, green: 0.48, blue: 0.0, alpha: 1.0), isDark: isDark)
        case .cleaning:
            return activePalette(NSColor(calibratedRed: 0.0, green: 0.62, blue: 1.0, alpha: 1.0), isDark: isDark)
        case .successFlash:
            return activePalette(NSColor.systemGreen, isDark: isDark)
        case .errorFlash:
            return activePalette(NSColor.systemRed, isDark: isDark)
        }
    }

    var isAnimated: Bool {
        switch self {
        case .idle:
            false
        case .recording, .cleaning, .successFlash, .errorFlash:
            true
        }
    }

    func animationIntensity(elapsed: TimeInterval) -> Double {
        switch self {
        case .idle:
            0
        case .recording:
            breathingIntensity(elapsed: elapsed, period: 1.10)
        case .cleaning:
            breathingIntensity(elapsed: elapsed, period: 0.82)
        case .successFlash, .errorFlash:
            threeBlinkIntensity(elapsed: elapsed)
        }
    }

    private func activePalette(_ color: NSColor, isDark: Bool) -> MenuBarPalette {
        MenuBarPalette(
            background: color,
            activeForeground: .white
        )
    }

    private func breathingIntensity(elapsed: TimeInterval, period: TimeInterval) -> Double {
        let position = (elapsed.truncatingRemainder(dividingBy: period)) / period
        let wave = (1 - cos(position * 2 * .pi)) / 2
        return 0.38 + (0.62 * wave)
    }

    private func threeBlinkIntensity(elapsed: TimeInterval) -> Double {
        let blinkDuration = 0.28
        guard elapsed < blinkDuration * 3 else { return 0 }
        let position = elapsed.truncatingRemainder(dividingBy: blinkDuration) / blinkDuration
        return sin(position * .pi)
    }
}
