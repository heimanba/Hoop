import SwiftData
import SwiftUI

struct AuthRootView: View {
    @Environment(Theme.self) private var theme
    @Query(sort: \AuthSessionRecord.signedInAt, order: .reverse) private var sessionRecords: [AuthSessionRecord]
    @State private var viewModel = AuthViewModel()

    var body: some View {
        Group {
            switch viewModel.state {
            case .loading:
                VStack(spacing: theme.spacing.small) {
                    ProgressView()
                    Text("正在加载本地账户...")
                        .font(theme.typography.body)
                        .foregroundStyle(theme.colors.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .hoopScreenBackground(theme)
            case .signedOut:
                SignInView(viewModel: viewModel)
            case .signedIn(let user):
                ProfileGateView(viewModel: viewModel, deviceUser: user)
            case .configurationError(let message):
                ConfigurationErrorView(message: message)
            }
        }
        .task {
            viewModel.restoreSession(from: sessionRecords)
        }
        .onChange(of: sessionSnapshot) {
            viewModel.restoreSession(from: sessionRecords)
        }
    }

    private var sessionSnapshot: String {
        sessionRecords
            .map { "\($0.key)|\($0.userID)|\($0.email)|\($0.displayName)" }
            .joined(separator: "\n")
    }
}

#Preview {
    AuthRootView()
        .environment(Theme())
        .environment(ProfileManager())
        .modelContainer(
            for: [AuthSessionRecord.self, LocalUserProfile.self, UploadedTrainingVideoRecord.self, TrainingVideoPost.self],
            inMemory: true
        )
}
