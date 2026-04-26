import SwiftUI

struct MetricTile: View {
    @Environment(Theme.self) private var theme

    let title: String
    let value: String
    let subtitle: String
    let tone: Color

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.xxSmall) {
            Text(title)
                .font(theme.typography.caption)
                .foregroundStyle(theme.colors.textSecondary)

            Text(value)
                .font(theme.typography.metricMedium)
                .foregroundStyle(theme.colors.textPrimary)

            Text(subtitle)
                .font(theme.typography.caption)
                .foregroundStyle(tone)
        }
        .padding(theme.spacing.compactCardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.colors.surfaceMuted)
        .clipShape(RoundedRectangle(cornerRadius: theme.radius.medium, style: .continuous))
    }
}
