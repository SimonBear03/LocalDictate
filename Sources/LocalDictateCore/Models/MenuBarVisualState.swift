import Foundation

public enum MenuBarVisualKind: String, Equatable, Sendable {
    case idle
    case recording
    case cleaning
    case successFlash
    case errorFlash

    public var returnsToIdleAfterNanoseconds: UInt64? {
        switch self {
        case .idle, .recording, .cleaning:
            nil
        case .successFlash, .errorFlash:
            1_050_000_000
        }
    }
}

public struct MenuBarVisualState: Equatable, Sendable {
    public var kind: MenuBarVisualKind
    public var generation: Int

    public init(kind: MenuBarVisualKind, generation: Int) {
        self.kind = kind
        self.generation = generation
    }

    public static let idle = MenuBarVisualState(kind: .idle, generation: 0)
}
