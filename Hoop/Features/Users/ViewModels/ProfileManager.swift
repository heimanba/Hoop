import Observation
import SwiftData
import SwiftUI

@MainActor
@Observable
final class ProfileManager {
    enum ParentAccessPolicy {
        case open
        case requiresDevicePassword
    }

    enum ProfileState: Equatable {
        case noProfiles
        case selecting
        case ready(LocalUserProfile)

        static func == (lhs: ProfileState, rhs: ProfileState) -> Bool {
            switch (lhs, rhs) {
            case (.noProfiles, .noProfiles), (.selecting, .selecting):
                true
            case let (.ready(lhsProfile), .ready(rhsProfile)):
                lhsProfile.id == rhsProfile.id
            default:
                false
            }
        }
    }

    private(set) var state: ProfileState = .noProfiles
    private(set) var parentAccessPolicy: ParentAccessPolicy = .open

    @ObservationIgnored
    @AppStorage("activeProfileID") private var activeProfileID: String?

    var currentProfile: LocalUserProfile? {
        guard case let .ready(profile) = state else { return nil }
        return profile
    }

    func resolve(from profiles: [LocalUserProfile]) {
        guard !profiles.isEmpty else {
            state = .noProfiles
            parentAccessPolicy = .open
            return
        }

        guard let activeProfileID,
              let activeProfile = profiles.first(where: { $0.id == activeProfileID }) else {
            state = .selecting
            return
        }

        state = .ready(activeProfile)
    }

    func select(_ profile: LocalUserProfile) {
        activeProfileID = profile.id
        parentAccessPolicy = .open
        state = .ready(profile)
    }

    func clearSelection(from profiles: [LocalUserProfile]) {
        activeProfileID = nil
        resolve(from: profiles)
    }

    func beginProfileSelection(from currentProfile: LocalUserProfile?) {
        activeProfileID = nil
        parentAccessPolicy = currentProfile?.role == .player ? .requiresDevicePassword : .open
        state = .selecting
    }

    func requiresDevicePassword(toSelect profile: LocalUserProfile) -> Bool {
        profile.role == .parent && parentAccessPolicy == .requiresDevicePassword
    }

    @discardableResult
    func createProfile(
        displayName: String,
        role: UserRole,
        avatarEmoji: String,
        preferredID: String? = nil,
        selectAfterCreation: Bool,
        in context: ModelContext
    ) throws -> LocalUserProfile {
        let normalizedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedName.isEmpty else {
            throw ProfileError.emptyDisplayName
        }

        let profile = LocalUserProfile(
            id: preferredID ?? UUID().uuidString,
            displayName: normalizedName,
            role: role,
            avatarEmoji: avatarEmoji.isEmpty ? role.defaultAvatar : avatarEmoji
        )

        context.insert(profile)
        try context.save()

        if selectAfterCreation {
            select(profile)
        }

        return profile
    }

    func deleteProfile(
        _ profile: LocalUserProfile,
        from profiles: [LocalUserProfile],
        in context: ModelContext
    ) throws {
        guard profiles.count > 1 else {
            throw ProfileError.lastProfileDeletionNotAllowed
        }

        let remainingParents = profiles.filter { $0.id != profile.id && $0.role == .parent }
        if profile.role == .parent && remainingParents.isEmpty {
            throw ProfileError.lastParentDeletionNotAllowed
        }

        let wasActiveProfile = profile.id == activeProfileID
        context.delete(profile)
        try context.save()

        if wasActiveProfile {
            activeProfileID = nil
        }
    }
}

enum ProfileError: LocalizedError {
    case emptyDisplayName
    case lastProfileDeletionNotAllowed
    case lastParentDeletionNotAllowed

    var errorDescription: String? {
        switch self {
        case .emptyDisplayName:
            "请先填写成员名称。"
        case .lastProfileDeletionNotAllowed:
            "至少需要保留一个本地成员。"
        case .lastParentDeletionNotAllowed:
            "至少需要保留一个家长成员。"
        }
    }
}
