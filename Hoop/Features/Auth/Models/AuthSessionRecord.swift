import Foundation
import SwiftData

@Model
final class AuthSessionRecord {
    @Attribute(.unique) var key: String
    var userID: String
    var email: String
    var displayName: String
    var signedInAt: Date

    init(
        key: String = "current-user",
        userID: String,
        email: String,
        displayName: String,
        signedInAt: Date
    ) {
        self.key = key
        self.userID = userID
        self.email = email
        self.displayName = displayName
        self.signedInAt = signedInAt
    }
}
