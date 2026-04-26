import SwiftUI

struct HoopCard<Content: View>: View {
    @Environment(Theme.self) private var theme

    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(theme.spacing.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.colors.surfaceRaised)
            .overlay {
                RoundedRectangle(cornerRadius: theme.radius.large, style: .continuous)
                    .stroke(theme.colors.border, lineWidth: theme.stroke.thin)
            }
            .clipShape(RoundedRectangle(cornerRadius: theme.radius.large, style: .continuous))
            .shadow(
                color: theme.shadow.cardColor,
                radius: theme.shadow.cardRadius,
                x: 0,
                y: theme.shadow.cardY
            )
    }
}
