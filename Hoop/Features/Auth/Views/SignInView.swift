import SwiftUI

struct SignInView: View {
    @Environment(Theme.self) private var theme
    @Environment(\.modelContext) private var modelContext
    @Bindable var viewModel: AuthViewModel
    @State private var email = ""
    @State private var password = ""
    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case email, password
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: theme.spacing.sectionGap) {
                    HoopCard {
                        VStack(alignment: .leading, spacing: theme.spacing.small) {
                            StatusBadge(title: "本地模式", tone: .brand)
                            Text("登录 Hoop")
                                .font(theme.typography.display)
                                .foregroundStyle(theme.colors.textPrimary)
                            Text("当前版本已移除线上账号系统，使用配置文件中的固定账号完成本地登录。")
                                .font(theme.typography.body)
                                .foregroundStyle(theme.colors.textSecondary)

                            if let configuredEmail = viewModel.configuredEmail {
                                Text("当前配置账号：\(configuredEmail)")
                                    .font(theme.typography.caption)
                                    .foregroundStyle(theme.colors.textTertiary)
                            }
                        }
                    }

                    HoopCard {
                        VStack(alignment: .leading, spacing: theme.spacing.small) {
                            VStack(alignment: .leading, spacing: theme.spacing.xxSmall) {
                                Text("邮箱")
                                    .font(theme.typography.captionEmphasis)
                                    .foregroundStyle(theme.colors.textSecondary)
                                TextField("输入邮箱", text: $email)
                                    .textContentType(.emailAddress)
                                    .textInputAutocapitalization(.never)
                                    .keyboardType(.emailAddress)
                                    .autocorrectionDisabled()
                                    .focused($focusedField, equals: .email)
                                    .onSubmit { focusedField = .password }
                            }
                            .textFieldStyle(.roundedBorder)

                            VStack(alignment: .leading, spacing: theme.spacing.xxSmall) {
                                Text("密码")
                                    .font(theme.typography.captionEmphasis)
                                    .foregroundStyle(theme.colors.textSecondary)
                                SecureField("输入密码", text: $password)
                                    .textContentType(.password)
                                    .focused($focusedField, equals: .password)
                                    .onSubmit { submit() }
                            }
                            .textFieldStyle(.roundedBorder)

                            Button("登录", systemImage: "arrow.right.circle.fill", action: submit)
                                .buttonStyle(PrimaryButtonStyle())
                                .disabled(viewModel.isWorking || email.isEmpty || password.isEmpty)

                            if viewModel.isWorking {
                                HStack(spacing: theme.spacing.xxSmall) {
                                    ProgressView()
                                    Text("正在处理...")
                                        .font(theme.typography.callout)
                                        .foregroundStyle(theme.colors.textSecondary)
                                }
                            }

                            if let message = viewModel.message {
                                Text(message)
                                    .font(theme.typography.callout)
                                    .foregroundStyle(theme.colors.textSecondary)
                            }
                        }
                    }
                }
                .padding(.horizontal, theme.spacing.pageMargin)
                .padding(.vertical, theme.spacing.medium)
            }
            .navigationTitle("登录")
            .navigationBarTitleDisplayMode(.inline)
            .defaultFocus($focusedField, .email)
            .hoopScreenBackground(theme)
        }
    }

    private func submit() {
        focusedField = nil
        viewModel.signIn(email: email, password: password, context: modelContext)
    }
}

#Preview {
    NavigationStack {
        SignInView(viewModel: AuthViewModel())
            .environment(Theme())
            .modelContainer(
                for: [AuthSessionRecord.self, LocalUserProfile.self, UploadedTrainingVideoRecord.self, TrainingVideoPost.self],
                inMemory: true
            )
    }
}
