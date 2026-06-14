import SwiftUI

enum SidebarSection: String, CaseIterable, Identifiable {
    case history
    case templates
    case settings
    case privacy
    case diagnostics

    var id: String { rawValue }

    var title: String {
        switch self {
        case .history: "History"
        case .templates: "Templates"
        case .settings: "Settings"
        case .privacy: "Privacy"
        case .diagnostics: "Diagnostics"
        }
    }

    var systemImage: String {
        switch self {
        case .history: "clock"
        case .templates: "text.badge.star"
        case .settings: "gearshape"
        case .privacy: "hand.raised"
        case .diagnostics: "stethoscope"
        }
    }
}
