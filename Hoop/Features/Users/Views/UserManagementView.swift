import SwiftData
import SwiftUI

struct UserManagementView: View {
    @Environment(Theme.self) private var theme
    @Environment(ProfileManager.self) private var profileManager
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(sort: \LocalUserProfile.createdAt) private var profiles: [LocalUserProfile]

    @State private var profilePendingDeletion: LocalUserProfile?
    @State private var alertMessage: String?
    @State private var isPresentingAddMember = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HoopCard {
                        VStack(alignment: .leading, spacing: theme.spacing.small) {
                            StatusBadge(title: "家长管理", tone: .success)
                            Text("本地成员")
                                .font(theme.typography.title2)
                                .foregroundStyle(theme.colors.textPrimary)
                            Text("删除成员只会移除本地资料，不会清理已上传到 OSS 的视频。")
                                .font(theme.typography.body)
                                .foregroundStyle(theme.colors.textSecondary)
                        }
                    }
                    .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }

                Section("成员列表") {
                    ForEach(profiles, id: \.id) { profile in
                        HStack(spacing: theme.spacing.small) {
                            Text(profile.avatarEmoji)
                                .font(.system(size: 26))
                                .accessibilityHidden(true)

                            VStack(alignment: .leading, spacing: theme.spacing.xxxSmall) {
                                Text(profile.displayName)
                                    .foregroundStyle(theme.colors.textPrimary)
                                Text(profile.role.title)
                                    .font(theme.typography.caption)
                                    .foregroundStyle(theme.colors.textSecondary)
                            }

                            Spacer()

                            if profile.id == profileManager.currentProfile?.id {
                                StatusBadge(title: "当前使用中", tone: .brand)
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if canDelete(profile) {
                                Button("删除", role: .destructive) {
                                    profilePendingDeletion = profile
                                }
                            }
                        }
                    }
                }

                if let alertMessage {
                    Section("状态") {
                        Text(alertMessage)
                            .foregroundStyle(theme.colors.textSecondary)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(theme.colors.background)
            .navigationTitle("成员管理")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("关闭") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("添加成员", systemImage: "plus") {
                        isPresentingAddMember = true
                    }
                }
            }
        }
        .sheet(isPresented: $isPresentingAddMember) {
            NavigationStack {
                OnboardingCreateProfileView(mode: .additionalMember)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button("取消") {
                                isPresentingAddMember = false
                            }
                        }
                    }
            }
        }
        .confirmationDialog(
            "移除本地资料",
            isPresented: deletionDialogBinding,
            titleVisibility: .visible
        ) {
            Button("删除", role: .destructive, action: deletePendingProfile)
            Button("取消", role: .cancel) {
                profilePendingDeletion = nil
            }
        } message: {
            Text("本地资料将被移除，已上传的训练视频不会被删除。")
        }
    }

    private var deletionDialogBinding: Binding<Bool> {
        Binding(
            get: { profilePendingDeletion != nil },
            set: { isPresented in
                if !isPresented {
                    profilePendingDeletion = nil
                }
            }
        )
    }

    private func canDelete(_ profile: LocalUserProfile) -> Bool {
        if profiles.count <= 1 {
            return false
        }

        if profile.role == .parent {
            return profiles.contains(where: { $0.id != profile.id && $0.role == .parent })
        }

        return true
    }

    private func deletePendingProfile() {
        guard let profilePendingDeletion else { return }

        do {
            try profileManager.deleteProfile(profilePendingDeletion, from: profiles, in: modelContext)
            profileManager.resolve(from: profiles.filter { $0.id != profilePendingDeletion.id })
            alertMessage = nil
        } catch {
            alertMessage = if let localizedError = error as? LocalizedError,
                              let description = localizedError.errorDescription,
                              !description.isEmpty {
                description
            } else {
                error.localizedDescription
            }
        }

        self.profilePendingDeletion = nil
    }
}
