import SwiftUI

enum AppTab: String, CaseIterable, Hashable, Identifiable {
    case feed
    case profile

    var id: String { rawValue }

    var title: String {
        switch self {
        case .feed: "动态"
        case .profile: "我的"
        }
    }

    var systemImage: String {
        switch self {
        case .feed: "play.rectangle.on.rectangle"
        case .profile: "person.crop.circle"
        }
    }
}
