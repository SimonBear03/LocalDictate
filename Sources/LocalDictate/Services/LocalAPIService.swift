import Foundation

struct LocalAPIStatus: Sendable {
    var isEnabled: Bool
    var endpoint: String
    var detail: String

    static let disabled = LocalAPIStatus(
        isEnabled: false,
        endpoint: "127.0.0.1",
        detail: "The local automation API is disabled. It will be opt-in before tools like StickS3 Companion use it."
    )
}

final class LocalAPIService: ObservableObject {
    @Published private(set) var status: LocalAPIStatus = .disabled
}

