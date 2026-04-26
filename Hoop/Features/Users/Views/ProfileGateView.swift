import SwiftData
import SwiftUI

struct ProfileGateView: View {
    @Environment(ProfileManager.self) private var profileManager
    @Query(sort: \LocalUserProfile.createdAt) private var profiles: [LocalUserProfile]

    @Bindable var viewModel: AuthViewModel
    let deviceUser: AuthenticatedUser

    var body: some View {
        Group {
            switch profileManager.state {
            case .noProfiles:
                NavigationStack {
                    OnboardingCreateProfileView(mode: .firstProfile(deviceUser: deviceUser))
                }
            case .selecting:
                NavigationStack {
                    ProfileSelectorView(viewModel: viewModel, profiles: profiles)
                }
            case .ready(let profile):
                AppShellView(viewModel: viewModel, deviceUser: deviceUser)
                    .id(profile.id)
            }
        }
        .task(id: profileSnapshot) {
            profileManager.resolve(from: profiles)
        }
    }

    private var profileSnapshot: String {
        profiles
            .map { "\($0.id)|\($0.displayName)|\($0.role.rawValue)|\($0.avatarEmoji)" }
            .joined(separator: "\n")
    }
}

#Preview {
    ProfileGateView(
        viewModel: AuthViewModel(),
        deviceUser: AuthenticatedUser(
            id: "local-parent",
            email: "parent@example.com",
            displayName: "爸爸"
        )
    )
    .environment(Theme())
    .environment(ProfileManager())
    .modelContainer(
        for: [AuthSessionRecord.self, LocalUserProfile.self, UploadedTrainingVideoRecord.self, TrainingVideoPost.self],
        inMemory: true
    )
}
