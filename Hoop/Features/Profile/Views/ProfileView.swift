import SwiftData
import SwiftUI

struct ProfileView: View {
    @Environment(Theme.self) private var theme
    @Environment(ProfileManager.self) private var profileManager
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \LocalUserProfile.createdAt) private var profiles: [LocalUserProfile]

    @Bindable var viewModel: AuthViewModel
    let deviceUser: AuthenticatedUser

    @State private var isPresentingUserManagement = false

    var body: some View {
        List {
            Section {
                HoopCard {
                    VStack(alignment: .leading, spacing: theme.spacing.small) {
                        if let currentProfile {
                            StatusBadge(
                                title: currentProfile.role.badgeTitle,
                                tone: currentProfile.role == .parent ? .success : .brand
                            )
                            Text(currentProfile.displayName)
                                .font(theme.typography.title2)
                                .foregroundStyle(theme.colors.textPrimary)
                            Text("当前设备已解锁，业务数据正以 \(currentProfile.role.title) 身份展示。")
                                .font(theme.typography.body)
                                .foregroundStyle(theme.colors.textSecondary)
                        } else {
                            StatusBadge(title: "等待选择成员", tone: .warning)
                            Text("还没有选中当前成员")
                                .font(theme.typography.title2)
                                .foregroundStyle(theme.colors.textPrimary)
                            Text("返回身份选择页后，训练上传和成员权限才会生效。")
                                .font(theme.typography.body)
                                .foregroundStyle(theme.colors.textSecondary)
                        }
                    }
                }
                .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }

            if let currentProfile {
                Section("当前成员") {
                    LabeledContent("昵称", value: currentProfile.displayName)
                    LabeledContent("角色", value: currentProfile.role.title)
                    LabeledContent("成员 ID", value: currentProfile.id)
                }
            }

            Section("设备账户") {
                LabeledContent("邮箱", value: deviceUser.email)
                LabeledContent("用户 ID", value: deviceUser.id)
                LabeledContent("数据来源", value: "SwiftData 本地存储")
                LabeledContent("会话状态", value: "已登录")
            }

            if let currentProfile {
                Section("成员操作") {
                    Button("切换当前身份", systemImage: "arrow.left.arrow.right.circle") {
                        profileManager.beginProfileSelection(from: currentProfile)
                    }
                }
            }

            if let currentProfile, currentProfile.role.canManageUsers {
                Section("家长操作") {
                    Button("管理家庭成员", systemImage: "person.2.fill") {
                        isPresentingUserManagement = true
                    }
                }
            }

            if let message = viewModel.message {
                Section("状态") {
                    Text(message)
                        .foregroundStyle(theme.colors.textSecondary)
                }
            }

            Section("账号操作") {
                Button("退出登录", role: .destructive) {
                    viewModel.signOut(context: modelContext)
                }
                .disabled(viewModel.isWorking)

                if viewModel.isWorking {
                    ProgressView("处理中...")
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .navigationTitle("我的")
        .background(theme.colors.background)
        .sheet(isPresented: $isPresentingUserManagement) {
            UserManagementView()
        }
    }

    private var currentProfile: LocalUserProfile? {
        profileManager.currentProfile
    }
}
