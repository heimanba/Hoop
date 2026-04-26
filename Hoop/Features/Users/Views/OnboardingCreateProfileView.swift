import SwiftData
import SwiftUI

struct OnboardingCreateProfileView: View {
    enum Mode {
        case firstProfile(deviceUser: AuthenticatedUser)
        case additionalMember
    }

    @Environment(Theme.self) private var theme
    @Environment(ProfileManager.self) private var profileManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let mode: Mode

    @State private var displayName = ""
    @State private var selectedRole: UserRole = .player
    @State private var selectedAvatar = UserRole.player.defaultAvatar
    @State private var errorMessage: String?
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case displayName
    }

    private let avatarOptions = ["👨", "👩", "🧑", "👧", "👦", "🏀", "⭐️", "🔥"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacing.sectionGap) {
                HoopCard {
                    VStack(alignment: .leading, spacing: theme.spacing.small) {
                        StatusBadge(title: modeTitle, tone: .brand)

                        Text(headerTitle)
                            .font(theme.typography.display)
                            .foregroundStyle(theme.colors.textPrimary)

                        Text(headerSubtitle)
                            .font(theme.typography.body)
                            .foregroundStyle(theme.colors.textSecondary)
                    }
                }

                HoopCard {
                    VStack(alignment: .leading, spacing: theme.spacing.small) {
                        VStack(alignment: .leading, spacing: theme.spacing.xxSmall) {
                            Text("昵称")
                                .font(theme.typography.captionEmphasis)
                                .foregroundStyle(theme.colors.textSecondary)

                            TextField("例如：小明", text: $displayName)
                                .focused($focusedField, equals: .displayName)
                                .textFieldStyle(.roundedBorder)
                        }

                        VStack(alignment: .leading, spacing: theme.spacing.xxSmall) {
                            Text("身份")
                                .font(theme.typography.captionEmphasis)
                                .foregroundStyle(theme.colors.textSecondary)

                            Picker("身份", selection: $selectedRole) {
                                ForEach(availableRoles) { role in
                                    Text(role.title).tag(role)
                                }
                            }
                            .pickerStyle(.segmented)
                            .disabled(isRoleLocked)
                        }

                        VStack(alignment: .leading, spacing: theme.spacing.xxSmall) {
                            Text("头像")
                                .font(theme.typography.captionEmphasis)
                                .foregroundStyle(theme.colors.textSecondary)

                            LazyVGrid(columns: avatarColumns, alignment: .leading, spacing: theme.spacing.xSmall) {
                                ForEach(avatarOptions, id: \.self) { avatar in
                                    Button {
                                        selectedAvatar = avatar
                                    } label: {
                                        avatarCell(for: avatar)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("选择头像 \(avatar)")
                                }
                            }
                        }

                        if let errorMessage {
                            Text(errorMessage)
                                .font(theme.typography.callout)
                                .foregroundStyle(theme.colors.textSecondary)
                        }

                        Button(submitTitle, systemImage: submitSystemImage, action: submit)
                            .buttonStyle(PrimaryButtonStyle())
                    }
                }
            }
            .padding(.horizontal, theme.spacing.pageMargin)
            .padding(.vertical, theme.spacing.medium)
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .defaultFocus($focusedField, .displayName)
        .hoopScreenBackground(theme)
        .onAppear {
            if case let .firstProfile(deviceUser) = mode, displayName.isEmpty {
                displayName = deviceUser.displayName
                selectedRole = .parent
                selectedAvatar = UserRole.parent.defaultAvatar
            }
        }
        .onChange(of: selectedRole) {
            if avatarOptions.contains(selectedAvatar) == false || selectedAvatar == previousDefaultAvatar {
                selectedAvatar = selectedRole.defaultAvatar
            }
        }
    }

    private var availableRoles: [UserRole] {
        switch mode {
        case .firstProfile:
            [.parent]
        case .additionalMember:
            UserRole.allCases
        }
    }

    private var isRoleLocked: Bool {
        if case .firstProfile = mode {
            return true
        }

        return false
    }

    private var navigationTitle: String {
        switch mode {
        case .firstProfile:
            "创建成员"
        case .additionalMember:
            "添加成员"
        }
    }

    private var modeTitle: String {
        switch mode {
        case .firstProfile:
            "首次使用"
        case .additionalMember:
            "成员管理"
        }
    }

    private var headerTitle: String {
        switch mode {
        case .firstProfile:
            "先创建这台设备上的第一个成员"
        case .additionalMember:
            "把新的家庭成员加入进来"
        }
    }

    private var headerSubtitle: String {
        switch mode {
        case .firstProfile:
            "首个成员默认作为家长，历史 local-parent 上传路径也会继续沿用。"
        case .additionalMember:
            "成员创建后会进入本地资料列表，训练视频将按成员 ID 分目录上传。"
        }
    }

    private var submitTitle: String {
        switch mode {
        case .firstProfile:
            "创建并进入 App"
        case .additionalMember:
            "保存成员"
        }
    }

    private var submitSystemImage: String {
        switch mode {
        case .firstProfile:
            "arrow.right.circle.fill"
        case .additionalMember:
            "person.badge.plus"
        }
    }

    private var avatarColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: theme.spacing.xSmall), count: 4)
    }

    private var previousDefaultAvatar: String {
        switch selectedRole {
        case .parent:
            UserRole.player.defaultAvatar
        case .player:
            UserRole.parent.defaultAvatar
        }
    }

    private func avatarCell(for avatar: String) -> some View {
        Text(avatar)
            .font(.system(size: 28))
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(avatarBackground)
            .overlay {
                avatarBorder(for: avatar)
            }
    }

    private var avatarBackground: some View {
        RoundedRectangle(cornerRadius: theme.radius.medium, style: .continuous)
            .fill(theme.colors.surfaceRaised)
    }

    private func avatarBorder(for avatar: String) -> some View {
        let isSelected = selectedAvatar == avatar

        return RoundedRectangle(cornerRadius: theme.radius.medium, style: .continuous)
            .stroke(
                isSelected ? theme.colors.brand : theme.colors.border,
                lineWidth: isSelected ? theme.stroke.emphasis : theme.stroke.thin
            )
    }

    private func submit() {
        do {
            let preferredID: String?
            let shouldDismiss: Bool
            let shouldSelectAfterCreation: Bool

            switch mode {
            case let .firstProfile(deviceUser):
                preferredID = deviceUser.id
                shouldDismiss = false
                shouldSelectAfterCreation = true
            case .additionalMember:
                preferredID = nil
                shouldDismiss = true
                shouldSelectAfterCreation = false
            }

            _ = try profileManager.createProfile(
                displayName: displayName,
                role: selectedRole,
                avatarEmoji: selectedAvatar,
                preferredID: preferredID,
                selectAfterCreation: shouldSelectAfterCreation,
                in: modelContext
            )
            errorMessage = nil

            if shouldDismiss {
                dismiss()
            }
        } catch {
            errorMessage = if let localizedError = error as? LocalizedError,
                              let description = localizedError.errorDescription,
                              !description.isEmpty {
                description
            } else {
                error.localizedDescription
            }
        }
    }
}

#Preview("First Profile") {
    NavigationStack {
        OnboardingCreateProfileView(
            mode: .firstProfile(
                deviceUser: AuthenticatedUser(
                    id: "local-parent",
                    email: "parent@example.com",
                    displayName: "爸爸"
                )
            )
        )
        .environment(Theme())
        .environment(ProfileManager())
        .modelContainer(
            for: [AuthSessionRecord.self, LocalUserProfile.self, UploadedTrainingVideoRecord.self, TrainingVideoPost.self],
            inMemory: true
        )
    }
}
