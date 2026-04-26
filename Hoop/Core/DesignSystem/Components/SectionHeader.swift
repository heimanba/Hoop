import SwiftUI

struct SectionHeader: View {
    @Environment(Theme.self) private var theme

    let title: String
    let subtitle: String?
    let actionTitle: String?

    init(title: String, subtitle: String? = nil, actionTitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
        self.actionTitle = actionTitle
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: theme.spacing.xxxSmall) {
                Text(title)
                    .font(theme.typography.title3)
                    .foregroundStyle(theme.colors.textPrimary)

                if let subtitle {
                    Text(subtitle)
                        .font(theme.typography.caption)
                        .foregroundStyle(theme.colors.textSecondary)
                }
            }

            Spacer(minLength: theme.spacing.small)

            if let actionTitle {
                Text(actionTitle)
                    .font(theme.typography.captionEmphasis)
                    .foregroundStyle(theme.colors.brand)
            }
        }
    }
}
