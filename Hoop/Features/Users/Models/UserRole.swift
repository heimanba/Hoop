import Foundation

enum UserRole: String, Codable, CaseIterable, Identifiable {
    case parent
    case player

    var id: String { rawValue }

    var title: String {
        switch self {
        case .parent:
            "家长"
        case .player:
            "球员"
        }
    }

    var badgeTitle: String {
        switch self {
        case .parent:
            "家长视角"
        case .player:
            "球员视角"
        }
    }

    var defaultAvatar: String {
        switch self {
        case .parent:
            "👨"
        case .player:
            "🏀"
        }
    }

    var canManageUsers: Bool { self == .parent }
    var canViewAllData: Bool { self == .parent }
    var canAccessSettings: Bool { self == .parent }
    var canSwitchProfiles: Bool { self == .parent }
    var canUpload: Bool { self == .player }
    var canViewOwnTraining: Bool { self == .player }

    /// 管理员可删除任意视频，球员只能删除自己的视频
    func canDeleteVideo(postPlayerID: String, currentProfileID: String) -> Bool {
        switch self {
        case .parent: return true
        case .player: return postPlayerID == currentProfileID
        }
    }
}
