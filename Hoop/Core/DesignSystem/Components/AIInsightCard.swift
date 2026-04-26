import SwiftUI

struct AIInsightCard: View {
    @Environment(Theme.self) private var theme

    let title: String
    let summary: String
    let recommendation: String

    var body: some View {
        HoopCard {
            VStack(alignment: .leading, spacing: theme.spacing.small) {
                HStack {
                    StatusBadge(title: "AI 分析", tone: .ai)
                    Spacer()
                    Image(systemName: "sparkles.rectangle.stack")
                        .foregroundStyle(theme.colors.ai)
                }

                Text(title)
                    .font(theme.typography.title3)
                    .foregroundStyle(theme.colors.textPrimary)

                Text(summary)
                    .font(theme.typography.body)
                    .foregroundStyle(theme.colors.textSecondary)

                VStack(alignment: .leading, spacing: theme.spacing.xxxSmall) {
                    Text("下一次训练重点")
                        .font(theme.typography.captionEmphasis)
                        .foregroundStyle(theme.colors.ai)
                    Text(recommendation)
                        .font(theme.typography.callout)
                        .foregroundStyle(theme.colors.textPrimary)
                }
                .padding(theme.spacing.compactCardPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(theme.colors.ai.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: theme.radius.medium, style: .continuous))
            }
        }
    }
}
