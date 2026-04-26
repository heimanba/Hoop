import Foundation
import SwiftData

@Model
final class LocalUserProfile {
    @Attribute(.unique) var id: String
    var displayName: String
    var role: UserRole
    var avatarEmoji: String
    var createdAt: Date

    init(
        id: String = UUID().uuidString,
        displayName: String,
        role: UserRole,
        avatarEmoji: String,
        createdAt: Date = .now
    ) {
        self.id = id
        self.displayName = displayName
        self.role = role
        self.avatarEmoji = avatarEmoji
        self.createdAt = createdAt
    }
}
