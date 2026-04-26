import SwiftUI

struct ProfileSelectorView: View {
    @Environment(Theme.self) private var theme
    @Environment(ProfileManager.self) private var profileManager

    @Bindable var viewModel: AuthViewModel
    let profiles: [LocalUserProfile]

    @State private var pendingParentProfile: LocalUserProfile?
    @State private var password = ""
    @State private var passwordError: String?
    @FocusState private var isPasswordFieldFocused: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacing.sectionGap) {
                HoopCard {
                    VStack(alignment: .leading, spacing: theme.spacing.small) {
                        StatusBadge(title: "设备已解锁", tone: .brand)

                        Text("选择这次是谁在使用 Hoop")
                            .font(theme.typography.display)
                            .foregroundStyle(theme.colors.textPrimary)

                        Text("训练上传、个人展示和成员权限都会跟随当前选择切换。")
                            .font(theme.typography.body)
                            .foregroundStyle(theme.colors.textSecondary)
                    }
                }

                VStack(alignment: .leading, spacing: theme.spacing.small) {
                    SectionHeader(title: "家庭成员", subtitle: "点一下就能切到对应身份")

                    ForEach(profiles, id: \.id) { profile in
                        Button {
                            handleSelection(for: profile)
                        } label: {
                            HoopCard {
                                HStack(spacing: theme.spacing.small) {
                                    Text(profile.avatarEmoji)
                                        .font(.system(size: 32))
                                        .accessibilityHidden(true)

                                    VStack(alignment: .leading, spacing: theme.spacing.xxxSmall) {
                                        Text(profile.displayName)
                                            .font(theme.typography.bodyEmphasis)
                                            .foregroundStyle(theme.colors.textPrimary)

                                        Text(profile.role.title)
                                            .font(theme.typography.caption)
                                            .foregroundStyle(theme.colors.textSecondary)
                                    }

                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.footnote.weight(.semibold))
                                        .foregroundStyle(theme.colors.textTertiary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("选择 \(profile.displayName)，\(profile.role.title)")
                    }
                }
            }
            .padding(.horizontal, theme.spacing.pageMargin)
            .padding(.vertical, theme.spacing.medium)
        }
        .navigationTitle("选择身份")
        .navigationBarTitleDisplayMode(.inline)
        .hoopScreenBackground(theme)
        .sheet(item: $pendingParentProfile, onDismiss: resetParentUnlockState) { profile in
            NavigationStack {
                parentUnlockSheet(for: profile)
            }
            .presentationDetents([.medium])
        }
    }
}

#Preview {
    NavigationStack {
        ProfileSelectorView(
            viewModel: AuthViewModel(),
            profiles: [
                LocalUserProfile(id: "local-parent", displayName: "爸爸", role: .parent, avatarEmoji: "👨"),
                LocalUserProfile(displayName: "小明", role: .player, avatarEmoji: "🏀")
            ]
        )
        .environment(Theme())
        .environment(ProfileManager())
    }
}

private extension ProfileSelectorView {
    func handleSelection(for profile: LocalUserProfile) {
        guard profileManager.requiresDevicePassword(toSelect: profile) else {
            profileManager.select(profile)
            return
        }

        password = ""
        passwordError = nil
        pendingParentProfile = profile
    }

    func parentUnlockSheet(for profile: LocalUserProfile) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: theme.spacing.sectionGap) {
                HoopCard {
                    VStack(alignment: .leading, spacing: theme.spacing.small) {
                        StatusBadge(title: "家长验证", tone: .warning)

                        Text("切换到 \(profile.displayName) 前需要验证设备密码")
                            .font(theme.typography.display)
                            .foregroundStyle(theme.colors.textPrimary)

                        Text("这样可以避免球员直接进入家长视角。验证通过后，本次会话会立即切换身份。")
                            .font(theme.typography.body)
                            .foregroundStyle(theme.colors.textSecondary)
                    }
                }

                HoopCard {
                    VStack(alignment: .leading, spacing: theme.spacing.small) {
                        VStack(alignment: .leading, spacing: theme.spacing.xxSmall) {
                            Text("设备密码")
                                .font(theme.typography.captionEmphasis)
                                .foregroundStyle(theme.colors.textSecondary)

                            SecureField("输入设备密码", text: $password)
                                .textContentType(.password)
                                .focused($isPasswordFieldFocused)
                                .textFieldStyle(.roundedBorder)
                                .onSubmit {
                                    unlockParentProfile(profile)
                                }
                        }

                        if let passwordError {
                            Text(passwordError)
                                .font(theme.typography.callout)
                                .foregroundStyle(theme.colors.textSecondary)
                        }

                        Button("验证并切换", systemImage: "lock.open.fill") {
                            unlockParentProfile(profile)
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(password.isEmpty)

                        Button("暂不切换") {
                            pendingParentProfile = nil
                        }
                        .font(theme.typography.bodyEmphasis)
                        .foregroundStyle(theme.colors.textSecondary)
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .padding(.horizontal, theme.spacing.pageMargin)
            .padding(.vertical, theme.spacing.medium)
        }
        .navigationTitle("验证家长身份")
        .navigationBarTitleDisplayMode(.inline)
        .hoopScreenBackground(theme)
        .defaultFocus($isPasswordFieldFocused, true)
    }

    func unlockParentProfile(_ profile: LocalUserProfile) {
        let trimmedPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)

        guard viewModel.validateDevicePassword(trimmedPassword) else {
            passwordError = "设备密码不正确。"
            return
        }

        profileManager.select(profile)
        pendingParentProfile = nil
    }

    func resetParentUnlockState() {
        password = ""
        passwordError = nil
        isPasswordFieldFocused = false
    }
}
