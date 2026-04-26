import SwiftUI

struct ConfigurationErrorView: View {
    @Environment(Theme.self) private var theme
    let message: String

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: theme.spacing.sectionGap) {
                    HoopCard {
                        VStack(alignment: .leading, spacing: theme.spacing.small) {
                            Image(systemName: "lock.trianglebadge.exclamationmark")
                                .font(.system(size: 32))
                                .foregroundStyle(theme.colors.warning)

                            Text("需要配置本地登录")
                                .font(theme.typography.title2)
                                .foregroundStyle(theme.colors.textPrimary)

                            Text(message)
                                .font(theme.typography.body)
                                .foregroundStyle(theme.colors.textSecondary)

                            Text("请在 Config/Secrets.xcconfig 中设置 AUTH_EMAIL 和 AUTH_PASSWORD。")
                                .font(theme.typography.caption)
                                .foregroundStyle(theme.colors.textTertiary)
                        }
                    }
                }
                .padding(.horizontal, theme.spacing.pageMargin)
                .padding(.vertical, theme.spacing.medium)
            }
            .navigationTitle("Hoop")
            .hoopScreenBackground(theme)
        }
    }
}
