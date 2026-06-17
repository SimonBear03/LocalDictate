import Foundation

enum MenuBarVisualKind: String, Equatable {
    case idle
    case recording
    case cleaning
    case successFlash
    case errorFlash

    var returnsToIdleAfterNanoseconds: UInt64? {
        switch self {
        case .idle, .recording, .cleaning:
            nil
        case .successFlash, .errorFlash:
            1_050_000_000
        }
    }
}

struct MenuBarVisualState: Equatable {
    var kind: MenuBarVisualKind
    var generation: Int

    static let idle = MenuBarVisualState(kind: .idle, generation: 0)
}
